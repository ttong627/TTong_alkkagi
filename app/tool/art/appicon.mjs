// 앱 아이콘·스토어 그림(설계서 §16.13).
// ⚠️2026-10-19 부터 앱 아이콘·스토어 아이콘·큰 그림은 코덱스 그림(apply_appicon.py) — 이 파일로 덮어쓰지 않는다(흑백 아이콘만 여기 것).
// 쓰기(저장소 루트): node app/tool/art/appicon.mjs
//  - store/icon-512.png · store/feature-graphic-1024x500.png
//  - app/android/app/src/main/res/mipmap-*/ic_launcher.png (옛 안드로이드)
//  - mipmap-*/ic_launcher_foreground.png + mipmap-anydpi-v26/ic_launcher.xml (적응형 아이콘)
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { markSvg as mark } from './appicon_mark.mjs';

const require = createRequire(import.meta.url);
let pw;
try {
  pw = require('playwright');
} catch {
  pw = require('/opt/node22/lib/node_modules/playwright');
}

const ROOT = resolve(new URL('../../..', import.meta.url).pathname);
const RES = join(ROOT, 'app/android/app/src/main/res');

/** 스토어 큰 그림 1024×500: 로비 배경 · 두 무인 · 제목. */
function featureGraphic(bgDataUrl, charA, charB, fontUrl) {
  return `<html><head><style>
  @font-face { font-family: T; src: url('${fontUrl}'); }
  body { margin:0; width:1024px; height:500px; overflow:hidden; font-family:T; }
  .bg { position:absolute; inset:0; background:url('${bgDataUrl}') center 62%/cover; }
  .dim { position:absolute; inset:0; background:linear-gradient(90deg, rgba(10,4,14,.85) 0%, rgba(10,4,14,.55) 45%, rgba(10,4,14,.05) 75%); }
  h1 { position:absolute; left:56px; top:96px; margin:0; font-size:118px; color:#f2c14e; letter-spacing:4px;
       -webkit-text-stroke: 6px #1a0f0a; paint-order: stroke fill; text-shadow: 0 8px 20px rgba(0,0,0,.6); }
  h2 { position:absolute; left:62px; top:250px; margin:0; font-size:40px; color:#fff7ea;
       -webkit-text-stroke: 4px #1a0f0a; paint-order: stroke fill; }
  .tags { position:absolute; left:62px; top:330px; display:flex; gap:10px; }
  .tag { font-size:24px; color:#2a1a08; background:#f2c14e; border:3px solid #1a0f0a; border-radius:16px; padding:6px 14px; }
  .c { position:absolute; bottom:-10px; height:420px; }
  </style></head><body>
  <div class="bg"></div><div class="dim"></div>
  <img class="c" style="right:200px" src="${charA}"/>
  <img class="c" style="right:10px; transform:scaleX(-1)" src="${charB}"/>
  <h1>탄지무림</h1><h2>검지로 튕기는 무협 알까기</h2>
  <div class="tags"><span class="tag">줄거리 6장</span><span class="tag">고수 7인</span><span class="tag">대전장 6곳</span></div>
  </body></html>`;
}

const browser = await pw.chromium.launch();
const page = await browser.newPage();
async function shot(html, w, h, out) {
  await page.setViewportSize({ width: w, height: h });
  await page.setContent(html.startsWith('<svg') ? `<html><body style="margin:0;background:transparent">${html}</body></html>` : html);
  await page.waitForTimeout(150);
  mkdirSync(join(out, '..'), { recursive: true });
  writeFileSync(out, await page.screenshot({ omitBackground: true, clip: { x: 0, y: 0, width: w, height: h } }));
}

// 스토어 아이콘(가득 채움 — 플레이가 모서리를 둥글게 깎는다).
await shot(mark(512), 512, 512, join(ROOT, 'store/icon-512.png'));
// 옛 안드로이드 아이콘(48dp 기준 배율).
const dens = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
for (const [d, k] of Object.entries(dens)) {
  const px = Math.round(48 * k);
  const round = `<svg xmlns="http://www.w3.org/2000/svg" width="${px}" height="${px}"><defs><clipPath id="r"><rect width="${px}" height="${px}" rx="${px * 0.22}"/></clipPath></defs>
    <g clip-path="url(#r)">${mark(px).replace(/^<svg[^>]*>/, '').replace(/<\/svg>$/, '')}</g></svg>`;
  await shot(round, px, px, join(RES, `mipmap-${d}/ic_launcher.png`));
  // 적응형 앞그림: 108dp 칸. 두 돌과 손끝(그림 좌표 중심 271,228 · 반지름 225 — 실측)을
  // 안전 원(지름 66dp) 안 반지름 31dp 에 맞춘다. 손은 바깥으로 이어져 가장자리에서 잘린다(손이 화면 밖에서 들어오는 모양).
  // 예전엔 72dp 칸에 통째로 넣어 원형 마스크에서 손끝이 잘렸다(바깥 31% · 2026-10-11 점검).
  const fpx = Math.round(108 * k);
  const sc = (31 / 225) * k;
  const body = mark(512, { bg: false }).replace(/^<svg[^>]*>/, '').replace(/<\/svg>$/, '');
  const fg = (style = '') =>
    `<svg xmlns="http://www.w3.org/2000/svg" width="${fpx}" height="${fpx}" style="${style}"><g transform="translate(${54 * k} ${54 * k}) scale(${sc}) translate(-271 -228)">${body}</g></svg>`;
  await shot(fg(), fpx, fpx, join(RES, `mipmap-${d}/ic_launcher_foreground.png`));
  // 테마 아이콘(안드로이드 13+): 같은 모양의 흰 실루엣.
  await shot(fg('filter:brightness(0) invert(1)'), fpx, fpx, join(RES, `mipmap-${d}/ic_launcher_monochrome.png`));
}
mkdirSync(join(RES, 'mipmap-anydpi-v26'), { recursive: true });
writeFileSync(join(RES, 'mipmap-anydpi-v26/ic_launcher.xml'), `<?xml version="1.0" encoding="utf-8"?>
<!-- 적응형 아이콘(안드로이드 8+): 뒤는 짙은 자줏빛, 앞은 검지·돌 그림(tool/art/appicon.mjs). -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
`);
mkdirSync(join(RES, 'values'), { recursive: true });
writeFileSync(join(RES, 'values/ic_launcher_background.xml'), `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#3A1630</color>
    <!-- 실행 화면 배경(로비 그림이 뜨기 전): 먹빛 -->
    <color name="launch_background">#17111C</color>
</resources>
`);

// 스토어 큰 그림.
const toData = (p) => 'data:image/webp;base64,' + readFileSync(p).toString('base64');
const IMG = join(ROOT, 'app/assets/images');
await shot(
  featureGraphic(
    toData(join(IMG, 'scenes/bg_lobby.webp')),
    toData(join(IMG, 'chars/yonga_attack.webp')),
    toData(join(IMG, 'chars/yeonbi_idle.webp')),
    'data:font/ttf;base64,' + readFileSync(join(ROOT, 'app/assets/fonts/BlackHanSans-Regular.ttf')).toString('base64'),
  ),
  1024,
  500,
  join(ROOT, 'store/feature-graphic-1024x500.png'),
);
await browser.close();
console.log('아이콘·스토어 그림을 썼습니다.');
