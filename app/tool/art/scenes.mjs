// 배경(세로 화면 720×1280)과 대전장 바닥(1024×1024).
// 산은 먹으로 번진 듯 여러 겹, 아래는 안개. 같은 씨앗이면 늘 같은 그림이 나온다.
import { shade, stroke, svg, resetIds, INK } from './lib.mjs';

function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

/** 산등성이 한 겹. base 높이에서 amp 만큼 들쭉날쭉. */
function ridge(r, w, h, base, amp, step, color, mist) {
  let d = `M0 ${h} L0 ${base}`;
  let y = base;
  for (let x = 0; x <= w + step; x += step) {
    const peak = r() < 0.25;
    y = base - (peak ? amp * (0.7 + r() * 0.5) : amp * r() * 0.6);
    const cx = x - step / 2;
    d += ` Q${cx} ${y - amp * 0.15} ${x} ${y}`;
  }
  d += ` L${w} ${h} Z`;
  const id = `m${Math.round(base)}${Math.round(amp)}`;
  return {
    def: `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${color}"/><stop offset="0.55" stop-color="${mist}"/></linearGradient>`,
    body: `<path d="${d}" fill="url(#${id})"/>`,
  };
}

function sky(w, h, top, mid, bottom) {
  return {
    def: `<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${top}"/><stop offset="0.55" stop-color="${mid}"/><stop offset="1" stop-color="${bottom}"/></linearGradient>`,
    body: `<rect width="${w}" height="${h}" fill="url(#sky)"/>`,
  };
}

function orb(x, y, r, color, glow) {
  return {
    def: `<radialGradient id="orb${x}" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="${glow}" stop-opacity="0.9"/><stop offset="1" stop-color="${glow}" stop-opacity="0"/></radialGradient>`,
    body: `<circle cx="${x}" cy="${y}" r="${r * 4}" fill="url(#orb${x})"/><circle cx="${x}" cy="${y}" r="${r}" fill="${color}"/>`,
  };
}

function clouds(r, w, y0, y1, n, color, op) {
  let b = '';
  for (let i = 0; i < n; i++) {
    const x = r() * w, y = y0 + r() * (y1 - y0), s = 0.6 + r() * 0.9;
    b += `<g opacity="${op}" fill="${color}"><ellipse cx="${x}" cy="${y}" rx="${90 * s}" ry="${18 * s}"/>
      <ellipse cx="${x - 40 * s}" cy="${y - 10 * s}" rx="${50 * s}" ry="${20 * s}"/>
      <ellipse cx="${x + 34 * s}" cy="${y - 14 * s}" rx="${44 * s}" ry="${22 * s}"/></g>`;
  }
  return b;
}

function pine(x, y, s, trunk, leaf) {
  let b = `<path d="M${x} ${y} q${-6 * s} ${-60 * s} ${4 * s} ${-120 * s} q${8 * s} ${-40 * s} ${-6 * s} ${-80 * s}" fill="none" stroke="${trunk}" stroke-width="${12 * s}" stroke-linecap="round"/>`;
  const tiers = [
    [-70, 150, 40], [-110, 120, 30], [-150, 160, 34], [-190, 110, 28],
  ];
  for (const [dy, wd, ht] of tiers) {
    const cx = x + (dy % 20) * s;
    b += `<ellipse cx="${cx}" cy="${y + dy * s}" rx="${(wd / 2) * s}" ry="${(ht / 2) * s}" fill="${leaf}"/>
      <ellipse cx="${cx - 10 * s}" cy="${y + (dy - 6) * s}" rx="${(wd / 3) * s}" ry="${(ht / 3.4) * s}" fill="${shade(leaf, 0.18)}"/>`;
  }
  return b;
}

