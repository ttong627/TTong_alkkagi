# -*- coding: utf-8 -*-
"""블렌더 안에서 도는 촬영장 — 장면키(_장면키.json)대로 부품·카메라를 움직여 장면을 찍는다.

blender --background --factory-startup --python blender_scene.py -- <장면키.json> <출력폴더> <입체|도면선> [초안] [장면=1,126,245]

비유: 콘티(장면키)는 밖(plan.py · camera.py)에서 다 짜 오고, 여기서는 세트·조명을 세우고 찍기만 한다.
움직임 수식은 여기에 없다 — 장면마다 위치 숫자를 그대로 받는다.

- `장면=` 을 주면 그 장면만 본 품질 사진으로 찍는다(미리보기) → `<출력>/미리보기/<입체|도면선_원본>/0126.png`
- 영상 렌더 때는 `_블렌더투영_<모드>.json` 에 블렌더가 계산한 부품 화면 위치를 남긴다 → make.py 가 camera.py 투영과 대조
- 실험용 손잡이: 환경변수 ASSEMBLY_TUNE='{"light": 0.8, "look": "AgX - Punchy", "raytrace": false, "rough": 0.6, "exposure": -0.3}'
"""
import json
import math
import os
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
KEYS = json.loads(Path(ARGS[0]).read_text(encoding="utf-8"))
OUT = Path(ARGS[1])
MODE = ARGS[2]
DRAFT = "초안" in ARGS[3:]
STILLS = [int(x) for x in next((a.split("=", 1)[1] for a in ARGS[3:] if a.startswith("장면=")), "").split(",") if x.strip()]
TUNE = json.loads(os.environ.get("ASSEMBLY_TUNE") or "{}")
K = KEYS["scale"]                                     # mm → 블렌더 미터

# 조명은 세상에 고정(카메라가 돌면 빛이 면을 타고 흐른다 — 입체감)
# (이름, 방위각, 높이각, 거리 m, 세기 W, 크기 m, 색)
# ★09-16 초안 실측: 420·110·520W 는 윗면이 하얗게 날아가고 색이 바랬다 → 절반 가까이 낮춤
LIGHTS = [
    ("주광", -40, 45, 2.6, 200.0, 1.2, (1.0, 0.95, 0.88)),
    ("보조광", 60, 18, 3.0, 70.0, 2.0, (0.82, 0.9, 1.0)),
    ("윤곽광", 165, 35, 2.4, 300.0, 0.8, (1.0, 1.0, 1.0)),
]


def log(*a):
    print("[조립분해]", *a, flush=True)


def safe_set(obj, name, value):
    try:
        setattr(obj, name, value)
        return True
    except (AttributeError, TypeError, ValueError):
        return False


def direction(az, el):
    a, e = math.radians(az), math.radians(el)
    return Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"   # 장면마다 정확한 값을 준다


def import_parts():
    """GLB 부품을 계획 이름에 짝지운다 — GLB 안에는 이름이 없어서 **중심 위치**로 맞춘다."""
    bpy.ops.import_scene.gltf(filepath=KEYS["glb"])
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    facts, diag = KEYS["parts"], KEYS["diag_mm"]
    matched = {}
    for o in meshes:
        pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
        c = [(min(p[i] for p in pts) + max(p[i] for p in pts)) / 2 * 1000 for i in range(3)]
        best = min(facts, key=lambda lab: math.dist(c, facts[lab]["center"]))
        gap = math.dist(c, facts[best]["center"])
        if gap > 0.02 * diag or best in matched:
            raise SystemExit(f"[조립분해] 부품 짝 맞추기 실패 — {o.name} 중심 {[round(v, 2) for v in c]}mm → "
                             f"{best} 와 {gap:.2f}mm 차이(겹침 {best in matched})")
        matched[best] = o
    missing = sorted(set(facts) - set(matched))
    if missing:
        raise SystemExit(f"[조립분해] GLB 에 없는 부품 {missing} — cad 모델을 다시 빌드했나 확인")
    root = bpy.data.objects.new("조립품", None)
    bpy.context.scene.collection.objects.link(root)
    for o in matched.values():
        o.parent = root
    root.scale = (K * 1000,) * 3                     # GLB 는 미터(mm/1000) → 전체 대각선 1m 크기로
    log("부품 짝", {lab: o.name for lab, o in matched.items()})
    return matched


