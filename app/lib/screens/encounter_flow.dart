import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/match.dart';
import '../progress/encounters.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import '../story/puzzles.dart';
import 'game_screen.dart';
import 'legendary_shop_screen.dart';

final _rand = math.Random();

/// 「1판」이 끝날 때마다 부른다: 기연을 뽑고(설계서 §5.3) 나오면 알린다.
/// [boost] 는 강호유랑 물음표 칸처럼 확률을 높일 때.
Future<void> afterRound(BuildContext context, {double boost = 1}) async {
  final store = ProfileStore.instance;
  final p = store.profile;
  final now = DateTime.now().millisecondsSinceEpoch;
  // 하루 상한(2026-10-11 경제 점검: 묘수풀이를 열었다 닫기만 해도 시간당 수백 번 뽑던 것).
  if (!takeEncounterTurn(p, today())) {
    await store.save();
    return;
  }
  final e = rollEncounter(p, _rand, now: now, boost: boost);
  // 돌 조각(2026-10-14 형 「기연이나 이벤트에서 조각을 모아서 완성하는 돌」).
  final shard = rollShard(p, _rand, boost: boost);
  await store.save();
  if (shard != null && context.mounted) {
    final have = p.bag[shardKey(shard)] ?? 0;
    final need = shardNeeds[shard]!;
    Sound.play('reward');
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          '기연! ${shard.label} 조각 +1 ($have/$need)'
          '${have >= need ? ' — 만물상에서 완성!' : ''}',
        ),
      ),
    );
  }
  if (e == null || !context.mounted) return;
  final nav = Navigator.of(context);
  switch (e) {
    case Encounter.elixir:
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('기연! 천년설삼'),
          content: const Text('산삼 향이 퍼진다. 먹으니 단전이 뜨거워진다 — 내공 +100'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('좋다'),
            ),
          ],
        ),
      );
    case Encounter.legendary:
      // 한 번뿐인 기회: 바깥을 눌러도, 뒤로 가기를 눌러도 닫히지 않는다(단추로만 고른다).
      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('기연! 기인방'),
            content: const Text(
              '허름한 노인이 보따리를 편다. 「10분만 판다네. 값은 자네 주머니 보고 부르지.」',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('나중에'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('들여다보기'),
              ),
            ],
          ),
        ),
      );
      if (go == true) {
        await nav.push(
          MaterialPageRoute<void>(builder: (_) => const LegendaryShopScreen()),
        );
      }
    case Encounter.hermit:
      // 한 번만 기회: 바깥을 눌러도, 뒤로 가기를 눌러도 닫히지 않는다(단추로만 고른다).
      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('기연! 은둔 고수'),
            content: const Text('「한 번에 돌 셋을 떨어뜨려 보아라. 해내면 내 비급을 주마.」(한 번만 기회)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('사양한다'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('도전'),
              ),
            ],
          ),
        ),
      );
      if (go != true) return;
      final won = await nav.push<bool>(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            title: hermitPuzzle.title,
            info: () => hermitPuzzle.help,
            config: MatchConfig(
              mode: MatchMode.practice,
              arena: puzzleArena,
              layout: hermitPuzzle.layout,
              shotLimit: hermitPuzzle.shots,
              myMaterial: p.material,
              myShape: p.shape,
              myTrail: p.trailOrNull,
              powerScale: p.maxSpeed / baseMaxSpeed,
            ),
          ),
        ),
      );
      final msg = won == true
          ? hermitReward(p, _rand)
          : '「아직 멀었구나.」 은둔 고수가 사라졌다';
      await store.save();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text(won == true ? '시험 통과!' : '실패'),
          content: Text(msg),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('확인'),
            ),
          ],
        ),
      );
  }
}
