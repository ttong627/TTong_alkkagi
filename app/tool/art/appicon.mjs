// 앱 아이콘·스토어 그림(설계서 §16.13).
// 쓰기(저장소 루트): node app/tool/art/appicon.mjs
//  - store/icon-512.png · store/feature-graphic-1024x500.png
//  - app/android/app/src/main/res/mipmap-*/ic_launcher.png (옛 안드로이드)
//  - mipmap-*/ic_launcher_foreground.png + mipmap-anydpi-v26/ic_launcher.xml (적응형 아이콘)
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { stroke } from './lib.mjs';

const require = createRequire(import.meta.url);
let pw;
try {
  pw = require('playwright');
} catch {
  pw = require('/opt/node22/lib/node_modules/playwright');
}

const ROOT = resolve(new URL('../../..', import.meta.url).pathname);
const RES = join(ROOT, 'app/android/app/src/main/res');

/** 아이콘 그림(가운데 안전 영역 안): 검지가 흰 돌을 튕기고, 손끝에 기가 터진다. */
function mark(size, { bg = true } = {}) {
  const s = size / 512;
  const g = (x) => x * s;
  const back = bg
    ? `<defs><radialGradient id="bg" cx="0.5" cy="0.38" r="0.75">
        <stop offset="0" stop-color="#7a2a3a"/><stop offset="0.6" stop-color="#3a1630"/><stop offset="1" stop-color="#170b1c"/></radialGradient></defs>
       <rect width="${size}" height="${size}" fill="url(#bg)"/>`
    : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  ${back}
  <defs>
    <radialGradient id="stone" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#ffffff"/><stop offset="0.6" stop-color="#e9e3d6"/><stop offset="1" stop-color="#a59c8a"/></radialGradient>
    <radialGradient id="dark" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#6d6d7a"/><stop offset="0.55" stop-color="#26262e"/><stop offset="1" stop-color="#0b0b10"/></radialGradient>
    <radialGradient id="qi" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#fff6c8"/><stop offset="0.45" stop-color="#ffc24d" stop-opacity="0.9"/><stop offset="1" stop-color="#ff7a1a" stop-opacity="0"/></radialGradient>
    <linearGradient id="skin" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe2c2"/><stop offset="1" stop-color="#e7b48a"/></linearGradient>
    <filter id="blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${g(10)}"/></filter>
  </defs>
  <!-- 날아가는 검은 돌과 속도 줄 -->
  <g stroke="#ffd36b" stroke-width="${g(12)}" stroke-linecap="round" opacity="0.85">
    <line x1="${g(250)}" y1="${g(190)}" x2="${g(330)}" y2="${g(140)}"/>
    <line x1="${g(270)}" y1="${g(225)}" x2="${g(345)}" y2="${g(180)}"/>
  </g>
  <circle cx="${g(370)}" cy="${g(140)}" r="${g(62)}" fill="url(#dark)" stroke="#120a0a" stroke-width="${g(9)}"/>
  <ellipse cx="${g(350)}" cy="${g(118)}" rx="${g(20)}" ry="${g(11)}" fill="#fff" opacity="0.5" transform="rotate(-30 ${g(350)} ${g(118)})"/>
  <!-- 기(氣) -->
  <circle cx="${g(232)}" cy="${g(262)}" r="${g(120)}" fill="url(#qi)" filter="url(#blur)"/>
  <!-- 흰 돌 -->
  <circle cx="${g(210)}" cy="${g(282)}" r="${g(96)}" fill="url(#stone)" stroke="#2a1a12" stroke-width="${g(10)}"/>
  <ellipse cx="${g(178)}" cy="${g(246)}" rx="${g(32)}" ry="${g(16)}" fill="#fff" opacity="0.9" transform="rotate(-30 ${g(178)} ${g(246)})"/>
  <!-- 검지로 튕기는 손(아래 왼쪽에서) -->
  <g transform="translate(${g(40)} ${g(478)}) rotate(40) scale(${s * 1.7})" ${stroke(5)}>
    <rect x="-34" y="-10" width="100" height="70" rx="30" fill="url(#skin)"/>
    <rect x="-18" y="-96" width="34" height="100" rx="17" fill="url(#skin)"/>
    <rect x="-8" y="-90" width="16" height="16" rx="6" fill="#ffd6cc" stroke-width="0"/>
    <rect x="22" y="-36" width="38" height="34" rx="16" fill="url(#skin)"/>
    <rect x="-58" y="6" width="40" height="28" rx="14" fill="url(#skin)"/>
  </g>
</svg>`;
}

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
  // 적응형 앞그림: 108dp 칸, 그림은 가운데 72dp 안(안전 영역 66dp)에.
  const fpx = Math.round(108 * k), inner = Math.round(72 * k), off = Math.round((fpx - inner) / 2);
  const fg = `<svg xmlns="http://www.w3.org/2000/svg" width="${fpx}" height="${fpx}"><g transform="translate(${off} ${off})">${mark(inner, { bg: false }).replace(/^<svg[^>]*>/, '').replace(/<\/svg>$/, '')}</g></svg>`;
  await shot(fg, fpx, fpx, join(RES, `mipmap-${d}/ic_launcher_foreground.png`));
}
mkdirSync(join(RES, 'mipmap-anydpi-v26'), { recursive: true });
writeFileSync(join(RES, 'mipmap-anydpi-v26/ic_launcher.xml'), `<?xml version="1.0" encoding="utf-8"?>
<!-- 적응형 아이콘(안드로이드 8+): 뒤는 짙은 자줏빛, 앞은 검지·돌 그림(tool/art/appicon.mjs). -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
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
