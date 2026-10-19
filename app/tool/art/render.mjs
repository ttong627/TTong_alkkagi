// SVG 그림을 크롬으로 그려 PNG 로 내보낸다.
// 쓰기: node app/tool/art/render.mjs [출력폴더] [--sheet 미리보기.png] [--only 이름,…]
// 크롬: 설치된 playwright(전역) — PLAYWRIGHT_BROWSERS_PATH 의 chromium.
// ⚠️2026-10-19 부터 앱의 배경·바닥·아이콘은 코덱스 그림(gen_world.py) — 이 SVG 그림으로 assets 를 덮어쓰지 않는다.
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync, unlinkSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { character, CAST } from './characters.mjs';
import { scenes } from './scenes.mjs';
import { icons } from './icons.mjs';

const require = createRequire(import.meta.url);
let pw;
try {
  pw = require('playwright');
} catch {
  pw = require('/opt/node22/lib/node_modules/playwright');
}

const args = process.argv.slice(2);
const out = args.find((a) => !a.startsWith('--')) ?? 'assets/images';
const sheetAt = args.indexOf('--sheet');
const sheet = sheetAt >= 0 ? args[sheetAt + 1] : null;
const onlyAt = args.indexOf('--only');
const only = onlyAt >= 0 ? new Set(args[onlyAt + 1].split(',')) : null;

/** [파일 이름, svg 문자열, 너비, 높이] 목록. */
function jobs() {
  const list = [];
  for (const [id, c] of Object.entries(CAST)) {
    for (const pose of ['idle', 'attack']) {
      list.push([`chars/${id}_${pose}.png`, character(c, pose, id), 440, 520, 2]);
    }
  }
  for (const [name, s, w, h] of scenes()) {
    list.push([`scenes/${name}.png`, s, w, h, name.startsWith('bg_') ? 1.5 : 1]);
  }
  for (const [name, s] of icons()) list.push([`icons/${name}.png`, s, 160, 160, 2]);
  const picked = only ? list.filter(([f]) => [...only].some((o) => f.includes(o))) : list;
  // 한 쪽에 여러 그림을 놓아도 id 가 겹치지 않게 그림마다 앞머리를 붙인다.
  return picked.map(([f, s, w, h, k], i) => [
    f,
    s.replace(/id="([\w-]+)"/g, `id="p${i}_$1"`).replace(/url\(#([\w-]+)\)/g, `url(#p${i}_$1)`),
    w,
    h,
    k,
  ]);
}

const browser = await pw.chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1 });
const done = [];
const webp = !args.includes('--png');
for (const [file, s, w, h, k = 1] of jobs()) {
  // 폰 화면(밀도 3배)에서 또렷하도록 k 배 크게 그린다. 앱은 WebP 로 받는다(용량).
  const W = Math.round(w * k), H = Math.round(h * k);
  await page.setViewportSize({ width: W, height: H });
  const big = s.replace(/width="\d+" height="\d+"/, `width="${W}" height="${H}"`);
  await page.setContent(`<html><body style="margin:0;background:transparent">${big}</body></html>`);
  const buf = await page.locator('svg').screenshot({ omitBackground: true });
  const path = join(out, file);
  mkdirSync(join(path, '..'), { recursive: true });
  writeFileSync(path, buf);
  if (webp) {
    const wp = path.replace(/\.png$/, '.webp');
    // 하늘 그라데이션은 품질 97 아래에서 줄무늬가 보였다(2026-10-11 비교).
    const q = file.includes('/bg_') ? '97' : '86';
    execFileSync('ffmpeg', ['-v', 'error', '-y', '-i', path, '-c:v', 'libwebp', '-quality', q, '-preset', 'picture',
      '-compression_level', '6', wp]);
    unlinkSync(path);
  }
  done.push([file, s, w, h]);
}
if (sheet) {
  // 한눈에 보기: 모두를 줄지어 놓은 미리보기.
  const cells = done
    .map(
      ([f, s, w, h]) =>
        `<div style="display:inline-block;margin:4px;text-align:center;font:12px sans-serif;color:#ccc">
        <div style="width:${Math.min(w, 260)}px;height:${(Math.min(w, 260) / w) * h}px">${s.replace(
          /width="\d+" height="\d+"/,
          'width="100%" height="100%"',
        )}</div>${f}</div>`,
    )
    .join('');
  await page.setViewportSize({ width: 1400, height: 800 });
  await page.setContent(`<html><body style="margin:8px;background:#3a2c20">${cells}</body></html>`);
  await page.screenshot({ path: sheet, fullPage: true });
}
await browser.close();
console.log(`그림 ${done.length}장 → ${out}`);
