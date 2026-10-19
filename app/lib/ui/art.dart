import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../game/arena.dart';
import '../progress/profile.dart';

/// 그림 자원 이름(설계서 §16.11). 그림은 `tool/art` 의 SVG 원본을 크롬으로 그린 WebP 다.
abstract final class Art {
  static String character(String id, {bool attack = false}) =>
      'assets/images/chars/${id}_${attack ? 'attack' : 'idle'}.webp';

  /// 얼굴만 자른 그림(동그란 얼굴 칸 · 무협 전신 그림부터 · tool/art/pick_cast.py). 없으면 전신 그림을 잘라 쓴다.
  static String face(String id) => 'assets/images/chars/${id}_face.webp';

  static String icon(String name) => 'assets/images/icons/$name.webp';

  static String background(String name) => 'assets/images/scenes/bg_$name.webp';

  static String arenaBackground(Arena a) => background(a.name);

  static String floor(Arena a) => 'assets/images/scenes/floor_${a.name}.webp';

  /// 내 캐릭터 그림 이름(Fighter 이름과 같다).
  static String fighterId(Fighter f) => f.name;

  /// 강호행 고수·숙적 이름 → 그림 이름. 모르는 이름이면 null.
  static String? bossId(String? name) => switch (name) {
    '촌장' => 'chonjang',
    '통통' => 'tongtong',
    '묵현' => 'mukhyeon',
    '숨은 자객' || '자객' => 'jagaek',
    '쿠비' => 'kubi',
    '로직' => 'logic',
    '무림맹주' || '맹주' => 'maengju',
    '사부' => 'sabu',
    _ => null,
  };

  /// 그림이 있는 캐릭터 이름 전부(시험에서 파일이 다 있는지 본다).
  static const characterIds = [
    'seokdu',
    'yeonbi',
    'cheongmyeong',
    'banDal',
    'gurumi',
    'jeonggak',
    'yonga', //
    'seolhwa', 'chwiseon', 'mukgaek', 'magyo', 'geomhwang', 'sinseung',
    'chonjang',
    'tongtong',
    'mukhyeon',
    'jagaek',
    'kubi',
    'logic',
    'maengju',
    'sabu',
  ];

  static const iconNames = [
    'coin', 'silver', 'token', 'stamina', 'naegong', 'tp', 'dan', 'campaign', //
    'training', 'puzzle', 'arena', 'wander', 'legend', 'shop', 'stats', 'codex',
    'depot', 'odds', 'free', 'rebirth', 'settings', 'look', 'mission',
    'attendance',
    'medal',
    'lock',
    'star',
    'star_empty',
    'chest',
    'mail',
    'rank',
    'weather',
    'terrain',
    'wslogis',
    'pet',
    'pet_squirrel',
    'pet_turtle',
    'pet_crane',
    'pet_tiger',
    'pet_dragon',
  ];

  // ── 대전장(Flame)이 캔버스에 바로 그릴 바닥 그림: 미리 읽어 둔다.
  // 판 크기(폰 너비)에 맞춰 768px 로 줄여 읽는다(1024² 원본 6장 25MB → 14MB).
  // 대전장 배경은 Image.asset 이 따로 읽으므로 여기서 또 읽지 않는다(예전엔 50MB 를 그냥 들고 있었다 · 2026-10-11 점검).
  static final _floors = <Arena, ui.Image>{};

  /// 대전장 바닥 그림(아직 못 읽었으면 null — 그때는 코드로 그린 바닥을 쓴다).
  static ui.Image? floorImage(Arena a) => _floors[a];

  /// 앱 시작 때 대전장 바닥을 읽는다. 실패해도 게임은 코드로 그린 바닥으로 간다.
  static Future<void> preload() async {
    for (final a in Arena.values) {
      try {
        _floors[a] = await _decode(floor(a), 768);
      } catch (_) {}
    }
  }

  static Future<ui.Image> _decode(String asset, int width) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    return (await codec.getNextFrame()).image;
  }
}