def make_camera():
    scene = bpy.context.scene
    data = bpy.data.cameras.new("카메라")
    data.sensor_width, data.sensor_fit = 36.0, "AUTO"
    data.clip_start, data.clip_end = 0.001, 1000.0
    data.dof.use_dof = MODE == "입체"
    data.dof.aperture_fstop = KEYS["camera"][0]["fstop"] * (2.0 if DRAFT else 1.0)
    cam = bpy.data.objects.new("카메라", data)
    target = bpy.data.objects.new("겨냥점", None)
    scene.collection.objects.link(cam)
    scene.collection.objects.link(target)
    track = cam.constraints.new("TRACK_TO")
    track.target, track.track_axis, track.up_axis = target, "TRACK_NEGATIVE_Z", "UP_Y"   # 수평 유지
    scene.camera = cam
    return cam, target


def animate(parts, cam, target):
    scene = bpy.context.scene
    n = KEYS["frames"]
    scene.frame_start, scene.frame_end = 1, n
    scene.render.fps = KEYS["fps"]
    for i in range(n):
        f = i + 1
        for lab, o in parts.items():
            o.location = [v / 1000 for v in KEYS["offsets"][lab][i]]
            o.keyframe_insert("location", frame=f)
        key = KEYS["camera"][i]
        cam.location = [v * K for v in key["pos"]]
        target.location = [v * K for v in key["target"]]
        cam.data.lens = key["lens"]
        cam.data.dof.focus_distance = key["focus"] * K
        cam.keyframe_insert("location", frame=f)
        target.keyframe_insert("location", frame=f)
        cam.data.keyframe_insert("lens", frame=f)
        cam.data.keyframe_insert("dof.focus_distance", frame=f)


