import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/quests.dart';
import 'package:alkkagi/story/campaign.dart';
import 'package:alkkagi/story/chapters.dart';
import 'package:alkkagi/story/course.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-14 형 「단계별 코스에 졸개나 중간 단계를 7~9단계로 구성하고 3, 4단계마다 중간보스 등장,
// 마지막 단계에서 보스 등장으로 구성해줘」.
void main() {
  setUpAll(initializePhysics);

  // 2026-10-28 형 「스테이지도 3라운드 정도 더 추가 · 중간 보스 부두목까지」: 장마다 3단계 더(10~12).
  test('장 10개 · 1~9장은 10~12단계 · 4단계(12단계 장은 7단계도) 중간 보스 · 보스 세 단계 앞 부두목 · 마지막은 그 장 보스', () {
    expect(courses.length, 10);
    for (final c in courses.where((c) => c.chapter < 10)) {
      final n = c.steps.length;
      expect(n, inInclusiveRange(10, 12), reason: '${c.chapter}장');
      expect(c.steps[3].kind, StepKind.mid, reason: '${c.chapter}장 4단계');
      if (n == 12) {
        expect(c.steps[6].kind, StepKind.mid, reason: '${c.chapter}장 7단계');
      }
      expect(c.steps[n - 4].kind, StepKind.mid);
      expect(c.steps[n - 4].foe, budumok, reason: '${c.chapter}장 부두목');
      expect(c.steps.last.kind, StepKind.boss);
      expect(c.steps.last.stageId, c.boss.id);
      // 중간 보스 사이는 3~4단계.
      final mids = [
        for (var i = 0; i < n; i++)
          if (c.steps[i].kind != StepKind.minion) i,
      ];
      for (var k = 1; k < mids.length; k++) {
        expect(mids[k] - mids[k - 1], inInclusiveRange(2, 4));
      }
    }
  });

  // 2026-10-28 형 「10단계는 보스로만 구성한 단계로 마지막은 알까기 신이 등장하도록」.
  test('10장: 보스만 10단계 — 1~9장 보스 재대결이 차례로, 마지막은 알까기 신', () {
    final c = courses.last;
    expect(c.chapter, 10);
    expect(c.steps, hasLength(10));
    expect(c.steps.every((s) => s.kind == StepKind.boss), isTrue);
    expect(
      [for (final s in c.steps.take(9)) s.rematchOf],
      [for (var k = 1; k <= 9; k++) 'c$k'],
    );
    expect(c.steps.last.stageId, 'c10');
    expect(c.boss.boss, '알까기 신');
    // 재대결 진행 id 는 이야기 판 id 와 겹치지 않는다(이미 깬 판으로 셈하지 않게).
    for (var i = 0; i < 9; i++) {
      expect(c.idOf(i), 'k10s${i + 1}');
    }
  });

  test('재대결: 그 판 대전장·고수 돌 그대로 · 손 오차는 줄고 시작 내공은 하나 더 · 보상은 중간 보스보다 크다', () {
    final p = Profile()..naegong = 9999;
    final c = courses.last;
    for (var i = 0; i < 9; i++) {
      final st = c.steps[i].rematch!;
      final cfg = CourseRules.configFor(p, c, i);
      final story = Campaign.configFor(p, st);
      expect(cfg.arena, st.arena);
      expect(cfg.opponentName, st.boss);
      expect(cfg.opponentMaterial, story.opponentMaterial);
      expect(cfg.aiErrorScale, lessThan(story.aiErrorScale));
      expect(
        cfg.opponentStartQi,
        (story.opponentStartQi + 1).clamp(0, maxQi),
        reason: st.id,
      );
    }
    final r = CourseRules.finish(p, c, 0, won: true);
    expect(r.coins, (100 + 20 * 10) * 2);
    expect(r.bag.keys.where((k) => k.startsWith('item:')), hasLength(1));
    expect(p.done, contains('k10s1'));
    expect(p.done, isNot(contains('c1')), reason: '재대결은 1장 보스를 깬 것으로 치지 않는다');
  });

  test('10장 문: 9장 보스를 깨야 열리고, 재대결도 차례대로', () {
    final p = Profile()..naegong = 9999;
    final c = courses.last;
    expect(CourseRules.lockReason(p, c, 0), contains('9장'));
    p.done.add('c9');
    expect(CourseRules.lockReason(p, c, 0), isNull);
    expect(CourseRules.lockReason(p, c, 1), isNotNull);
    expect(
      CourseRules.lockReason(p, c, 9),
      contains('9단계'),
      reason: '알까기 신은 재대결 아홉을 다 넘어야',
    );
    p.done.addAll([for (var i = 0; i < 9; i++) c.idOf(i)]);
    expect(CourseRules.lockReason(p, c, 9), isNull);
  });

  test('이야기 판 13개(장 보스 10 · 숙적 3)가 코스에 한 번씩 · 예전 순서 그대로', () {
    final ids = [
      for (final c in courses)
        for (final s in c.steps) ?s.stageId,
    ];
    expect(ids, [for (final s in campaign) s.id]);
  });

  test('차례대로 열린다 · 앞 장 보스를 깨야 다음 장 · 보스를 이미 깬 장은 모두 열림', () {
    final p = Profile()..naegong = 9999;
    final c1 = courses[0], c2 = courses[1];
    expect(CourseRules.lockReason(p, c1, 0), isNull);
    expect(CourseRules.lockReason(p, c1, 1), isNotNull);
    p.done.add(c1.idOf(0));
    expect(CourseRules.lockReason(p, c1, 1), isNull);
    expect(CourseRules.lockReason(p, c2, 0), isNotNull, reason: '1장 보스 먼저');
    // 예전 진행: 1장 보스만 깬 사람 → 1장 모든 단계 열림, 2장 1단계 열림.
    final old = Profile()
      ..naegong = 9999
      ..done.add('c1');
    for (var i = 0; i < c1.steps.length; i++) {
      expect(CourseRules.lockReason(old, c1, i), isNull);
    }
    expect(CourseRules.lockReason(old, c2, 0), isNull);
  });

  test('보상: 졸개 첫 승리 엽전 ×2 + 재료 1 · 중간 보스 재료 + 아이템 · 다시 이기면 엽전 반', () {
    final p = Profile();
    final c = courses[3]; // 4장(용비늘도 나오는 장)
    final r1 = CourseRules.finish(p, c, 0, won: true);
    expect(r1.coins, (30 + 10 * 4) * 2);
    expect(r1.bag.values.fold(0, (a, b) => a + b), 1);
    expect(p.done, contains(c.idOf(0)));
    final again = CourseRules.finish(p, c, 0, won: true);
    expect(again.coins, (30 + 10 * 4) ~/ 2);
    expect(again.bag, isEmpty);
    final mid = CourseRules.finish(p, c, 3, won: true);
    expect(mid.bag.keys.where((k) => k.startsWith('item:')), hasLength(1));
    expect(Bag.count(p, Mat.scale.key), 1);
    expect(CourseRules.finish(p, c, 4, won: false).coins, 0);
  });

  test('졸개 판은 상대 돌이 적다(4~8개) · 중간 보스는 새 재질 돌', () {
    final p = Profile();
    final c = courses[0];
    final cfg = CourseRules.configFor(p, c, 0);
    expect(cfg.opponentStones, c.steps[0].stones);
    final m = Match(cfg);
    expect(m.alive(1), c.steps[0].stones);
    expect(m.alive(0), stonesPerTeam);
    m.dispose();
    expect(CourseRules.configFor(p, c, 3).opponentMaterial, StoneMaterial.wood);
  });
}
