import 'dart:async';

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../progress/profile.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

import '../game/arena.dart';
import '../game/fx_colors.dart';
import '../game/match.dart';
import '../game/schools.dart';
import '../progress/store.dart';
import '../story/campaign.dart';
import '../story/chapters.dart';
import 'dialogue_screen.dart';
import 'encounter_flow.dart';
import 'game_screen.dart';

/// 강호행: 6장과 숙적전을 차례로 깬다(설계서 §9·§16.1).
class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  @override
  void initState() {
    super.initState();
    // 첫 방문 안내(설계서 §16.13).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          firstVisit(context, 'campaign', '장을 하나씩 깨며 강호로 나아가거라. 판마다 별 셋을 노려라!'),
    );
  }

  final _store = ProfileStore.instance;

  Future<void> _play(int i) async {
    final p = _store.profile;
    final s = campaign[i];
    final nav = Navigator.of(context);
    // 「건너뛰기」 한 번이면 서장 · 인사 · 장 시작 대사 모두 건너뛰고 바로 판으로.
    var skipped = false;
    if (!p.codex.contains('서장')) {
      skipped =
          await nav.push<bool>(
            gameRoute<bool>(
              const DialogueScreen(
                title: '서장 · 기명석',
                lines: prologue,
                scene: 'lobby',
              ),
            ),
          ) ??
          false;
      p.codex.add('서장');
      await _store.save();
      if (!mounted) return;
    }
    if (!skipped) {
      Sound.play('jingle_chapter');
      await nav.push(
        gameRoute<bool>(
          DialogueScreen(
            title: s.title,
            scene: s.arena.name,
            lines: [
              if (p.hero case final h?)
                (s.speaker, heroGreeting(h.label, h.trait)),
              ...s.intro,
            ],
          ),
        ),
      );
      if (!mounted) return;
    }
    Match? last;
    final won = await nav.push<bool>(
      gameRoute(
        GameScreen(
          config: Campaign.configFor(p, s, easy: p.easyMode),
          title: s.title,
          quips: s.quips,
          boss: true,
          stageId: s.id,
          onTurnEnd: (m) => last = m,
        ),
      ),
    );
    if (won == null || !mounted) return;
    final r = Campaign.finish(
      p,
      s,
      won: won,
      civiliansLost: last?.civiliansLost ?? 0,
      bonusCoins: last?.bonusCoins ?? 0,
    );
    await _store.save();
    if (!mounted) return;
    await showRewardDialog(
      context,
      title: won ? '승리!' : '패배',
      won: won,
      items: [
        if (r.coins > 0) ('coin', '+${r.coins}${r.first ? ' (첫 승 ×2)' : ''}'),
        if (r.silver > 0) ('silver', '+${r.silver}'),
        if (r.bonus > 0) ('coin', '일타쌍피 +${r.bonus}'),
        if (r.fine > 0) ('coin', '백성 돌 배상 −${r.fine}'),
      ],
      newHero: r.hero,
      note: won ? null : '${s.boss}에게 졌다. 목인항에서 내공을 쌓고 다시!',
    );
    if (!won || !mounted) return;
    await nav.push(
      gameRoute<bool>(
        DialogueScreen(title: s.title, lines: s.outro, scene: s.arena.name),
      ),
    );
    if (r.awaken && mounted) await _awaken();
    if (mounted) setState(() {});
    if (mounted) await afterRound(context);
  }

  /// 폐관수련동(설계서 §8.1): 현경(7단계)부터. 무공을 쓰는 강적과 겨룬다. 이기면 엽전 200 · 징표 2.
  Future<void> _seclusion() async {
    final p = _store.profile;
    final martials = [
      Technique.swordQi,
      Technique.stomp,
      Technique.taiji,
      Technique.clone,
    ];
    final m = martials[DateTime.now().millisecond % martials.length];
    final won = await Navigator.of(context).push<bool>(
      gameRoute(
        GameScreen(
          title: '폐관수련동',
          boss: true,
          config: Campaign.playerConfig(
            p,
            arena: Arena.murimIce,
            difficulty: Difficulty.hard,
            opponentMaterial: StoneMaterial.hyeoncheol,
            opponentShape: StoneShape.sphere,
            opponentMartial: m,
            aiStyle: AiStyle.master,
            opponentStartQi: 3,
            opponentName: '폐관 고수(${m.label})',
            aimAssist: 0,
            qiClash: true,
          ),
        ),
      ),
    );
    // 큰 보상은 하루 첫 승리만(2026-10-11 경제 점검: 무제한이던 것). 그 뒤로는 엽전 30.
    final day = today();
    final big = won == true && day.compareTo(p.seclusionDay) > 0;
    if (big) {
      p.coins += 200;
      p.tokens += 2;
      p.seclusionDay = day;
    } else if (won == true) {
      p.coins += 30;
    }
    await _store.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          won == true
              ? (big
                    ? '폐관 고수를 꺾었다 — 엽전 +200 · 징표 +2'
                    : '또 꺾었다 — 엽전 +30 (큰 보상은 하루 한 번)')
              : '아직 이르다',
        ),
      ),
    );
    setState(() {});
    if (won == true) await afterRound(context);
  }

  /// 1장을 처음 깨면 문파를 고른다(설계서 §2.1 · 한 번 고르면 환생 때까지 그대로).
  Future<void> _awaken() async {
    final t = await showDialog<Technique>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AwakenDialog(),
    );
    if (t == null) return;
    _store.profile.school = t;
    _store.profile.codex.add('문파:${t.name}');
    await _store.save();
  }

  /// 잠긴 까닭을 한눈에 읽히게 줄인다(「앞 판(…)을 먼저 깨세요」 → 「1장 먼저」).
  static String _lockShort(String lock, int i) {
    if (lock.startsWith('앞 판') && i > 0) {
      return '${campaign[i - 1].title.split(' ').first} 먼저';
    }
    return '${lock.split(' 이 필요').first} 필요';
  }

  /// 난이도: 쉬움(고수 손이 서툴다 · 2장 통통까지 처음 하는 사람도 깬다) / 보통.
  Widget _difficultyRow(Profile p) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '난이도',
                style: TextStyle(fontFamily: titleFont, fontSize: 18),
              ),
              const SizedBox(width: 10),
              GameChip(
                key: const Key('diff-easy'),
                label: '쉬움',
                selected: p.easyMode,
                onTap: () => _setEasy(true),
              ),
              const SizedBox(width: 8),
              GameChip(
                key: const Key('diff-normal'),
                label: '보통',
                selected: !p.easyMode,
                onTap: () => _setEasy(false),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            p.easyMode ? '고수의 손이 서툴러요 — 처음 하는 분도 2장까지 쉽게' : '고수가 제 실력으로 겨뤄요',
            style: const TextStyle(fontSize: 14, color: Palette.dim),
          ),
        ],
      ),
    ),
  );

  void _setEasy(bool v) {
    setState(() => _store.profile.easyMode = v);
    unawaited(_store.save());
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    return GameScaffold(
      title: '강호행',
      background: 'dustyYard',
      dim: 0.5,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: [
              Image.asset(Art.icon('star'), width: 26),
              const SizedBox(width: 4),
              Text(
                '${p.totalStars}',
                style: const TextStyle(fontFamily: titleFont, fontSize: 18),
              ),
            ],
          ),
        ),
      ],
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: campaign.length + 2,
        itemBuilder: (_, j) {
          if (j == 0) return _difficultyRow(p);
          final i = j - 1;
          if (i == campaign.length) {
            final open = p.stage >= 7;
            return _StageCard(
              key: const Key('seclusion'),
              scene: 'murimIce',
              face: 'mukgaek',
              title: '폐관수련동',
              sub: open ? '끝판 · 무공 쓰는 강적' : '내공 현경(7단계)부터',
              stars: 0,
              locked: !open,
              done: false,
              onTap: open ? _seclusion : null,
            );
          }
          final s = campaign[i];
          final lock = Campaign.lockReason(p, i);
          return _StageCard(
            key: Key('stage-${s.id}'),
            scene: s.arena.name,
            face: Art.bossId(s.boss),
            title: s.title,
            sub: lock == null
                ? '${s.boss} · ${s.arena.label}'
                : _lockShort(lock, i),
            stars: p.stars[s.id] ?? 0,
            locked: lock != null,
            done: p.done.contains(s.id),
            onTap: lock == null ? () => _play(i) : null,
          );
        },
      ),
    );
  }
}

