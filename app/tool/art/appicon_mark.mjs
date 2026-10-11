// 앱 아이콘 그림 한 장(appicon.mjs 가 쓴다 · 크기 재기에도 쓴다).
import { stroke } from './lib.mjs';

/** 아이콘 그림(가운데 안전 영역 안): 검지가 흰 돌을 튕기고, 손끝에 기가 터진다. */
export function markSvg(size, { bg = true } = {}) {
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
