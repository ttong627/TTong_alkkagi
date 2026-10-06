// 알까기 물리 모델 시험대 (설계서 v2 §3 의 숫자를 재는 코드)
// 엔진: planck.js (Box2D v2 의 JS 이식). 실제 게임은 Forge2D(Box2D v3 바인딩)를 쓰지만,
// 이 시험은 "위에서 내려다본 2D + 감속 + 회전 보정" 모델이 의도대로 움직이는지와
// 한 수(shot) 계산 비용의 크기를 재기 위한 것이다.
// 단위: 1 = 1cm, 1초 = 60스텝.
'use strict';
const planck = require('planck');
const { World, Vec2, Circle } = planck;

// ── 설계 값 (설계서 §3 표와 같아야 한다) ────────────────────────────
const BOARD = 42;          // 바둑판 한 변 42cm (19줄 × 약 2.2cm)
const R = 1.1;             // 돌 반지름 1.1cm
const STEP = 1 / 60;
const REST_SPEED = 0.5;    // 0.5cm/s 아래면 멈춘 것으로 본다
const MAX_TURN_SEC = 10;   // 한 수 최대 10초 (넘으면 강제 정지)
const SPIN_K = 0.5;        // 회전 보정 세기: 충돌 직전 속도의 최대 50%
const SPIN_TAU = 1.0;      // 회전이 1초에 1/e 로 줄어든다

const MATERIALS = {
  cheongok:  { name: '청옥(표준)',   density: 1.0, damping: 1.2,  restitution: 0.85 },
  wood:      { name: '만년기주(나무)', density: 0.5, damping: 0.9,  restitution: 0.80 },
  hyeoncheol:{ name: '현철(무거움)', density: 2.5, damping: 2.0,  restitution: 0.75 },
  ice:       { name: '빙백한옥(얼음)', density: 1.0, damping: 0.15, restitution: 0.95 },
};
const SHAPES = { // 모양: 감속 배수, 회전 효율
  flat:   { name: '납작한 돌', dampMul: 1.3, spinEff: 0.4 },
  round:  { name: '모서리 둥근 돌', dampMul: 1.0, spinEff: 0.7 },
  sphere: { name: '구형 돌', dampMul: 0.7, spinEff: 1.0 },
};

function makeWorld() {
  return new World({ gravity: Vec2(0, 0) });
}

function addStone(world, x, y, mat = 'cheongok', shape = 'round', minDamping = 0.15) {
  const m = MATERIALS[mat], s = SHAPES[shape];
  const damping = Math.max(minDamping, m.damping * s.dampMul);
  const b = world.createBody({
    type: 'dynamic', position: Vec2(x, y), bullet: true,
    linearDamping: damping, angularDamping: 2.0,
  });
  b.createFixture(new Circle(R), { density: m.density, friction: 0.1, restitution: m.restitution });
  b.setUserData({ mat, shape, spin: 0, spinUsed: false, out: false });
  return b;
}

// 한 수 쏘기: angle(라디안), speed(cm/s 초기 속도), hit: -1(하)~0(중)~+1(상)
function shoot(stone, angle, speed, hit) {
  const d = stone.getUserData();
  d.spin = Math.max(-1, Math.min(1, hit)) * SHAPES[d.shape].spinEff;
  d.spinUsed = false;
  stone.setLinearVelocity(Vec2(Math.cos(angle) * speed, Math.sin(angle) * speed));
}

// 한 수가 멈출 때까지 계산. 반환: { steps, timedOut }
function runTurn(world, shooter) {
  const hits = new Set();
  const onBegin = (c) => {
    const a = c.getFixtureA().getBody(), b = c.getFixtureB().getBody();
    if (a === shooter || b === shooter) hits.add(true);
  };
  world.on('begin-contact', onBegin);
  const maxSteps = Math.round(MAX_TURN_SEC / STEP);
  let steps = 0, timedOut = false;
  for (; steps < maxSteps; steps++) {
    const pre = shooter.getLinearVelocity().clone();
    const d = shooter.getUserData();
    world.step(STEP, 8, 3);
    if (!d.spinUsed) {
      d.spin *= Math.exp(-STEP / SPIN_TAU);           // 굴러가며 회전이 준다
      if (hits.size) {                                // 첫 충돌 직후 회전 보정
        const sp = pre.length();
        if (sp > 0 && d.spin !== 0) {
          const dir = Vec2(pre.x / sp, pre.y / sp);
          const v = shooter.getLinearVelocity();
          shooter.setLinearVelocity(Vec2(v.x + dir.x * SPIN_K * d.spin * sp, v.y + dir.y * SPIN_K * d.spin * sp));
        }
        d.spinUsed = true;
      }
    }
    // 판 밖으로 나간 돌(장외)
    let moving = false;
    for (let b = world.getBodyList(); b; b = b.getNext()) {
      const u = b.getUserData();
      if (!u || u.out) continue;
      const p = b.getPosition();
      if (Math.abs(p.x) > BOARD / 2 || Math.abs(p.y) > BOARD / 2) {
        u.out = true; b.setLinearVelocity(Vec2(0, 0)); b.setActive(false); continue;
      }
      if (b.getLinearVelocity().length() > REST_SPEED) moving = true;
    }
    if (!moving) { steps++; break; }
  }
  if (steps >= maxSteps) {
    timedOut = true;
    for (let b = world.getBodyList(); b; b = b.getNext()) b.setLinearVelocity(Vec2(0, 0));
  }
  world.off('begin-contact', onBegin);
  return { steps, timedOut };
}

module.exports = { planck, makeWorld, addStone, shoot, runTurn, MATERIALS, SHAPES, BOARD, R, STEP, MAX_TURN_SEC };