/// 강호행 판 한 칸: 그 장의 배경 위에 고수 얼굴 · 제목 · 별.
class _StageCard extends StatelessWidget {
  const _StageCard({
    super.key,
    required this.scene,
    required this.face,
    required this.title,
    required this.sub,
    required this.stars,
    required this.locked,
    required this.done,
    required this.onTap,
  });
  final String scene;
  final String? face;
  final String title;
  final String sub;
  final int stars;
  final bool locked;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap == null
            ? () => Sound.play('error', 0.6)
            : () {
                Sound.play('ui_open');
                onTap!();
              },
        child: Container(
          // 글자가 커져도 칸이 늘어난다(고정 높이 128 은 넘쳤다).
          constraints: const BoxConstraints(minHeight: 112),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: locked ? Colors.white24 : Palette.gold,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  Art.background(scene),
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, 0.3),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: locked ? 0.8 : 0.65),
                        Colors.black.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Opacity(
                      opacity: locked ? 0.45 : 1,
                      child: Portrait(
                        id: face,
                        size: 86,
                        ring: locked ? Colors.white24 : Palette.gold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: OutlinedText(
                              title,
                              size: 20,
                              title: true,
                              align: TextAlign.start,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sub,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Palette.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              for (var k = 0; k < 3; k++)
                                Image.asset(
                                  Art.icon(k < stars ? 'star' : 'star_empty'),
                                  width: 24,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: locked
                          ? Image.asset(Art.icon('lock'), width: 40)
                          : (done
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Palette.jade,
                                    size: 40,
                                  )
                                : const Icon(
                                    Icons.play_circle_fill,
                                    color: Palette.gold,
                                    size: 46,
                                  )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 보상 창: 그림과 숫자로(설계서 §16.9).
Future<void> showRewardDialog(
  BuildContext context, {
  required String title,
  required bool won,
  required List<(String, String)> items,
  Fighter? newHero,
  String? note,
}) {
  if (won) Sound.play('jingle_reward');
  return showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: Colors.transparent,
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedText(
              title,
              size: 40,
              title: true,
              color: won ? Palette.gold : const Color(0xFFB0B8C8),
            ),
            const SizedBox(height: 12),
            for (final (icon, text) in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(Art.icon(icon), width: 40),
                    const SizedBox(width: 8),
                    Text(
                      text,
                      style: const TextStyle(
                        fontFamily: titleFont,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
            if (newHero != null) ...[
              const SizedBox(height: 8),
              CharacterSprite(id: newHero.name, height: 180),
              OutlinedText(
                '새 동료: ${newHero.label}',
                size: 22,
                color: Palette.gold,
              ),
              Text(newHero.trait, textAlign: TextAlign.center),
            ],
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                note,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17),
              ),
            ],
            const SizedBox(height: 16),
            GameButton(
              label: '확인',
              color: Palette.red,
              onTap: () => Navigator.pop(c),
              width: 180,
            ),
          ],
        ),
      ),
    ),
  );
}

