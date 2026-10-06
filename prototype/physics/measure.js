// 설계서 v2 에 들어가는 물리 숫자를 재는 스크립트.  실행: node measure.js
'use strict';
const { makeWorld, addStone, shoot, runTurn, MATERIALS, SHAPES, BOARD, R, STEP } = require('./sim');
const f = (n, d = 1) => Number(n).toFixed(d);

// 시드 고정 난수 (결정성 확인용)
function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 2 ** 32); }

console.log('## A. 타격점 상·중·하 (같은 재질·같은 무게, 정면 충돌)');
for (const [gap, label] of [[8, '가까운 표적 8cm'], [20, '먼 표적 20cm']]) {
  for (const [hit, name] of [[1, '상(밀어치기)'], [0, '중(강타)'], [-1, '하(끌어치기)']]) {
    const w = makeWorld();
    const me = addStone(w, -gap, 0, 'cheongok', 'sphere');
    const tg = addStone(w, 0, 0, 'cheongok', 'sphere');
    shoot(me, 0, 20, hit);
    runTurn(w, me);
    console.log(`  ${label} ${name}: 내 돌 이동 ${f(me.getPosition().x + gap)}cm (최종 x=${f(me.getPosition().x)}) · 표적 이동 ${f(tg.getPosition().x)}cm`);
  }
}

console.log('\n## B. 재질별 — 같은 힘(충격량 60)으로 쳤을 때 혼자 굴러간 거리·시간');
for (const k of Object.keys(MATERIALS)) {
  const w = makeWorld();
  const s = addStone(w, -BOARD / 2 + 2, 0, k, 'round');
  const mass = s.getMass();
  shoot(s, 0, 60 / mass, 0); // 같은 충격량 → 가벼우면 빠르다
  const t0 = s.getPosition().x;
  const r = runTurn(w, s);
  const u = s.getUserData();
  console.log(`  ${MATERIALS[k].name}: 질량 ${f(mass, 2)} · 초기속도 ${f(60 / mass)}cm/s · ${u.out ? '판 밖으로 나감' : `거리 ${f(s.getPosition().x - t0)}cm`} · ${f(r.steps * STEP, 2)}초`);
}

console.log('\n## B2. 재질별 — 같은 속도(30cm/s)로 표적(청옥)을 정면으로 쳤을 때 표적이 밀린 거리');
for (const k of Object.keys(MATERIALS)) {
  const w = makeWorld();
  const me = addStone(w, -8, 0, k, 'round');
  const tg = addStone(w, 0, 0, 'cheongok', 'round');
  shoot(me, 0, 30, 0);
  runTurn(w, me);
  console.log(`  ${MATERIALS[k].name} → 표적 이동 ${f(tg.getPosition().x)}cm`);
}

console.log('\n## B3. 모양별 — 같은 속도, 혼자 굴러간 거리');
for (const k of Object.keys(SHAPES)) {
  const w = makeWorld();
  const s = addStone(w, -BOARD / 2 + 2, 0, 'cheongok', k);
  shoot(s, 0, 40, 0);
  const t0 = s.getPosition().x; runTurn(w, s);
  console.log(`  ${SHAPES[k].name}: ${f(s.getPosition().x - t0)}cm`);
}

console.log('\n## C. 빙백한옥 감속 하한 — 감속 0 이면 끝나지 않는다');
for (const minD of [0, 0.15]) {
  const w = makeWorld();
  const s = addStone(w, 0, 0, 'ice', 'sphere', minD);
  s.setLinearDamping(minD);
  // 벽이 없으므로 같은 자리에서 아주 느리게 굴린다 (판 밖으로 나가지 않을 만큼)
  shoot(s, 0, 1.2, 0);
  const r = runTurn(w, s);
  console.log(`  감속 하한 ${minD}: ${r.timedOut ? '10초 안에 안 멈춤 → 강제 정지 필요' : `${f(r.steps * STEP, 2)}초에 멈춤`} (이동 ${f(s.getPosition().x)}cm)`);
}

function randomGame(seed, minD = 0.15) {
  const rand = rng(seed);
  const w = makeWorld();
  const stones = [];
  const mats = Object.keys(MATERIALS), shapes = Object.keys(SHAPES);
  // 8:8, 서로 겹치지 않게 배치
  while (stones.length < 16) {
    const x = (rand() - 0.5) * (BOARD - 6), y = (stones.length < 8 ? -1 : 1) * (2 + rand() * (BOARD / 2 - 5));
    if (stones.every((s) => { const p = s.getPosition(); return Math.hypot(p.x - x, p.y - y) > 2 * R + 0.3; })) {
      stones.push(addStone(w, x, y, mats[Math.floor(rand() * 4)], shapes[Math.floor(rand() * 3)], minD));
    }
  }
  const me = stones[Math.floor(rand() * 8)];
  shoot(me, Math.PI / 2 + (rand() - 0.5) * 0.8, 40 + rand() * 80, rand() * 2 - 1);
  return { w, me, stones };
}

console.log('\n## D. 한 수 계산 비용 (16알 판, 무작위 한 수 2,000번)');
const N = 2000, times = [], steps = []; let timedOut = 0, outs = 0;
for (let i = 0; i < N; i++) {
  const { w, me, stones } = randomGame(1000 + i);
  const t = process.hrtime.bigint();
  const r = runTurn(w, me);
  times.push(Number(process.hrtime.bigint() - t) / 1e6);
  steps.push(r.steps); if (r.timedOut) timedOut++;
  outs += stones.filter((s) => s.getUserData().out).length;
}
const q = (a, p) => [...a].sort((x, y) => x - y)[Math.floor(a.length * p)];
const avg = (a) => a.reduce((s, v) => s + v, 0) / a.length;
console.log(`  계산 시간: 평균 ${f(avg(times), 2)}ms · 중앙 ${f(q(times, 0.5), 2)}ms · 95% ${f(q(times, 0.95), 2)}ms · 최대 ${f(Math.max(...times), 2)}ms`);
console.log(`  게임 속 시간: 평균 ${f(avg(steps) * STEP, 2)}초 · 95% ${f(q(steps, 0.95) * STEP, 2)}초 · 10초 강제정지 ${timedOut}번`);
console.log(`  한 수당 장외 평균 ${f(outs / N, 2)}알`);
for (const minD of [0.3, 0.5]) {
  let to = 0; const st = [];
  for (let i = 0; i < N; i++) { const { w, me } = randomGame(1000 + i, minD); const r = runTurn(w, me); st.push(r.steps); if (r.timedOut) to++; }
  console.log(`  감속 하한 ${minD}: 게임 속 시간 평균 ${f(avg(st) * STEP, 2)}초 · 95% ${f(q(st, 0.95) * STEP, 2)}초 · 10초 강제정지 ${to}번`);
}

console.log('\n## E. 결정성 — 같은 입력을 두 번 계산해 결과가 비트 단위로 같은가 (200판)');
let same = 0;
for (let i = 0; i < 200; i++) {
  const snap = () => { const { w, me, stones } = randomGame(5000 + i); runTurn(w, me); return JSON.stringify(stones.map((s) => [s.getPosition().x, s.getPosition().y, s.getUserData().out])); };
  if (snap() === snap()) same++;
}
console.log(`  같은 결과 ${same}/200`);