/** 기와지붕 정자(로비·학당). */
function pavilion(x, y, s, roof, pillar) {
  return `<g transform="translate(${x} ${y}) scale(${s})">
    <rect x="-150" y="-30" width="300" height="30" fill="${shade(pillar, -0.3)}" ${stroke(4)}/>
    <rect x="-120" y="-190" width="18" height="160" fill="${pillar}" ${stroke(4)}/>
    <rect x="102" y="-190" width="18" height="160" fill="${pillar}" ${stroke(4)}/>
    <rect x="-40" y="-190" width="14" height="160" fill="${pillar}" ${stroke(4)}/>
    <rect x="26" y="-190" width="14" height="160" fill="${pillar}" ${stroke(4)}/>
    <rect x="-130" y="-200" width="260" height="22" fill="#2f6f5e" ${stroke(4)}/>
    <path d="M-210 -205 Q-150 -215 -120 -250 L120 -250 Q150 -215 210 -205 Q140 -225 120 -235 L-120 -235 Q-140 -225 -210 -205 Z"
      fill="${roof}" ${stroke(5)}/>
    <path d="M-120 -250 Q0 -320 120 -250 Z" fill="${shade(roof, 0.12)}" ${stroke(5)}/>
    <path d="M-110 -262 Q0 -306 110 -262" fill="none" stroke="${shade(roof, 0.35)}" stroke-width="4"/>
    </g>`;
}

function lantern(x, y, s = 1) {
  return `<g transform="translate(${x} ${y}) scale(${s})">
    <line x1="0" y1="-40" x2="0" y2="-14" stroke="${INK}" stroke-width="3"/>
    <circle cx="0" cy="12" r="40" fill="#ffb347" opacity="0.35"/>
    <ellipse cx="0" cy="12" rx="20" ry="26" fill="#e0402c" ${stroke(3)}/>
    <ellipse cx="0" cy="12" rx="10" ry="24" fill="none" stroke="#ffcf6b" stroke-width="2.5"/>
    <rect x="-9" y="-16" width="18" height="6" fill="#2a1a12"/><rect x="-9" y="36" width="18" height="6" fill="#2a1a12"/>
    <line x1="0" y1="42" x2="0" y2="62" stroke="#d9b45c" stroke-width="3"/></g>`;
}

function house(x, y, s, wall, roof) {
  return `<g transform="translate(${x} ${y}) scale(${s})">
    <rect x="-90" y="-80" width="180" height="80" fill="${wall}" ${stroke(4)}/>
    <rect x="-60" y="-60" width="40" height="40" fill="${shade(wall, -0.3)}" ${stroke(3)}/>
    <rect x="20" y="-70" width="44" height="70" fill="${shade(wall, -0.45)}" ${stroke(3)}/>
    <path d="M-120 -76 Q-60 -150 0 -158 Q60 -150 120 -76 Q0 -96 -120 -76 Z" fill="${roof}" ${stroke(4)}/>
    <path d="M-100 -96 Q0 -128 100 -96" fill="none" stroke="${shade(roof, -0.25)}" stroke-width="3"/></g>`;
}

function bamboo(x, y, hgt, color) {
  let b = `<rect x="${x - 7}" y="${y - hgt}" width="14" height="${hgt}" rx="6" fill="${color}"/>`;
  for (let k = y - 60; k > y - hgt; k -= 70) {
    b += `<rect x="${x - 9}" y="${k}" width="18" height="5" rx="2" fill="${shade(color, -0.25)}"/>
      <path d="M${x} ${k} q30 -14 56 -6 q-30 4 -56 6" fill="${shade(color, 0.1)}"/>`;
  }
  return b;
}

function flag(x, y, color, h = 120) {
  return `<line x1="${x}" y1="${y}" x2="${x}" y2="${y - h}" stroke="#5a3a22" stroke-width="6"/>
    <path d="M${x} ${y - h} q40 10 70 0 q-10 30 0 60 q-30 10 -70 0 Z" fill="${color}" ${stroke(3)}/>`;
}

function fireflies(r, w, y0, y1, n) {
  let b = '';
  for (let i = 0; i < n; i++) {
    const x = r() * w, y = y0 + r() * (y1 - y0);
    b += `<circle cx="${x}" cy="${y}" r="${10 + r() * 8}" fill="#d9ff7a" opacity="0.22"/><circle cx="${x}" cy="${y}" r="3" fill="#f5ffd0"/>`;
  }
  return b;
}