def resolution():
    w, h = (1920, 1080) if KEYS["ratio"] == "16:9" else (1080, 1920)
    return (w // 2, h // 2) if DRAFT else (w, h)


def studio_solid():
    scene = bpy.context.scene
    world = bpy.data.worlds.new("스튜디오")
    scene.world = world
    safe_set(world, "use_nodes", True)
    bg = world.node_tree.nodes.get("Background") if world.node_tree else None
    if bg:
        bg.inputs["Color"].default_value = (0.016, 0.018, 0.022, 1.0)
        bg.inputs["Strength"].default_value = 1.0
    floor_z = KEYS["floor_mm"] * K - 0.0005
    bpy.ops.mesh.primitive_plane_add(size=80.0, location=(0.0, 0.0, floor_z))
    floor = bpy.context.active_object
    floor.name = "바닥"
    mat = bpy.data.materials.new("바닥재질")
    safe_set(mat, "use_nodes", True)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.045, 0.05, 0.056, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.42
    floor.data.materials.append(mat)
    rough = float(TUNE.get("rough", 0.55))           # ★0.35 는 큰 조명을 거울처럼 비춰 윗면이 날아갔다
    for m in bpy.data.materials:
        node = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
        if node and m is not mat:
            node.inputs["Roughness"].default_value = rough
    center = Vector(KEYS["rest_center_mm"]) * K
    light_scale = float(TUNE.get("light", 1.0))
    for name, az, el, dist, energy, size, color in LIGHTS:
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy * light_scale, size, color
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = center + direction(az, el) * dist
        obj.rotation_euler = (center - obj.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.engine = "BLENDER_EEVEE"
    ee = scene.eevee
    ee.taa_render_samples = 16 if DRAFT else 64
    safe_set(ee, "use_raytracing", bool(TUNE.get("raytrace", True)))
    safe_set(ee, "use_shadows", True)
    if not DRAFT:                                      # ★초안에서 자글자글한 노이즈 — 본 렌더는 추적·그림자를 촘촘히
        safe_set(ee.ray_tracing_options, "resolution_scale", "1")
        safe_set(ee, "shadow_ray_count", 2)
        safe_set(ee, "shadow_step_count", 8)
    scene.render.use_motion_blur = not DRAFT
    safe_set(scene.render, "motion_blur_shutter", 0.5)
    safe_set(scene.view_settings, "view_transform", "AgX")
    # ★09-16 본 품질 비교(A 중간높은대비 · B 레이트레이싱 끔 · C Punchy): C 가 색이 또렷하고 대비가 살아 기본으로
    safe_set(scene.view_settings, "look", TUNE.get("look", "AgX - Punchy"))
    safe_set(scene.view_settings, "exposure", float(TUNE.get("exposure", 0.0)))
    log("입체 설정", {"조명배율": light_scale, "거칠기": rough, "레이트레이싱": ee.use_raytracing,
                    "색": scene.view_settings.look, "노출": scene.view_settings.exposure})


def studio_line():
    """도면선 원본 — 면 방향마다 색이 확 다른 법선 매트캡 + 부품 외곽선. 선은 make.py 가 경계 검출로 뽑는다."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    world = bpy.data.worlds.new("흰바탕")
    world.color = (1.0, 1.0, 1.0)
    scene.world = world
    sh = scene.display.shading
    sh.light = "MATCAP"
    caps = [s.name for s in bpy.context.preferences.studio_lights if s.type == "MATCAP"]
    pick = next((c for c in caps if "normal" in c.lower()), None)
    if pick:
        sh.studio_light = pick
    else:
        sh.light = "STUDIO"
    log("매트캡", pick or "없음 → 스튜디오 조명")
    sh.show_object_outline = True
    sh.object_outline_color = (0.0, 0.0, 0.0)
    sh.show_cavity = False
    safe_set(sh, "show_shadows", False)
    safe_set(scene.display, "render_aa", "8")


def record_projection(parts):
    """블렌더가 계산한 부품 모서리의 화면 위치(가로·세로 위에서부터) — make.py 가 camera.py 와 대조."""
    scene = bpy.context.scene
    step = max(1, KEYS["fps"] // 2)
    rows = []
    for i in range(0, KEYS["frames"], step):
        scene.frame_set(i + 1)
        bpy.context.view_layer.update()
        row = {"i": i, "parts": {}}
        for lab, o in parts.items():
            uv = [world_to_camera_view(scene, scene.camera, o.matrix_world @ Vector(c)) for c in o.bound_box]
            row["parts"][lab] = [min(p.x for p in uv), max(p.x for p in uv), min(1 - p.y for p in uv), max(1 - p.y for p in uv)]
        rows.append(row)
    (OUT / f"_블렌더투영_{MODE}.json").write_text(json.dumps(rows, ensure_ascii=False), encoding="utf-8")


def main():
    reset()
    parts = import_parts()
    cam, target = make_camera()
    animate(parts, cam, target)
    (studio_solid if MODE == "입체" else studio_line)()
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = resolution()
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    safe_set(scene.render.image_settings, "color_mode", "RGB")
    sub = "입체" if MODE == "입체" else "도면선_원본"
    if STILLS:
        folder = OUT / "미리보기" / sub
        folder.mkdir(parents=True, exist_ok=True)
        log("미리보기 시작", MODE, STILLS, resolution())
        for f in STILLS:
            scene.frame_set(max(1, min(KEYS["frames"], f)))
            scene.render.filepath = str(folder / f"{f:04d}.png")
            bpy.ops.render.render(write_still=True)
        log("렌더 끝", MODE)
        return
    folder = OUT / ("입체_장면" if MODE == "입체" else "도면선_원본")
    folder.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(folder / "####")
    record_projection(parts)
    log("렌더 시작", MODE, "초안" if DRAFT else "본", KEYS["frames"], "장면", resolution())
    bpy.ops.render.render(animation=True)
    log("렌더 끝", MODE)


main()
