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
  final _store = ProfileStore.instance;

  Future<void> _play(int i) async {
    final p = _store.profile;
    final s = campaign[i];
    final nav = Navigator.of(context);
    if (!p.codex.contains('서장')) {
      await nav.push(
        gameRoute<void>(
          const DialogueScreen(
            title: '서장 · 기명석',
            lines: prologue,
            scene: 'lobby',
          ),
        ),
      );
      p.codex.add('서장');
      await _store.save();
    }
    Sound.play('jingle_chapter');
    await nav.push(
      gameRoute<void>(
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
    Match? last;
    final won = await nav.push<bool>(
      gameRoute(
        GameScreen(
          config: Campaign.configFor(p, s),
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
      gameRoute<void>(
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
    if (won == true) {
      p.coins += 200;
      p.tokens += 2;
    }
    await _store.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(won == true ? '폐관 고수를 꺾었다 — 엽전 +200 · 징표 +2' : '아직 이르다'),
      ),
    );
    setState(() {});
    await afterRound(context);
  }

  /// 1장을 처음 깨면 문파를 고른다(설계서 §2.1 · 한 번 고르면 환생 때까지 그대로).
  Future<void> _awaken() async {
    final t = await showDialog<Technique>(
      context: context,
      barrierDismissible: false,
      builder: (c) => SimpleDialog(
        title: const Text('기명석이 빛난다 — 문파 각성'),
        children: [
          for (final (tech, school) in schools)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, tech),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: techniqueColor(tech)),
                title: Text('$school · ${tech.label}'),
                subtitle: Text(martialHelp(tech).split(' · ').first),
              ),
            ),
        ],
      ),
    );
    if (t == null) return;
    _store.profile.school = t;
    _store.profile.codex.add('문파:${t.name}');
    await _store.save();
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
        itemCount: campaign.length + 1,
        itemBuilder: (_, i) {
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
            sub: lock ?? '${s.boss} · ${s.arena.label}',
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
          height: 128,
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
            fit: StackFit.expand,
            children: [
              Image.asset(
                Art.background(scene),
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.3),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: locked ? 0.8 : 0.65),
                      Colors.black.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
              Row(
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