function snow(r, w, h, n) {
  let b = '';
  for (let i = 0; i < n; i++) {
    b += `<circle cx="${r() * w}" cy="${r() * h}" r="${1.5 + r() * 3.5}" fill="#fff" opacity="${0.4 + r() * 0.5}"/>`;
  }
  return b;
}

const W = 720, H = 1280;

function landscape(seed, pal, extra = () => '') {
  resetIds(`s${seed}`);
  const r = rng(seed);
  const defs = [], body = [];
  const push = (o) => (defs.push(o.def), body.push(o.body));
  push(sky(W, H, pal.sky[0], pal.sky[1], pal.sky[2]));
  if (pal.orb) push(orb(pal.orb[0], pal.orb[1], pal.orb[2], pal.orb[3], pal.orb[4]));
  body.push(clouds(r, W, 120, 420, 6, pal.cloud ?? '#fff', 0.35));
  const layers = pal.ridges;
  layers.forEach(([base, amp, step, color, mist]) => push(ridge(r, W, H, base, amp, step, color, mist)));
  body.push(extra(r));
  // 아래 안개 띠.
  defs.push(`<linearGradient id="fog" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${pal.fog}" stop-opacity="0"/><stop offset="1" stop-color="${pal.fog}" stop-opacity="0.85"/></linearGradient>`);
  body.push(`<rect y="${H * 0.62}" width="${W}" height="${H * 0.38}" fill="url(#fog)"/>`);
  // 화면 가장자리 어둡게(글자가 잘 보이게).
  defs.push(`<radialGradient id="vig" cx="0.5" cy="0.45" r="0.75">
    <stop offset="0.6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.45"/></radialGradient>`);
  body.push(`<rect width="${W}" height="${H}" fill="url(#vig)"/>`);
  // 종이 잔결: 그라데이션 줄무늬(WebP·8비트)를 흩뜨리고 화선지 느낌을 준다.
  defs.push(`<filter id="grain" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="${seed}"/>
    <feColorMatrix values="0 0 0 0 0.5  0 0 0 0 0.5  0 0 0 0 0.5  0 0 0 0.9 0"/></filter>`);
  body.push(`<rect width="${W}" height="${H}" filter="url(#grain)" opacity="0.10" style="mix-blend-mode:overlay"/>`);
  return svg(W, H, defs, body.join('\n'));
}

