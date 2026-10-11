// 캐릭터 그림(작은 몸·큰 머리 무협 인물). 한 틀(rig)에 머리·옷·소품만 바꿔 모두를 그린다.
// 자세: idle(서 있기) · attack(검지로 튕기기, 손끝에 기).
import { INK, shade, vgrad, rgrad, stroke, svg, resetIds, fx } from './lib.mjs';

const SKIN = '#f3cfa6';

/** 한 사람을 그린다. c: 아래 CAST 의 한 줄. */
export function character(c, pose = 'idle', id = 'c') {
  resetIds(`${id}${pose[0]}`);
  const defs = [];
  const add = (g) => (defs.push(g.def), `url(#${g.id})`);
  const W = c.build === 'big' ? 1.18 : c.build === 'round' ? 1.3 : c.build === 'slim' ? 0.9 : 1;
  const X = (x) => 200 + (x - 200) * W; // 몸통 가로 폭
  const atk = pose === 'attack';
  const skin = c.skin ?? SKIN;
  const fSkin = add(rgrad(skin, 0.25, -0.18, 0.4, 0.35));
  const fRobe = add(vgrad(c.robe, 0.18, -0.3));
  const fRobe2 = add(vgrad(c.robe2 ?? shade(c.robe, -0.25), 0.1, -0.3));
  const fHair = add(vgrad(c.hairColor ?? '#2b2420', 0.25, -0.2));
  const fBelt = add(vgrad(c.belt ?? '#c8a24a', 0.3, -0.25));
  const parts = [];

  // 바닥 그림자.
  parts.push(`<ellipse cx="200" cy="500" rx="${105 * W}" ry="16" fill="#000" opacity="0.28"/>`);

  // ─ 뒤쪽 소품(등 뒤 칼·머리 꽁지·긴 머리).
  if (c.sword) {
    parts.push(`<g transform="rotate(-28 200 330)">
      <rect x="192" y="170" width="16" height="230" rx="5" fill="${add(vgrad('#3b3b48'))}" ${stroke(4)}/>
      <rect x="176" y="380" width="48" height="12" rx="5" fill="#c9a43c" ${stroke(4)}/>
      <rect x="194" y="390" width="12" height="40" rx="4" fill="#5a2c1c" ${stroke(4)}/></g>`);
  }
  if (c.hair === 'long' || c.hair === 'longTied') {
    parts.push(`<path d="M112 160 Q100 300 140 360 L260 360 Q300 300 288 160 Z" fill="${fHair}" ${stroke(5)}/>`);
  }
  if (c.hair === 'ponytail') {
    const sw = atk ? -30 : 0;
    parts.push(`<path d="M270 110 Q340 ${120 + sw} 335 ${215 + sw} Q320 ${280 + sw} 300 ${300 + sw} Q312 ${220 + sw} 280 150 Z"
      fill="${fHair}" ${stroke(5)}/>`);
  }
  if (c.cape) {
    parts.push(`<path d="M${X(135)} 262 Q${X(80)} 380 ${X(95)} 470 L${X(305)} 470 Q${X(320)} 380 ${X(265)} 262 Z"
      fill="${add(vgrad(c.cape, 0.1, -0.35))}" ${stroke(5)}/>`);
  }

  // ─ 다리·신.
  const legY = 430;
  for (const [x, s] of [[X(170), -1], [X(230), 1]]) {
    const off = atk ? s * 10 : 0;
    parts.push(`<path d="M${x - 20} ${legY} L${x - 18 + off} 482 L${x + 18 + off} 482 L${x + 20} ${legY} Z"
      fill="${fRobe2}" ${stroke(5)}/>`);
    parts.push(`<ellipse cx="${x + off + s * 6}" cy="488" rx="27" ry="13" fill="${add(vgrad('#2d2622', 0.3, -0.2))}" ${stroke(5)}/>`);
  }

  // ─ 몸통(도포). 어깨 → 허리 → 넓게 퍼지는 아랫단.
  const hem = c.build === 'round' ? 448 : 452;
  parts.push(`<path d="M${X(145)} 258 Q200 246 ${X(255)} 258
      Q${X(285)} 290 ${X(282)} 340 Q${X(300)} 400 ${X(298)} ${hem}
      Q200 ${hem + 14} ${X(102)} ${hem} Q${X(100)} 400 ${X(118)} 340
      Q${X(115)} 290 ${X(145)} 258 Z" fill="${fRobe}" ${stroke(5)}/>`);
  const lit = add({ id: 'lit', def: '' });
  defs.pop();
  defs.push(`<linearGradient id="${lit.slice(5, -1)}" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#fff" stop-opacity="0.18"/><stop offset="0.45" stop-color="#fff" stop-opacity="0"/>
    <stop offset="0.62" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.28"/></linearGradient>`);
  parts.push(`<path d="M${X(145)} 258 Q200 246 ${X(255)} 258 Q${X(285)} 290 ${X(282)} 340 Q${X(300)} 400 ${X(298)} ${hem}
      Q200 ${hem + 14} ${X(102)} ${hem} Q${X(100)} 400 ${X(118)} 340 Q${X(115)} 290 ${X(145)} 258 Z" fill="${lit}"/>`);
  // 배 둥글게(통통).
  if (c.build === 'round') {
    parts.push(`<ellipse cx="200" cy="350" rx="${88 * W * 0.85}" ry="70" fill="${fRobe}" ${stroke(5)}/>`);
  }
  // 앞자락 선과 깃(흰 동정).
  parts.push(`<path d="M${X(165)} 262 L200 330 L${X(235)} 262" fill="none" stroke="#f6f0e2" stroke-width="16" stroke-linejoin="round"/>
    <path d="M${X(165)} 262 L200 330 L${X(235)} 262" fill="none" ${stroke(4)}/>
    <path d="M200 330 Q${X(212)} 400 ${X(230)} ${hem + 4}" fill="none" ${stroke(4)}/>`);
  if (c.apron) {
    parts.push(`<path d="M${X(150)} 345 L${X(250)} 345 L${X(262)} 440 Q200 452 ${X(138)} 440 Z" fill="${add(vgrad(c.apron))}" ${stroke(4)}/>`);
  }
  // 허리띠.
  parts.push(`<rect x="${X(116)}" y="328" width="${X(284) - X(116)}" height="24" rx="10" fill="${fBelt}" ${stroke(5)}/>
    <path d="M${X(222)} 350 q8 30 -4 58 M${X(236)} 350 q12 26 6 52" fill="none" stroke="${shade(c.belt ?? '#c8a24a', -0.2)}" stroke-width="9" stroke-linecap="round"/>`);
  if (c.beads) {
    for (let i = 0; i < 9; i++) {
      const a = Math.PI * (0.15 + 0.7 * (i / 8));
      const bx = 200 - Math.cos(a) * 52 * W, by = 262 + Math.sin(a) * 60;
      parts.push(`<circle cx="${bx}" cy="${by}" r="9" fill="${add(rgrad('#7a3b1e'))}" ${stroke(3)}/>`);
    }
  }
  if (c.fur) {
    parts.push(`<path d="M${X(130)} 266 q20 -22 40 -6 q20 -20 30 -4 q20 -18 30 -2 q22 -16 36 8 l-6 22 q-70 -14 -124 0 Z"
      fill="${add(vgrad(c.fur))}" ${stroke(4)}/>`);
  }

  // ─ 팔. 소매는 넓고 손은 둥글다.
  const sleeve = (d) => `<path d="${d}" fill="${fRobe}" ${stroke(5)}/>`;
  const hand = (x, y, r = 17) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fSkin}" ${stroke(4)}/>`;
  const leftIdle = () =>
    sleeve(`M${X(145)} 262 Q${X(100)} 290 ${X(96)} 360 L${X(140)} 372 Q${X(142)} 320 ${X(158)} 300 Z`) +
    hand(X(116), 378);
  const rightIdle = () =>
    sleeve(`M${X(255)} 262 Q${X(300)} 290 ${X(304)} 360 L${X(260)} 372 Q${X(258)} 320 ${X(242)} 300 Z`) +
    hand(X(284), 378);
  // 공격: 앞으로 뻗은 오른팔 끝에 검지를 세워 튕긴다.
  const rightAttack = () => {
    const hx = X(258) + 96, hy = 244;
    const q = c.qi ?? '#7fd6ff';
    return (
      sleeve(`M${X(250)} 262 Q${X(280)} 236 ${hx - 26} 226 L${hx - 22} 266 Q${X(280)} 276 ${X(250)} 304 Z`) +
      `<circle cx="${hx + 34}" cy="${hy - 6}" r="34" fill="${q}" opacity="0.75" filter="${fx('glow')}"/>` +
      `<circle cx="${hx + 34}" cy="${hy - 6}" r="12" fill="#fff" opacity="0.9" filter="${fx('soft')}"/>` +
      `<path d="M${hx + 46} ${hy - 30} l26 -10 M${hx + 52} ${hy - 4} l32 0 M${hx + 46} ${hy + 18} l26 10"
         stroke="${q}" stroke-width="6" stroke-linecap="round"/>` +
      hand(hx, hy, 18) +
      // 검지(앞으로) + 엄지.
      `<rect x="${hx + 6}" y="${hy - 13}" width="28" height="11" rx="5.5" fill="${fSkin}" ${stroke(3.5)}/>
       <path d="M${hx - 4} ${hy - 16} q8 -10 16 -4" fill="none" ${stroke(3.5)}/>`
    );
  };
  const leftAttack = () =>
    sleeve(`M${X(145)} 262 Q${X(104)} 286 ${X(112)} 330 L${X(150)} 344 Q${X(150)} 312 ${X(160)} 298 Z`) +
    hand(X(140), 344);

  parts.push(atk ? leftAttack() : leftIdle());
  if (!atk) parts.push(rightIdle());

  // ─ 머리.
  const hx = 200, hy = 165, hr = 92;
  parts.push(`<rect x="183" y="236" width="34" height="26" fill="${fSkin}" ${stroke(4)}/>`); // 목
  // 귀.
  parts.push(`<ellipse cx="${hx - hr + 4}" cy="${hy + 14}" rx="16" ry="20" fill="${fSkin}" ${stroke(4)}/>
    <ellipse cx="${hx + hr - 4}" cy="${hy + 14}" rx="16" ry="20" fill="${fSkin}" ${stroke(4)}/>`);
  // 얼굴(살짝 아래가 좁은 둥근 모양).
  parts.push(`<path d="M${hx - hr} ${hy} Q${hx - hr} ${hy - hr} ${hx} ${hy - hr} Q${hx + hr} ${hy - hr} ${hx + hr} ${hy}
      Q${hx + hr - 6} ${hy + hr - 6} ${hx} ${hy + hr} Q${hx - hr + 6} ${hy + hr - 6} ${hx - hr} ${hy} Z" fill="${fSkin}" ${stroke(5)}/>`);
  // 볼 홍조.
  const blush = c.drunk ? 0.7 : 0.3;
  parts.push(`<ellipse cx="${hx - 52}" cy="${hy + 42}" rx="18" ry="10" fill="#ff7a7a" opacity="${blush}"/>
    <ellipse cx="${hx + 52}" cy="${hy + 42}" rx="18" ry="10" fill="#ff7a7a" opacity="${blush}"/>`);

  // 눈.
  const eyes = atk && c.eyes !== 'closed' ? 'fierce' : c.eyes ?? 'round';
  const ex = 36, ey = hy + 14;
  const iris = c.iris ?? '#3a2a20';
  for (const s of [-1, 1]) {
    const x = hx + s * ex;
    if (eyes === 'closed') {
      parts.push(`<path d="M${x - 16} ${ey} Q${x} ${ey + 12} ${x + 16} ${ey}" fill="none" ${stroke(5)}/>`);
    } else if (eyes === 'happy') {
      parts.push(`<path d="M${x - 15} ${ey + 4} Q${x} ${ey - 14} ${x + 15} ${ey + 4}" fill="none" ${stroke(5)}/>`);
    } else {
      const ry = eyes === 'fierce' ? 15 : eyes === 'narrow' ? 9 : 19;
      parts.push(`<ellipse cx="${x}" cy="${ey}" rx="15" ry="${ry}" fill="#fff" ${stroke(4)}/>
        <ellipse cx="${x + s * 2}" cy="${ey + 2}" rx="10" ry="${Math.min(ry - 2, 14)}" fill="${iris}"/>
        <ellipse cx="${x + s * 2}" cy="${ey + 3}" rx="5" ry="${Math.min(ry - 6, 8)}" fill="#120c08"/>
        <circle cx="${x - 3}" cy="${ey - 5}" r="4.5" fill="#fff"/>
        <circle cx="${x + 5}" cy="${ey + 6}" r="2" fill="#fff" opacity="0.8"/>`);
      if (eyes === 'fierce') {
        // 위 눈꺼풀을 비스듬히(성난 눈).
        // 콧등 쪽(안쪽)이 낮고 바깥이 높다.
        const yo = ey - 17, yi = ey - 4;
        parts.push(`<path d="M${x + s * 19} ${yo} L${x - s * 19} ${yi} L${x - s * 19} ${ey - 28} L${x + s * 19} ${ey - 28} Z" fill="${fSkin}"/>
          <path d="M${x + s * 18} ${yo} L${x - s * 18} ${yi}" ${stroke(5.5)}/>`);
      }
    }
    // 눈썹.
    const bw = c.brow === 'thick' ? 9 : c.brow === 'white' ? 8 : 5.5;
    const bc = c.brow === 'white' ? '#f2f2f2' : c.hairColor ?? INK;
    const tilt = eyes === 'fierce' ? -s * 14 : c.brow === 'white' ? -s * 6 : 0;
    const by = ey - 30;
    if (c.brow === 'white') {
      parts.push(`<path d="M${x - s * 14} ${by + tilt} Q${x + s * 8} ${by - 8} ${x + s * 34} ${by + 16}" fill="none"
        stroke="${INK}" stroke-width="${bw + 6}" stroke-linecap="round"/>
        <path d="M${x - s * 14} ${by + tilt} Q${x + s * 8} ${by - 8} ${x + s * 34} ${by + 16}" fill="none"
        stroke="${bc}" stroke-width="${bw}" stroke-linecap="round"/>`);
    } else {
      parts.push(`<path d="M${x - 16} ${by - (s < 0 ? tilt : -tilt) * 0} L${x + 16} ${by}" transform="rotate(${tilt} ${x} ${by})"
        stroke="${bc}" stroke-width="${bw}" stroke-linecap="round"/>`);
    }
  }
  if (c.glasses) {
    parts.push(`<circle cx="${hx - ex}" cy="${ey}" r="24" fill="#bfe3ff" fill-opacity="0.15" ${stroke(4)}/>
      <circle cx="${hx + ex}" cy="${ey}" r="24" fill="#bfe3ff" fill-opacity="0.15" ${stroke(4)}/>
      <path d="M${hx - 12} ${ey - 2} Q${hx} ${ey - 8} ${hx + 12} ${ey - 2}" fill="none" ${stroke(4)}/>`);
  }
  // 코·입.
  parts.push(`<path d="M${hx - 2} ${hy + 40} q5 4 0 7" fill="none" stroke="${shade(skin, -0.35)}" stroke-width="3.5" stroke-linecap="round"/>`);
  const my = hy + 62;
  const mouth = atk ? 'shout' : c.mouth ?? 'smile';
  if (mouth === 'shout') {
    parts.push(`<path d="M${hx - 15} ${my - 4} Q${hx} ${my - 8} ${hx + 15} ${my - 4} Q${hx + 10} ${my + 16} ${hx} ${my + 16} Q${hx - 10} ${my + 16} ${hx - 15} ${my - 4} Z"
      fill="#7a2b26" ${stroke(4)}/><path d="M${hx - 8} ${my + 10} q8 -6 16 0" fill="#ff8f8f"/>`);
  } else if (mouth === 'grin') {
    parts.push(`<path d="M${hx - 20} ${my - 4} Q${hx} ${my + 16} ${hx + 20} ${my - 4} Z" fill="#fff" ${stroke(4)}/>`);
  } else if (mouth === 'flat') {
    parts.push(`<path d="M${hx - 12} ${my} L${hx + 12} ${my - 2}" ${stroke(4.5)}/>`);
  } else if (mouth === 'smirk') {
    parts.push(`<path d="M${hx - 14} ${my} Q${hx + 2} ${my + 6} ${hx + 16} ${my - 7}" fill="none" ${stroke(4.5)}/>`);
  } else {
    parts.push(`<path d="M${hx - 14} ${my - 2} Q${hx} ${my + 12} ${hx + 14} ${my - 2}" fill="none" ${stroke(4.5)}/>`);
  }
  if (c.mask) {
    parts.push(`<path d="M${hx - hr + 2} ${hy + 22} Q${hx} ${hy + 34} ${hx + hr - 2} ${hy + 22}
      Q${hx + hr - 10} ${hy + hr - 8} ${hx} ${hy + hr} Q${hx - hr + 10} ${hy + hr - 8} ${hx - hr + 2} ${hy + 22} Z"
      fill="${add(vgrad(c.mask, 0.15, -0.3))}" ${stroke(5)}/>`);
  }
  if (c.beard) {
    const bc = c.beard;
    parts.push(`<path d="M${hx - 50} ${hy + 50} Q${hx - 40} ${hy + 150} ${hx} ${hy + 175} Q${hx + 40} ${hy + 150} ${hx + 50} ${hy + 50}
      Q${hx + 20} ${hy + 76} ${hx} ${hy + 72} Q${hx - 20} ${hy + 76} ${hx - 50} ${hy + 50} Z"
      fill="${add(vgrad(bc, 0.3, -0.15))}" ${stroke(4.5)}/>
      <path d="M${hx - 30} ${hy + 56} Q${hx} ${hy + 46} ${hx + 30} ${hy + 56} Q${hx + 10} ${hy + 64} ${hx} ${hy + 60} Q${hx - 10} ${hy + 64} ${hx - 30} ${hy + 56} Z"
      fill="${bc}" ${stroke(3.5)}/>`);
  }

  // ─ 앞머리·머리 모양.
  parts.push(hairFront(c, hx, hy, hr, fHair, add));
  // ─ 머리 위 소품.
  if (c.headband) {
    parts.push(`<path d="M${hx - hr + 2} ${hy - 30} Q${hx} ${hy - 50} ${hx + hr - 2} ${hy - 30} L${hx + hr - 4} ${hy - 12} Q${hx} ${hy - 32} ${hx - hr + 4} ${hy - 12} Z"
      fill="${add(vgrad(c.headband))}" ${stroke(4)}/>
      <path d="M${hx + hr - 6} ${hy - 22} q${atk ? 50 : 30} ${atk ? -10 : 20} ${atk ? 70 : 40} ${atk ? 6 : 60}" fill="none" stroke="${c.headband}" stroke-width="12" stroke-linecap="round"/>`);
  }
  if (c.hat === 'gat') {
    parts.push(`<ellipse cx="${hx}" cy="${hy - 70}" rx="150" ry="26" fill="#1a1514" fill-opacity="0.85" ${stroke(4)}/>
      <path d="M${hx - 52} ${hy - 72} L${hx - 44} ${hy - 150} Q${hx} ${hy - 162} ${hx + 44} ${hy - 150} L${hx + 52} ${hy - 72} Z" fill="#1a1514" fill-opacity="0.9" ${stroke(4)}/>
      <path d="M${hx - 70} ${hy - 60} Q${hx - 90} ${hy + 40} ${hx - 70} ${hy + 120}" fill="none" stroke="#d9b45c" stroke-width="4" stroke-dasharray="2 8" stroke-linecap="round"/>`);
  }
  if (c.hat === 'satgat') {
    parts.push(`<path d="M${hx - 150} ${hy - 40} L${hx} ${hy - 150} L${hx + 150} ${hy - 40} Q${hx} ${hy - 62} ${hx - 150} ${hy - 40} Z"
      fill="${add(vgrad('#c9a46a', 0.25, -0.3))}" ${stroke(5)}/>
      <path d="M${hx - 75} ${hy - 95} L${hx} ${hy - 150} L${hx + 75} ${hy - 95}" fill="none" stroke="${shade('#c9a46a', -0.35)}" stroke-width="3"/>`);
  }
  if (c.crown) {
    parts.push(`<path d="M${hx - 46} ${hy - 78} L${hx - 52} ${hy - 128} L${hx - 22} ${hy - 104} L${hx} ${hy - 140} L${hx + 22} ${hy - 104} L${hx + 52} ${hy - 128} L${hx + 46} ${hy - 78} Z"
      fill="${add(vgrad(c.crown, 0.4, -0.25))}" ${stroke(5)}/>
      <circle cx="${hx}" cy="${hy - 96}" r="9" fill="#d23c3c" ${stroke(3)}/>`);
  }
  if (c.horns) {
    for (const s of [-1, 1]) {
      parts.push(`<path d="M${hx + s * 50} ${hy - 70} Q${hx + s * 90} ${hy - 120} ${hx + s * 70} ${hy - 160} Q${hx + s * 70} ${hy - 110} ${hx + s * 34} ${hy - 82} Z"
        fill="${add(vgrad('#3a2346', 0.3, -0.3))}" ${stroke(4.5)}/>`);
    }
  }
  if (c.flower) {
    parts.push(flower(hx + 60, hy - 64, c.flower));
  }
  if (c.gourd && !atk) {
    parts.push(`<g transform="rotate(-20 ${X(116)} 378)">
      <circle cx="${X(110)}" cy="410" r="22" fill="${add(rgrad('#d9a441'))}" ${stroke(4)}/>
      <circle cx="${X(110)}" cy="378" r="14" fill="${add(rgrad('#d9a441'))}" ${stroke(4)}/>
      <rect x="${X(104)}" y="356" width="12" height="10" fill="#a33" ${stroke(3)}/></g>`);
  }
  if (c.fan && !atk) {
    parts.push(`<path d="M${X(284)} 378 L${X(250)} 300 A80 80 0 0 1 ${X(334)} 318 Z" fill="${add(vgrad('#f4ead2', 0.2, -0.1))}" ${stroke(4)}/>
      <path d="M${X(284)} 378 L${X(272)} 306 M${X(284)} 378 L${X(296)} 304 M${X(284)} 378 L${X(318)} 310" ${stroke(2.5)}/>` + hand(X(284), 378));
  }
  if (c.staff && !atk) {
    parts.push(`<rect x="${X(76)}" y="190" width="14" height="300" rx="7" fill="${add(vgrad('#7b4a26'))}" ${stroke(4)}/>` + hand(X(84), 360));
  }

  if (atk) parts.push(rightAttack());

  // 공격 자세는 몸을 앞으로 살짝 기울인다.
  const body = atk ? `<g transform="rotate(-4 200 490)">${parts.join('\n')}</g>` : parts.join('\n');
  return svg(440, 520, defs, body, -20);
}

