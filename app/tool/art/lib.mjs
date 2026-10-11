// 그림 공용 도우미: 색 섞기·그라데이션·외곽선.
// 그림은 손으로 쓴 SVG 를 코드로 조립한 것이다(저작권 걱정 없는 자체 제작).

export const INK = '#2a1a12';

/** '#rrggbb' 를 t(−1 어둡게 … +1 밝게)만큼. */
export function shade(hex, t) {
  const n = parseInt(hex.slice(1), 16);
  let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  const to = t > 0 ? 255 : 0;
  const k = Math.abs(t);
  r = Math.round(r + (to - r) * k);
  g = Math.round(g + (to - g) * k);
  b = Math.round(b + (to - b) * k);
  return '#' + ((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1);
}

let gid = 0;
let pre = 'a';
/** 그림마다 id 앞머리를 달리한다(한 쪽에 여러 그림을 놓아도 그라데이션이 섞이지 않게). */
export function resetIds(prefix = 'a') {
  gid = 0;
  pre = prefix;
}

/** 위가 밝고 아래가 어두운 세로 그라데이션. defs 에 넣을 문자열과 id 를 돌려준다. */
export function vgrad(hex, light = 0.25, dark = -0.25) {
  const id = `${pre}${gid++}`;
  return {
    id,
    def: `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${shade(hex, light)}"/>
      <stop offset="1" stop-color="${shade(hex, dark)}"/></linearGradient>`,
  };
}

/** 왼쪽 위에서 빛이 오는 둥근 그라데이션(구슬·머리·돌). */
export function rgrad(hex, light = 0.45, dark = -0.35, cx = 0.35, cy = 0.3) {
  const id = `${pre}${gid++}`;
  return {
    id,
    def: `<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="0.8">
      <stop offset="0" stop-color="${shade(hex, light)}"/>
      <stop offset="0.55" stop-color="${hex}"/>
      <stop offset="1" stop-color="${shade(hex, dark)}"/></radialGradient>`,
  };
}

export const fx = (n) => `url(#${pre}${n})`;

export const stroke = (w = 5) =>
  `stroke="${INK}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`;

export function svg(w, h, defs, body, vx = 0) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vx} 0 ${w} ${h}" width="${w}" height="${h}">
<defs>${defs.join('\n')}
<filter id="${pre}glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter>
<filter id="${pre}soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="3"/></filter>
</defs>
${body}
</svg>`;
}