export function backgrounds() {
  return [
    // 로비: 해 질 녘 산문(山門) 앞.
    ['lobby', landscape(11, {
      sky: ['#2b1f4a', '#c4607a', '#f2b067'], orb: [520, 420, 56, '#ffe0a0', '#ffb36b'], cloud: '#ffd6c0',
      ridges: [[640, 260, 120, '#6d4a7a', '#c98a8a'], [760, 220, 90, '#4a3360', '#a0687a'], [900, 160, 70, '#2c2040', '#6a4a60']],
      fog: '#f0b8a0',
    }, (r) => pine(90, 1240, 1.5, '#2a1a12', '#1f3a2e') + pavilion(420, 1150, 1.25, '#3a3550', '#8a2b20') +
      pine(660, 1280, 1.2, '#2a1a12', '#24402f') + lantern(250, 930, 1.1) + lantern(590, 940, 1.1))],
    // 1장 흙먼지 마을: 맑은 낮, 초가.
    ['dustyYard', landscape(21, {
      sky: ['#5fa8e8', '#9fd0f0', '#f4e6c8'], orb: [140, 230, 50, '#fff7d6', '#fff0a0'],
      ridges: [[620, 220, 110, '#7aa0b8', '#cfe0e0'], [760, 160, 90, '#6d8f5a', '#c8d8b0'], [900, 90, 70, '#8a7a4a', '#d8c8a0']],
      fog: '#f0e0c0',
    }, (r) => house(180, 1060, 1.3, '#e6cfa0', '#b08850') + house(540, 1100, 1.1, '#e0c898', '#a07a44') + pine(660, 1200, 1, '#3a2a1a', '#3a6a3a'))],
    // 2장 통통 객잔: 밤, 등불.
    ['oilyTable', landscape(31, {
      sky: ['#120c20', '#3a2440', '#7a3a2a'], orb: [560, 210, 40, '#fff2c8', '#ffe0a0'], cloud: '#7a5a7a',
      ridges: [[700, 200, 100, '#2a2038', '#5a3a40'], [860, 140, 80, '#1c1424', '#3a2420']],
      fog: '#5a2a1a',
    }, (r) => house(360, 1150, 2.2, '#8a5a30', '#3a2a2a') + lantern(140, 820, 1.4) + lantern(360, 760, 1.6) + lantern(580, 820, 1.4))],
    // 3장 거북 장터: 오후, 깃발.
    ['turtleMarket', landscape(41, {
      sky: ['#f0a050', '#f6c890', '#f6e6c8'], orb: [600, 300, 46, '#fff0c0', '#ffd080'],
      ridges: [[640, 200, 100, '#a08070', '#e8d0b0'], [820, 140, 80, '#806050', '#d0b090']],
      fog: '#f0d8b0',
    }, (r) => flag(120, 1000, '#d23c3c') + flag(300, 980, '#2f6fae') + flag(470, 1000, '#e8c25a') + flag(640, 990, '#3a9a5a') +
      house(220, 1180, 1.2, '#d8b888', '#6a5a4a') + house(560, 1190, 1.2, '#d0b080', '#5a4a3a'))],
    // 4장 쿠비 숲: 짙은 녹음, 반딧불.
    ['kubiForest', landscape(51, {
      sky: ['#0e2a24', '#2a5a40', '#7aa070'], cloud: '#a0d0a0',
      ridges: [[560, 260, 100, '#2a5a40', '#6a9a70'], [760, 200, 80, '#1c4030', '#4a7050'], [920, 140, 60, '#10281c', '#2a4a30']],
      fog: '#a8d0a0',
    }, (r) => bamboo(60, 1280, 900, '#5a9a4a') + bamboo(130, 1280, 760, '#4a8a3a') + bamboo(620, 1280, 860, '#5a9a4a') +
      bamboo(680, 1280, 980, '#4a8a3a') + fireflies(r, W, 500, 1100, 22))],
    // 5장 로직 학당: 푸른 새벽, 정자.
    ['logicMarble', landscape(61, {
      sky: ['#1a2a5a', '#5a7ab0', '#d8e0f0'], orb: [150, 260, 36, '#ffffff', '#c0d8ff'], cloud: '#e0e8ff',
      ridges: [[600, 300, 130, '#4a5a8a', '#b0c0e0'], [780, 220, 100, '#3a4a70', '#90a0c8']],
      fog: '#e0e6f4',
    }, (r) => pavilion(360, 1120, 1.4, '#2a3a5a', '#e8e4dc') + pine(60, 1260, 1.2, '#2a1a12', '#2a4a4a'))],
    // 6장 무림맹 본단: 눈 덮인 설산, 깃발.
    ['murimIce', landscape(71, {
      sky: ['#0c1a34', '#3a5a8a', '#c8dcf0'], orb: [560, 220, 44, '#f4f8ff', '#bcd8ff'], cloud: '#d0e0ff',
      ridges: [[560, 340, 140, '#e8f0ff', '#90b0d8'], [760, 240, 100, '#c0d4f0', '#7090c0'], [920, 140, 70, '#8aa8d0', '#4a6a9a']],
      fog: '#d8e8f8',
    }, (r) => flag(160, 1020, '#d23c3c', 220) + flag(560, 1020, '#d23c3c', 220) + pavilion(360, 1160, 1.2, '#7a1f1f', '#d9b54a') +
      snow(r, W, H, 140))],
  ];
}