function flower(x, y, color) {
  let p = '';
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2;
    p += `<circle cx="${x + Math.cos(a) * 11}" cy="${y + Math.sin(a) * 11}" r="9" fill="${color}" ${stroke(2.5)}/>`;
  }
  return p + `<circle cx="${x}" cy="${y}" r="6" fill="#ffd34d" ${stroke(2.5)}/>`;
}

function hairFront(c, hx, hy, hr, fHair, add) {
  const st = stroke(5);
  // 머리 윗부분을 덮는 모양(이마 선이 약간 물결).
  const cap = `<path d="M${hx - hr - 4} ${hy + 6} Q${hx - hr - 6} ${hy - hr - 10} ${hx} ${hy - hr - 12} Q${hx + hr + 6} ${hy - hr - 10} ${hx + hr + 4} ${hy + 6}
      Q${hx + hr - 14} ${hy - 34} ${hx + 50} ${hy - 44} Q${hx + 26} ${hy - 30} ${hx + 12} ${hy - 50}
      Q${hx - 10} ${hy - 30} ${hx - 34} ${hy - 46} Q${hx - 60} ${hy - 30} ${hx - hr + 10} ${hy - 30} Z" fill="${fHair}" ${st}/>`;
  const shine = `<path d="M${hx - 50} ${hy - 76} Q${hx - 20} ${hy - 92} ${hx + 16} ${hy - 86}" fill="none" stroke="#fff" stroke-opacity="0.35" stroke-width="7" stroke-linecap="round"/>`;
  switch (c.hair) {
    case 'bald':
      return `<path d="M${hx - 46} ${hy - 62} Q${hx - 26} ${hy - 82} ${hx} ${hy - 80}" fill="none" stroke="#fff" stroke-opacity="0.6" stroke-width="9" stroke-linecap="round"/>` +
        (c.dots ? [-24, 0, 24].map((d) => `<circle cx="${hx + d}" cy="${hy - 58}" r="5" fill="${shade(c.skin ?? SKIN, -0.3)}"/>`).join('') : '');
    case 'topknot':
      return cap + shine +
        `<circle cx="${hx}" cy="${hy - hr - 26}" r="28" fill="${fHair}" ${st}/>
         <rect x="${hx - 22}" y="${hy - hr - 6}" width="44" height="12" rx="5" fill="${c.pin ?? '#c9a43c'}" ${stroke(4)}/>
         <path d="M${hx - 44} ${hy - hr - 34} L${hx + 44} ${hy - hr - 18}" stroke="${c.pin ?? '#c9a43c'}" stroke-width="7" stroke-linecap="round"/>`;
    case 'twinbuns':
      return `<circle cx="${hx - 70}" cy="${hy - 78}" r="30" fill="${fHair}" ${st}/>
         <circle cx="${hx + 70}" cy="${hy - 78}" r="30" fill="${fHair}" ${st}/>` + cap + shine;
    case 'spiky':
      return `<path d="M${hx - hr - 6} ${hy + 4} L${hx - 120} ${hy - 60} L${hx - 70} ${hy - 80} L${hx - 80} ${hy - 140}
        L${hx - 20} ${hy - 104} L${hx + 6} ${hy - 160} L${hx + 34} ${hy - 104} L${hx + 96} ${hy - 136}
        L${hx + 78} ${hy - 76} L${hx + 128} ${hy - 56} L${hx + hr + 6} ${hy + 4}
        Q${hx + 60} ${hy - 40} ${hx + 40} ${hy - 30} L${hx + 20} ${hy - 56} L${hx} ${hy - 26} L${hx - 26} ${hy - 58} L${hx - 50} ${hy - 26} Q${hx - 70} ${hy - 30} ${hx - hr - 6} ${hy + 4} Z"
        fill="${fHair}" ${st}/>` + shine;
    case 'wild':
      return `<path d="M${hx - hr - 14} ${hy + 20} Q${hx - 140} ${hy - 30} ${hx - 100} ${hy - 70} Q${hx - 120} ${hy - 120} ${hx - 60} ${hy - 120}
        Q${hx - 40} ${hy - 160} ${hx + 4} ${hy - 130} Q${hx + 50} ${hy - 162} ${hx + 70} ${hy - 116} Q${hx + 130} ${hy - 110} ${hx + 104} ${hy - 60}
        Q${hx + 140} ${hy - 20} ${hx + hr + 14} ${hy + 20} Q${hx + 70} ${hy - 30} ${hx + 30} ${hy - 40} Q${hx + 10} ${hy - 20} ${hx - 10} ${hy - 46}
        Q${hx - 40} ${hy - 24} ${hx - 60} ${hy - 40} Q${hx - 90} ${hy - 20} ${hx - hr - 14} ${hy + 20} Z" fill="${fHair}" ${st}/>` + shine;
    case 'long':
    case 'ponytail':
    case 'longTied':
    default:
      return cap + shine +
        (c.hair === 'ponytail' ? `<rect x="${hx + 54}" y="${hy - 96}" width="26" height="18" rx="6" transform="rotate(35 ${hx + 67} ${hy - 87})" fill="${c.pin ?? '#d64545'}" ${stroke(4)}/>` : '') +
        (c.hair === 'long' ? `<path d="M${hx - hr - 4} ${hy + 6} Q${hx - hr - 12} ${hy + 60} ${hx - hr + 4} ${hy + 90} L${hx - hr + 18} ${hy - 10} Z" fill="${fHair}" ${st}/>
          <path d="M${hx + hr + 4} ${hy + 6} Q${hx + hr + 12} ${hy + 60} ${hx + hr - 4} ${hy + 90} L${hx + hr - 18} ${hy - 10} Z" fill="${fHair}" ${st}/>` : '');
  }
}