/// 문파마다 짧은 한마디(읽지 않아도 그림·색으로 고르게, 글은 한 줄만).
String _schoolLine(Technique t) => switch (t) {
  Technique.swordQi => '일직선으로 쭉 밀고 나가요',
  Technique.stomp => '둘레 돌까지 밖으로 밀어요',
  Technique.taiji => '궤적이 휘어 돌아가요',
  Technique.clone => '두 개 맞히면 내 돌이 둘로',
  _ => '',
};

/// 문파 각성 창(설계서 §2.1): 큰 카드 넷 가운데 하나를 누르고, 「정말 이걸로?」에 답해야 정해진다.
/// 고른 [Technique] 으로 닫힌다. 한 번 고르면 환생 때까지 그대로라서 밖을 눌러 닫을 수는 없다.
class AwakenDialog extends StatefulWidget {
  const AwakenDialog({super.key});

  @override
  State<AwakenDialog> createState() => _AwakenDialogState();
}

class _AwakenDialogState extends State<AwakenDialog> {
  Technique? _pick;

  String _name(Technique t) => schools.firstWhere((e) => e.$1 == t).$2;

  @override
  Widget build(BuildContext context) {
    final pick = _pick;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: SingleChildScrollView(
            child: pick == null ? _cards() : _confirm(pick),
          ),
        ),
      ),
    );
  }

  Widget _cards() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const OutlinedText('문파 각성', size: 30, title: true, color: Palette.gold),
      const SizedBox(height: 4),
      // 영구 선택이라는 것을 한 번만, 눈에 띄게.
      const Text(
        '환생 전까지 바꿀 수 없어요',
        key: Key('awaken-warn'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Palette.gold),
      ),
      const SizedBox(height: 10),
      for (var r = 0; r < schools.length; r += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = r; c < r + 2 && c < schools.length; c++) ...[
                  if (c > r) const SizedBox(width: 10),
                  Expanded(
                    child: _SchoolCard(
                      key: Key('awaken-${schools[c].$1.name}'),
                      tech: schools[c].$1,
                      name: schools[c].$2,
                      onTap: () {
                        Sound.play('ui_tap');
                        setState(() => _pick = schools[c].$1);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
    ],
  );

  Widget _confirm(Technique t) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const OutlinedText('정말 이걸로?', size: 30, title: true, color: Palette.gold),
      const SizedBox(height: 10),
      SizedBox(
        width: 190,
        child: _SchoolCard(tech: t, name: _name(t), onTap: null),
      ),
      const SizedBox(height: 8),
      const Text(
        '환생 전까지 바꿀 수 없어요',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: GameButton(
              key: const Key('awaken-no'),
              label: '다시 고를래',
              color: Palette.skyDeep,
              height: 52,
              fontSize: 19,
              onTap: () => setState(() => _pick = null),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GameButton(
              key: const Key('awaken-yes'),
              label: '이걸로!',
              color: Palette.red,
              height: 52,
              fontSize: 22,
              sound: 'unlock',
              onTap: () => Navigator.pop(context, t),
            ),
          ),
        ],
      ),
    ],
  );
}

/// 문파 카드: 무공 빛깔 동그라미(글자 하나) + 이름 + 한 줄.
class _SchoolCard extends StatelessWidget {
  const _SchoolCard({
    super.key,
    required this.tech,
    required this.name,
    required this.onTap,
  });
  final Technique tech;
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = techniqueColor(tech);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: color, width: 2.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                name.characters.first,
                style: const TextStyle(
                  fontFamily: titleFont,
                  fontSize: 30,
                  color: Color(0xFF2A1A12),
                ),
              ),
            ),
            const SizedBox(height: 6),
            OutlinedText(name, size: 24, title: true),
            const SizedBox(height: 2),
            Text(
              _schoolLine(tech),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