// ── 대전장 바닥(위에서 내려다본 그림).
const F = 1024;

function floor(seed, base, fn) {
  resetIds(`f${seed}`);
  const r = rng(seed);
  const defs = [`<radialGradient id="fl" cx="0.45" cy="0.4" r="0.75">
    <stop offset="0" stop-color="${shade(base, 0.12)}"/><stop offset="1" stop-color="${shade(base, -0.22)}"/></radialGradient>`];
  const body = [`<rect width="${F}" height="${F}" fill="url(#fl)"/>`, fn(r, defs)];
  return svg(F, F, defs, body.join('\n'));
}

function speckles(r, n, colors, rmin, rmax, op = 0.5) {
  let b = '';
  for (let i = 0; i < n; i++) {
    const c = colors[Math.floor(r() * colors.length)];
    b += `<ellipse cx="${r() * F}" cy="${r() * F}" rx="${rmin + r() * (rmax - rmin)}" ry="${rmin + r() * (rmax - rmin) * 0.7}"
      transform="rotate(${r() * 180} ${512} ${512})" fill="${c}" opacity="${op}"/>`;
  }
  return b;
}

export function floors() {
  return [
    // 흙 마당: 흙 얼룩·조약돌·풀.
    ['dustyYard', floor(101, '#b8925f', (r) => {
      let b = speckles(r, 160, ['#a07a48', '#c8a070', '#8a6a40'], 10, 60, 0.35);
      for (let i = 0; i < 70; i++) {
        const x = r() * F, y = r() * F, s = 4 + r() * 10;
        b += `<ellipse cx="${x}" cy="${y}" rx="${s}" ry="${s * 0.75}" fill="#9a8a78" stroke="#5a4a3a" stroke-width="1.5"/>
          <ellipse cx="${x - s * 0.3}" cy="${y - s * 0.3}" rx="${s * 0.35}" ry="${s * 0.2}" fill="#fff" opacity="0.4"/>`;
      }
      for (let i = 0; i < 40; i++) {
        const x = r() * F, y = r() * F;
        b += `<path d="M${x} ${y} l-6 -18 M${x} ${y} l2 -22 M${x} ${y} l9 -16" stroke="#6a8a3a" stroke-width="3" stroke-linecap="round"/>`;
      }
      return b;
    })],
    // 객잔 원탁: 나뭇결 + 기름 자국 반짝임.
    ['oilyTable', floor(102, '#8a5530', (r, defs) => {
      let b = '';
      for (let y = 0; y < F; y += 14) {
        let d = `M0 ${y}`;
        for (let x = 0; x <= F; x += 64) d += ` Q${x + 32} ${y + (r() - 0.5) * 14} ${x + 64} ${y + (r() - 0.5) * 6}`;
        b += `<path d="${d}" fill="none" stroke="${r() < 0.5 ? '#6a3a1e' : '#a06a40'}" stroke-width="${2 + r() * 3}" opacity="0.5"/>`;
      }
      for (let i = 0; i < 6; i++) {
        const x = 150 + r() * 720, y = 150 + r() * 720;
        b += `<ellipse cx="${x}" cy="${y}" rx="${30 + r() * 25}" ry="${20 + r() * 20}" fill="none" stroke="#5a2e14" stroke-width="3" opacity="0.6"/>`;
      }
      for (let i = 0; i < 14; i++) {
        const x = r() * F, y = r() * F, s = 30 + r() * 80;
        b += `<ellipse cx="${x}" cy="${y}" rx="${s}" ry="${s * 0.6}" fill="#ffe6a0" opacity="0.13"/>
          <ellipse cx="${x - s * 0.2}" cy="${y - s * 0.15}" rx="${s * 0.3}" ry="${s * 0.12}" fill="#fff" opacity="0.25"/>`;
      }
      return b;
    })],
    // 장터 돌바닥: 네모 돌 판.
    ['turtleMarket', floor(103, '#8f877c', (r) => {
      let b = '';
      const n = 8, s = F / n;
      for (let i = 0; i < n; i++) {
        for (let j = 0; j < n; j++) {
          const off = j % 2 ? s / 2 : 0;
          const c = shade('#8f877c', (r() - 0.5) * 0.25);
          b += `<rect x="${i * s + off - s + 4}" y="${j * s + 4}" width="${s - 8}" height="${s - 8}" rx="10" fill="${c}" stroke="#5a544c" stroke-width="5"/>
            <path d="M${i * s + off - s + 14} ${j * s + 14} h${s - 30}" stroke="#fff" stroke-opacity="0.18" stroke-width="5"/>`;
        }
      }
      return b + speckles(r, 120, ['#6a645c', '#b0a898'], 2, 6, 0.6);
    })],
    // 숲길: 흙 위 낙엽.
    ['kubiForest', floor(104, '#5e5a33', (r) => {
      let b = speckles(r, 100, ['#4a4626', '#706a3c', '#3a3a20'], 20, 70, 0.4);
      const leafC = ['#c0602a', '#d9a03a', '#8a3a1e', '#7a8a3a', '#a07a2a'];
      for (let i = 0; i < 140; i++) {
        const x = r() * F, y = r() * F, s = 10 + r() * 14, a = r() * 360;
        const c = leafC[Math.floor(r() * leafC.length)];
        b += `<g transform="translate(${x} ${y}) rotate(${a})"><path d="M0 ${-s} Q${s * 0.7} 0 0 ${s} Q${-s * 0.7} 0 0 ${-s} Z" fill="${c}" opacity="0.85"/>
          <line x1="0" y1="${-s}" x2="0" y2="${s}" stroke="${shade(c, -0.4)}" stroke-width="1.5"/></g>`;
      }
      return b;
    })],
    // 학당 대리석: 결 무늬.
    ['logicMarble', floor(105, '#e6e2da', (r) => {
      let b = '';
      for (let i = 0; i < 26; i++) {
        let x = r() * F, y = r() * F;
        let d = `M${x} ${y}`;
        for (let k = 0; k < 8; k++) {
          x += (r() - 0.3) * 140; y += (r() - 0.5) * 120;
          d += ` Q${x - 30} ${y + 20} ${x} ${y}`;
        }
        b += `<path d="${d}" fill="none" stroke="${r() < 0.5 ? '#a8a4a0' : '#c8c0b8'}" stroke-width="${1 + r() * 3}" opacity="0.6"/>`;
      }
      b += `<path d="M512 0 V1024 M0 512 H1024" stroke="#b8b0a4" stroke-width="4" opacity="0.6"/>`;
      return b;
    })],
    // 빙판: 갈라진 금·눈가루·반짝임.
    ['murimIce', floor(106, '#b9dceb', (r) => {
      let b = speckles(r, 80, ['#d8f0ff', '#a0c8e0'], 30, 120, 0.35);
      for (let i = 0; i < 18; i++) {
        let x = r() * F, y = r() * F, d = `M${x} ${y}`;
        for (let k = 0; k < 5; k++) { x += (r() - 0.5) * 160; y += (r() - 0.5) * 160; d += ` L${x} ${y}`; }
        b += `<path d="${d}" fill="none" stroke="#fff" stroke-width="2.5" opacity="0.7"/>
          <path d="${d}" fill="none" stroke="#7aa8c8" stroke-width="1" opacity="0.6" transform="translate(2 2)"/>`;
      }
      for (let i = 0; i < 40; i++) {
        const x = r() * F, y = r() * F, s = 4 + r() * 8;
        b += `<path d="M${x - s} ${y} L${x + s} ${y} M${x} ${y - s} L${x} ${y + s}" stroke="#fff" stroke-width="2" opacity="0.8"/>`;
      }
      return b;
    })],
  ];
}

export function scenes() {
  return [
    ...backgrounds().map(([n, s]) => [`bg_${n}`, s, W, H]),
    ...floors().map(([n, s]) => [`floor_${n}`, s, F, F]),
  ];
}