/** 등장인물. id 는 앱의 Fighter 이름·고수 이름과 같다. */
export const CAST = {
  // 고를 수 있는 캐릭터(Fighter).
  seokdu: { robe: '#8a5a2b', belt: '#3d2a1c', hair: 'bald', dots: true, build: 'big', brow: 'thick', mouth: 'grin', qi: '#ffb347' },
  yeonbi: { robe: '#3d8fd1', robe2: '#24527a', belt: '#f2f2f2', hair: 'ponytail', pin: '#ff5c7a', build: 'slim', mouth: 'smile', iris: '#4a2f78', qi: '#9ee6ff' },
  cheongmyeong: { robe: '#e9eef2', robe2: '#8fb3c9', belt: '#4d7a94', hair: 'long', hairColor: '#24303a', eyes: 'narrow', mouth: 'flat', qi: '#b8f3ff' },
  banDal: { robe: '#e0a33b', belt: '#7a3b1e', hair: 'topknot', pin: '#f5e6a0', build: 'round', apron: '#f4ead2', eyes: 'happy', mouth: 'grin', qi: '#ffd66b' },
  gurumi: { robe: '#4f8a3a', belt: '#8a6a3a', hair: 'wild', hairColor: '#5a3a22', fur: '#a07a52', mouth: 'grin', qi: '#a6f07a' },
  jeonggak: { robe: '#5b5f8a', belt: '#c9a43c', hair: 'topknot', glasses: true, eyes: 'round', mouth: 'flat', qi: '#c7b8ff' },
  yonga: { robe: '#c23a2b', robe2: '#6e1d16', belt: '#e8c25a', hair: 'spiky', headband: '#e8c25a', brow: 'thick', mouth: 'smirk', iris: '#b5651d', qi: '#ff7a3d' },
  seolhwa: { robe: '#f4f7fb', robe2: '#9fb7d6', belt: '#7fa7d9', hair: 'long', hairColor: '#cfd8e6', flower: '#ffffff', build: 'slim', iris: '#5b86c7', qi: '#d8f4ff' },
  chwiseon: { robe: '#a0623a', belt: '#e0c070', hair: 'topknot', hairColor: '#7d7d7d', beard: '#9a9a9a', drunk: true, eyes: 'happy', gourd: true, mouth: 'grin', qi: '#ffcf6b' },
  mukgaek: { robe: '#2c2f38', robe2: '#15171c', belt: '#8a1f1f', hair: 'long', hat: 'satgat', sword: true, eyes: 'narrow', mouth: 'flat', qi: '#9aa6ff' },
  magyo: { robe: '#4b2357', robe2: '#22102a', belt: '#b0303a', hair: 'long', hairColor: '#1a1020', horns: true, cape: '#2a0f33', iris: '#c0303a', mouth: 'smirk', qi: '#d14bff' },
  geomhwang: { robe: '#d9b54a', robe2: '#8a6a1c', belt: '#3a2a1a', hair: 'longTied', hairColor: '#e8e8e8', sword: true, cape: '#b0302a', brow: 'thick', mouth: 'flat', qi: '#fff2a6' },
  sinseung: { robe: '#e07a1f', robe2: '#9a4a10', belt: '#7a2a10', hair: 'bald', dots: true, beads: true, eyes: 'closed', mouth: 'smile', qi: '#ffe08a' },
  // 강호행 고수·숙적.
  chonjang: { robe: '#6f7f6a', belt: '#3d3d3d', hair: 'topknot', hairColor: '#dcdcdc', beard: '#eeeeee', brow: 'white', hat: 'gat', eyes: 'happy', mouth: 'smile', qi: '#c8ffb0' },
  tongtong: { robe: '#d8562c', belt: '#4a2a1a', hair: 'topknot', build: 'round', apron: '#fff4dd', eyes: 'happy', mouth: 'grin', headband: '#ffffff', qi: '#ffb36b' },
  mukhyeon: { robe: '#1f2230', robe2: '#0c0d14', belt: '#6a2ad1', hair: 'long', hairColor: '#0f1018', cape: '#2a1b4a', eyes: 'fierce', iris: '#7b3cff', mouth: 'smirk', qi: '#8b5cff' },
  jagaek: { robe: '#2a2a2a', robe2: '#111111', belt: '#7a1010', hair: 'ponytail', mask: '#1a1a1a', headband: '#7a1010', eyes: 'narrow', iris: '#d14040', qi: '#ff4d4d' },
  kubi: { robe: '#5c4a2a', belt: '#2f2414', hair: 'wild', hairColor: '#3a2410', fur: '#8a6a3a', build: 'big', brow: 'thick', skin: '#e0b085', mouth: 'grin', qi: '#9be36b' },
  logic: { robe: '#2f4f6f', robe2: '#1b2f45', belt: '#d9c27a', hair: 'topknot', glasses: true, beard: '#2b2420', fan: true, eyes: 'narrow', mouth: 'flat', qi: '#7ad8ff' },
  maengju: { robe: '#e8c25a', robe2: '#8a6a1c', belt: '#7a1f1f', hair: 'longTied', hairColor: '#ececec', beard: '#f0f0f0', brow: 'white', crown: '#e8c25a', cape: '#8a1f1f', build: 'big', mouth: 'flat', qi: '#ffe27a' },
  // 입문 사부.
  sabu: { robe: '#6d8199', robe2: '#3a4a5c', belt: '#c9a43c', hair: 'topknot', hairColor: '#e6e6e6', beard: '#f2f2f2', brow: 'white', staff: true, eyes: 'happy', mouth: 'smile', qi: '#bff0ff' },
};
