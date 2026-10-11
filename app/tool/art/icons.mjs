// 아이콘 160×160: 재화·메뉴. 글을 읽지 않아도 그림으로 알아보게.
import { shade, vgrad, rgrad, stroke, svg, resetIds, fx } from './lib.mjs';

const S = 160;
const st = stroke(6);

function make(name, draw) {
  resetIds(`i${name}`);
  const defs = [];
  const add = (g) => (defs.push(g.def), `url(#${g.id})`);
  return [name, svg(S, S, defs, draw(add))];
}

const shine = (x, y, rx, ry, rot = -30) =>
  `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" transform="rotate(${rot} ${x} ${y})" fill="#fff" opacity="0.55"/>`;

const star = (cx, cy, r, fill, s = st) => {
  let d = '';
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const rr = i % 2 ? r * 0.45 : r;
    d += `${i ? 'L' : 'M'}${cx + Math.cos(a) * rr} ${cy + Math.sin(a) * rr}`;
  }
  return `<path d="${d}Z" fill="${fill}" ${s}/>`;
};

export function icons() {
  return [
    // ── 재화.
    make('coin', (a) => `<circle cx="80" cy="84" r="58" fill="${shade('#b07a1a', -0.2)}" ${st}/>
      <circle cx="80" cy="78" r="58" fill="${a(rgrad('#f2c14e'))}" ${st}/>
      <circle cx="80" cy="78" r="42" fill="none" stroke="#a8761a" stroke-width="5"/>
      <rect x="64" y="62" width="32" height="32" rx="3" fill="#5a3a12" ${stroke(5)}/>
      ${shine(56, 48, 18, 8)}`),
    make('silver', (a) => `<path d="M18 88 Q22 60 44 64 Q60 40 80 40 Q100 40 116 64 Q138 60 142 88 Q140 124 80 128 Q20 124 18 88 Z"
        fill="${a(vgrad('#dfe6ee', 0.35, -0.35))}" ${st}/>
      <ellipse cx="80" cy="70" rx="30" ry="16" fill="${a(rgrad('#f4f8ff'))}" ${stroke(5)}/>
      ${shine(52, 92, 16, 6, -10)}`),
    make('token', (a) => `<path d="M80 18 L132 40 L126 104 Q104 136 80 146 Q56 136 34 104 L28 40 Z" fill="${a(vgrad('#d23c3c', 0.3, -0.3))}" ${st}/>
      <path d="M80 34 L116 50 L112 98 Q96 120 80 128 Q64 120 48 98 L44 50 Z" fill="none" stroke="#f2c14e" stroke-width="5"/>
      ${star(80, 82, 24, '#f2c14e', stroke(4))}`),
    make('stamina', (a) => `<path d="M80 146 Q30 140 34 96 Q38 70 60 50 Q58 76 74 82 Q66 46 92 16 Q96 52 118 70 Q136 90 128 116 Q118 144 80 146 Z"
        fill="${a(vgrad('#58c4ff', 0.35, -0.3))}" ${st}/>
      <path d="M80 136 Q56 130 60 106 Q64 92 76 84 Q76 102 88 104 Q86 90 98 80 Q112 100 108 116 Q102 134 80 136 Z" fill="#dff6ff"/>`),
    make('naegong', (a) => `<circle cx="80" cy="80" r="70" fill="#7fd6ff" opacity="0.35" filter="${fx('glow')}"/>
      <circle cx="80" cy="80" r="56" fill="#f6f1e4" ${st}/>
      <path d="M80 24 A56 56 0 0 1 80 136 A28 28 0 0 1 80 80 A28 28 0 0 0 80 24 Z" fill="#2a1a12"/>
      <circle cx="80" cy="52" r="9" fill="#2a1a12"/><circle cx="80" cy="108" r="9" fill="#f6f1e4"/>
      <circle cx="80" cy="80" r="56" fill="none" ${st}/>`),
    make('tp', (a) => `<rect x="30" y="34" width="100" height="96" rx="8" fill="${a(vgrad('#f4ead2', 0.2, -0.2))}" ${st}/>
      <rect x="20" y="24" width="120" height="20" rx="10" fill="${a(vgrad('#8a5a2b'))}" ${st}/>
      <rect x="20" y="120" width="120" height="20" rx="10" fill="${a(vgrad('#8a5a2b'))}" ${st}/>
      ${star(80, 82, 26, '#f2a83a', stroke(5))}`),
    make('dan', (a) => `<circle cx="80" cy="80" r="66" fill="#ff5a3a" opacity="0.4" filter="${fx('glow')}"/>
      <circle cx="80" cy="82" r="44" fill="${a(rgrad('#e03a2a', 0.5, -0.4))}" ${st}/>
      <path d="M58 72 Q80 50 102 72" fill="none" stroke="#ffd36b" stroke-width="5" stroke-linecap="round"/>
      ${shine(64, 64, 12, 6)}`),
    // ── 메뉴.
    make('campaign', (a) => `<path d="M14 120 L56 46 L80 82 L104 34 L148 120 Z" fill="${a(vgrad('#6d8f5a', 0.3, -0.3))}" ${st}/>
      <path d="M92 56 L104 34 L116 56 Q104 50 92 56 Z" fill="#fff" ${stroke(4)}/>
      <path d="M30 140 Q60 120 70 128 Q90 140 110 116 Q124 100 140 108" fill="none" stroke="#c0392b" stroke-width="6" stroke-dasharray="2 12" stroke-linecap="round"/>
      <path d="M128 92 l0 -30 l20 8 l-20 8" fill="#d23c3c" ${stroke(4)}/>`),
    make('training', (a) => `<rect x="70" y="28" width="22" height="118" rx="8" fill="${a(vgrad('#a0703a'))}" ${st}/>
      <circle cx="81" cy="34" r="22" fill="${a(rgrad('#b88048'))}" ${st}/>
      <rect x="22" y="62" width="58" height="16" rx="8" fill="${a(vgrad('#8a5a2b'))}" ${st}/>
      <rect x="84" y="88" width="58" height="16" rx="8" fill="${a(vgrad('#8a5a2b'))}" ${st}/>
      <rect x="36" y="140" width="90" height="14" rx="6" fill="#5a3a1e" ${st}/>
      <path d="M118 30 l14 -10 M124 44 l18 -2 M114 18 l4 -14" stroke="#ffd36b" stroke-width="6" stroke-linecap="round"/>`),
    make('puzzle', (a) => `<path d="M28 44 H64 Q60 24 80 24 Q100 24 96 44 H132 V80 Q152 76 152 96 Q152 116 132 112 V140 H28 V112 Q48 116 48 96 Q48 76 28 80 Z"
        fill="${a(vgrad('#7a5ad1', 0.3, -0.3))}" ${st}/>
      <circle cx="80" cy="92" r="20" fill="${a(rgrad('#f4f1ea'))}" ${stroke(5)}/>`),
    make('arena', (a) => `<path d="M40 30 H120 V60 Q120 100 80 108 Q40 100 40 60 Z" fill="${a(vgrad('#f2c14e', 0.35, -0.3))}" ${st}/>
      <path d="M40 40 Q16 40 18 60 Q20 78 44 80 M120 40 Q144 40 142 60 Q140 78 116 80" fill="none" ${st}/>
      <rect x="72" y="106" width="16" height="22" fill="#c8962a" ${st}/>
      <rect x="44" y="126" width="72" height="20" rx="6" fill="${a(vgrad('#8a5a2b'))}" ${st}/>
      ${star(80, 62, 18, '#fff7d0', stroke(4))}`),
    make('wander', (a) => `<circle cx="80" cy="80" r="62" fill="${a(rgrad('#e8d6a8'))}" ${st}/>
      <circle cx="80" cy="80" r="46" fill="none" stroke="#8a6a3a" stroke-width="4"/>
      <path d="M80 30 L94 80 L80 130 L66 80 Z" fill="#d23c3c" ${stroke(4)}/>
      <path d="M80 80 L94 80 L80 130 L66 80 Z" fill="#f4f1ea" ${stroke(4)}/>
      <circle cx="80" cy="80" r="8" fill="#2a1a12"/>`),
    make('legend', (a) => `<circle cx="80" cy="74" r="66" fill="#ffd36b" opacity="0.5" filter="${fx('glow')}"/>
      <rect x="24" y="70" width="112" height="68" rx="8" fill="${a(vgrad('#8a4a1e', 0.25, -0.3))}" ${st}/>
      <path d="M24 70 Q24 30 80 30 Q136 30 136 70 Z" fill="${a(vgrad('#a85a24', 0.3, -0.2))}" ${st}/>
      <rect x="24" y="66" width="112" height="12" fill="#f2c14e" ${stroke(4)}/>
      <rect x="68" y="66" width="24" height="30" rx="4" fill="#f2c14e" ${stroke(4)}/>
      ${star(120, 30, 14, '#fff7d0', stroke(3))}${star(36, 40, 10, '#fff7d0', stroke(3))}`),
    make('shop', (a) => `<path d="M40 60 Q36 140 80 144 Q124 140 120 60 Z" fill="${a(vgrad('#c0392b', 0.3, -0.3))}" ${st}/>
      <path d="M44 60 Q60 40 80 46 Q100 40 116 60 Q100 70 80 66 Q60 70 44 60 Z" fill="${a(vgrad('#e0503a'))}" ${st}/>
      <path d="M62 48 Q80 20 98 48" fill="none" stroke="#f2c14e" stroke-width="7" stroke-linecap="round"/>
      <circle cx="80" cy="104" r="22" fill="${a(rgrad('#f2c14e'))}" ${stroke(5)}/>
      <rect x="73" y="97" width="14" height="14" fill="#5a3a12"/>`),
    make('stats', (a) => `<path d="M40 80 Q40 40 70 42 L110 42 Q130 44 128 66 L128 112 Q126 140 92 142 L66 142 Q40 140 40 112 Z"
        fill="${a(vgrad('#f3cfa6', 0.2, -0.25))}" ${st}/>
      <path d="M62 42 V76 M86 42 V76 M110 44 V76" ${stroke(5)}/>
      <path d="M40 92 Q70 86 92 96" fill="none" ${stroke(5)}/>
      <path d="M130 30 l10 -16 M138 50 l18 -4 M118 18 l-2 -14" stroke="#ff9f3a" stroke-width="7" stroke-linecap="round"/>`),
    make('codex', (a) => `<path d="M20 36 Q50 24 80 40 Q110 24 140 36 V132 Q110 120 80 136 Q50 120 20 132 Z" fill="${a(vgrad('#3a6aa0', 0.3, -0.3))}" ${st}/>
      <path d="M30 42 Q54 34 76 46 V124 Q54 112 30 120 Z" fill="#f4ead2" ${stroke(4)}/>
      <path d="M130 42 Q106 34 84 46 V124 Q106 112 130 120 Z" fill="#f4ead2" ${stroke(4)}/>
      <path d="M40 64 h26 M40 80 h26 M94 64 h26 M94 80 h20" stroke="#8a7a5a" stroke-width="4" stroke-linecap="round"/>`),
    make('depot', (a) => `<rect x="24" y="66" width="112" height="76" rx="6" fill="${a(vgrad('#b07a3b', 0.25, -0.3))}" ${st}/>
      <path d="M24 92 H136 M60 66 V142 M100 66 V142" stroke="#6a4420" stroke-width="5"/>
      <line x1="112" y1="66" x2="112" y2="10" stroke="#5a3a22" stroke-width="7"/>
      <path d="M112 12 q22 6 38 0 q-6 16 0 32 q-18 6 -38 0 Z" fill="#2f6fae" ${stroke(4)}/>`),
    make('odds', (a) => `<g transform="rotate(-12 60 92)"><rect x="22" y="54" width="76" height="76" rx="14" fill="${a(vgrad('#f4f1ea', 0.2, -0.25))}" ${st}/>
      <circle cx="42" cy="74" r="7" fill="#c0392b"/><circle cx="78" cy="110" r="7" fill="#2a1a12"/><circle cx="60" cy="92" r="7" fill="#2a1a12"/></g>
      <g transform="rotate(14 112 66)"><rect x="80" y="30" width="62" height="62" rx="12" fill="${a(vgrad('#f4f1ea', 0.2, -0.25))}" ${st}/>
      <circle cx="98" cy="48" r="6" fill="#2a1a12"/><circle cx="124" cy="74" r="6" fill="#2a1a12"/></g>`),
    make('free', (a) => `<circle cx="58" cy="88" r="38" fill="${a(rgrad('#f4f1ea'))}" ${st}/>
      <circle cx="104" cy="72" r="38" fill="${a(rgrad('#3a3a44', 0.35, -0.4))}" ${st}/>
      ${shine(46, 74, 12, 6)}${shine(92, 58, 12, 6)}`),
    make('rebirth', (a) => `<circle cx="80" cy="80" r="66" fill="#ff7a3d" opacity="0.4" filter="${fx('glow')}"/>
      <path d="M80 140 Q30 130 26 80 Q50 92 60 110 Q50 70 80 20 Q110 70 100 110 Q110 92 134 80 Q130 130 80 140 Z"
        fill="${a(vgrad('#ffb347', 0.3, -0.3))}" ${st}/>
      <path d="M80 128 Q60 118 64 96 Q72 104 80 112 Q88 104 96 96 Q100 118 80 128 Z" fill="#fff3c8"/>`),
    make('settings', (a) => {
      let teeth = '';
      for (let i = 0; i < 8; i++) {
        teeth += `<rect x="70" y="16" width="20" height="30" rx="5" transform="rotate(${i * 45} 80 80)" fill="${shade('#8c939d', -0.1)}" ${stroke(5)}/>`;
      }
      return `${teeth}<circle cx="80" cy="80" r="44" fill="${a(rgrad('#b8c0cc'))}" ${st}/>
        <circle cx="80" cy="80" r="18" fill="#2a1a12"/>`;
    }),
    make('look', (a) => `<ellipse cx="80" cy="68" rx="44" ry="52" fill="${a(vgrad('#c9a43c', 0.35, -0.3))}" ${st}/>
      <ellipse cx="80" cy="68" rx="32" ry="40" fill="${a(vgrad('#cfe8ff', 0.3, -0.2))}" ${stroke(4)}/>
      <rect x="72" y="118" width="16" height="30" rx="6" fill="#8a5a2b" ${st}/>
      ${shine(66, 52, 10, 18, 20)}`),
    make('mission', (a) => `<rect x="30" y="20" width="100" height="126" rx="10" fill="${a(vgrad('#f4ead2', 0.2, -0.2))}" ${st}/>
      <rect x="56" y="12" width="48" height="20" rx="6" fill="#8a5a2b" ${stroke(5)}/>
      <path d="M46 56 l8 8 l14 -16 M46 88 l8 8 l14 -16" fill="none" stroke="#2e9a4a" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M80 58 h34 M80 90 h34 M80 122 h34" stroke="#8a7a5a" stroke-width="6" stroke-linecap="round"/>
      <rect x="46" y="112" width="20" height="20" rx="4" fill="none" stroke="#8a7a5a" stroke-width="5"/>`),
    make('attendance', (a) => `<rect x="22" y="32" width="116" height="112" rx="12" fill="#f4f1ea" ${st}/>
      <path d="M22 44 Q22 32 34 32 H126 Q138 32 138 44 V62 H22 Z" fill="${a(vgrad('#d23c3c'))}" ${st}/>
      <rect x="44" y="18" width="12" height="28" rx="6" fill="#5a3a22" ${stroke(4)}/><rect x="104" y="18" width="12" height="28" rx="6" fill="#5a3a22" ${stroke(4)}/>
      ${star(80, 102, 28, '#f2c14e', stroke(5))}`),
    make('medal', (a) => `<path d="M50 14 L70 70 L90 70 L70 14 Z" fill="#2f6fae" ${stroke(5)}/><path d="M110 14 L90 70 L70 70 L90 14 Z" fill="#d23c3c" ${stroke(5)}/>
      <circle cx="80" cy="102" r="44" fill="${a(rgrad('#f2c14e'))}" ${st}/>
      <circle cx="80" cy="102" r="30" fill="none" stroke="#a8761a" stroke-width="5"/>
      ${star(80, 102, 20, '#fff7d0', stroke(4))}`),
    make('lock', (a) => `<path d="M48 74 V54 Q48 22 80 22 Q112 22 112 54 V74" fill="none" stroke="#2a1a12" stroke-width="22" stroke-linecap="round"/>
      <path d="M48 74 V54 Q48 22 80 22 Q112 22 112 54 V74" fill="none" stroke="#9aa2ac" stroke-width="12" stroke-linecap="round"/>
      <rect x="30" y="70" width="100" height="76" rx="14" fill="${a(vgrad('#f2c14e', 0.3, -0.3))}" ${st}/>
      <circle cx="80" cy="102" r="10" fill="#2a1a12"/><rect x="75" y="106" width="10" height="22" rx="4" fill="#2a1a12"/>`),
    make('star', () => star(80, 84, 66, '#f7c531', stroke(7)) + shine(58, 56, 14, 7)),
    make('star_empty', () => star(80, 84, 66, '#4a3a2e', stroke(7))),
    make('chest', (a) => `<rect x="20" y="70" width="120" height="72" rx="8" fill="${a(vgrad('#8a4a1e', 0.25, -0.3))}" ${st}/>
      <path d="M20 70 Q20 26 80 26 Q140 26 140 70 Z" fill="${a(vgrad('#a85a24', 0.3, -0.2))}" ${st}/>
      <path d="M40 30 V142 M120 30 V142" stroke="#c8962a" stroke-width="10"/>
      <rect x="66" y="62" width="28" height="34" rx="5" fill="#f2c14e" ${stroke(4)}/>`),
    make('mail', (a) => `<rect x="18" y="40" width="124" height="88" rx="10" fill="${a(vgrad('#f4f1ea', 0.2, -0.2))}" ${st}/>
      <path d="M22 46 L80 92 L138 46" fill="none" ${st}/>
      <circle cx="80" cy="92" r="14" fill="#d23c3c" ${stroke(4)}/>`),
    make('rank', (a) => `<rect x="18" y="80" width="40" height="62" fill="${a(vgrad('#b8c0cc'))}" ${st}/>
      <rect x="60" y="50" width="40" height="92" fill="${a(vgrad('#f2c14e'))}" ${st}/>
      <rect x="102" y="96" width="40" height="46" fill="${a(vgrad('#c8814a'))}" ${st}/>
      <text x="80" y="104" font-size="38" font-weight="900" text-anchor="middle" fill="#5a3a12" font-family="sans-serif">1</text>`),
  ];
}
