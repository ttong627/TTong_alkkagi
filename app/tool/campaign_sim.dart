// 강호행 판마다 「사람 손 흉내」가 몇 % 이기나 잰다(난이도 맞추기 · 설계서 §16.16).
//
// 실행: N=40 STAGES=c1,c2 HAND=avg EASY=1 flutter test tool/campaign_sim.dart
//   HAND = novice(초보) | avg(보통 사람)   EASY = 1 이면 강호행 「쉬움」으로
//
// 사람 손 흉내([가정] — 고르는 수는 보통 AI 와 같고, 손 오차만 다르다):
//   보통 사람: 방향 ±7.9°(고르게) — 가상 시험(tool/flick_sim.dart)의 손 방향 오차 90% 7.12° 와 맞춘 값 · 세기 ±25%
//   초보:      방향 ±11.5° · 세기 ±35%
// 둘 다 평타만 친다(내공·회심을 안 쓴다 — 사람에게 불리한 쪽으로 잰다). 내공 겨루기 연타는 초당 8회.
import 'dart:io';
import 'dart:math' as math;

import 'package:alkkagi/game/ai.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/story/campaign.dart';
import 'package:alkkagi/story/chapters.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 내 돌이 떨어진 수: 내가 쳐서(자멸) / 상대가 쳐서.
int selfOuts = 0, foeOuts = 0;

/// 한 판을 끝까지 둔다. 이기면 참.
bool playOne(MatchConfig cfg, int seed, double angleErr, double speedErr) {
  final rand = math.Random(seed);
  final m = Match(cfg);
  var guard = 0;
  while (!m.isOver && guard++ < 120) {
    final mine = m.turn == 0;
    final before = m.alive(0);
    final shot = mine
        ? aiShotNow(
            m,
            seed: rand.nextInt(1 << 30),
            search: Difficulty.normal,
            angleError: angleErr,
            speedError: speedErr,
          )
        : aiShotNow(m, seed: rand.nextInt(1 << 30));
    m.shoot(
      m.table.stones[shot.stoneId],
      shot.angle,
      mine ? shot.speed * cfg.powerScale : shot.speed,
      shot.hit,
      mode: mine ? StrikeMode.plain : shot.mode,
    );
    var steps = 0;
    while (m.isMoving && steps++ < 20000) {
      if (m.clash != null) {
        m.resolveClash(
          20 + rand.nextInt(9),
          QiClash.aiTaps(cfg.difficulty, rand),
        );
      }
      m.step();
    }
    final lost = before - m.alive(0);
    if (mine) {
      selfOuts += lost;
    } else {
      foeOuts += lost;
    }
  }
  final won = m.winner == 0 && !m.isDraw;
  m.dispose();
  return won;
}

void main() {
  test('강호행 승률', () async {
    await initializePhysics();
    final n = int.parse(Platform.environment['N'] ?? '40');
    final want = (Platform.environment['STAGES'] ?? '').split(',');
    final hand = Platform.environment['HAND'] ?? 'avg';
    final easy = Platform.environment['EASY'] == '1';
    // SCALES=1,2,3 이면 그 AI 손 오차 배수마다(없으면 설정 그대로).
    final scales = <double?>[
      for (final x in (Platform.environment['SCALES'] ?? '').split(','))
        if (x.isNotEmpty) double.parse(x),
    ];
    if (scales.isEmpty) scales.add(null);
    final power = double.tryParse(Platform.environment['POWER'] ?? '');
    final blunder = double.tryParse(Platform.environment['BLUNDER'] ?? '');
    final style = AiStyle.values
        .where((x) => x.name == Platform.environment['STYLE'])
        .firstOrNull;
    final qi = int.tryParse(Platform.environment['QI'] ?? '');
    StoneMaterial? matOf(String k) => StoneMaterial.values
        .where((x) => x.name == Platform.environment[k])
        .firstOrNull;
    final mat = matOf('MAT');
    final myMat = matOf('MYMAT');
    final powerLv = int.tryParse(Platform.environment['POWERLV'] ?? '') ?? 0;
    final prog = Platform.environment['PROG'] == '1';
    final (ae, se) = hand == 'novice'
        ? (11.5 * math.pi / 180, 0.35)
        : (7.9 * math.pi / 180, 0.25);
    for (final s in campaign) {
      if (want.first.isNotEmpty && !want.contains(s.id)) continue;
      final p = Profile()..tutorialDone = true;
      if (myMat != null) {
        p.materials.add(myMat);
        p.material = myMat;
      }
      p.stats[Stat.power] = powerLv;
      if (prog) {
        // [가정] 그 판에 온 보통 사람의 진행: 세기 단계는 판마다 조금씩, 숙적2(r2)부터 현철 돌.
        final k = campaign.indexOf(s);
        p.stats[Stat.power] = const [0, 2, 3, 5, 7, 8, 10, 12, 14][k];
        if (k >= 5) {
          p.materials.add(StoneMaterial.hyeoncheol);
          p.material = StoneMaterial.hyeoncheol;
        }
      }
      for (final sc in scales) {
        final cfg = Campaign.configFor(
          p,
          s,
          easy: easy,
          aiErrorScale: sc,
          aiPowerScale: power,
          aiBlunder: blunder,
          aiStyle: style,
          bossQi: qi,
          bossMaterial: mat,
        );
        final sw = Stopwatch()..start();
        var wins = 0;
        selfOuts = foeOuts = 0;
        for (var i = 0; i < n; i++) {
          if (playOne(cfg, 1000 + i, ae, se)) wins++;
        }
        // ignore: avoid_print
        print(
          '${s.id}\t${s.boss}\t${easy ? '쉬움' : '보통'}\t$hand\t'
          '이김 $wins/$n = ${(100 * wins / n).toStringAsFixed(0)}%\t'
          '(내 돌 잃음: 내가 친 수 ${(selfOuts / n).toStringAsFixed(1)} · 상대 ${(foeOuts / n).toStringAsFixed(1)} · 오차 ×${cfg.aiErrorScale.toStringAsFixed(2)} · 세기 ×${cfg.aiPowerScale.toStringAsFixed(2)} · 실수 ${cfg.aiBlunder.toStringAsFixed(2)} · ${cfg.aiStyle.name} 내공${cfg.opponentStartQi} · ${cfg.opponentMaterial.name} 대 ${cfg.myMaterial.name} · ×${cfg.powerScale.toStringAsFixed(2)} · ${sw.elapsed.inSeconds}초)',
        );
      }
    }
  }, timeout: Timeout.none);
}
