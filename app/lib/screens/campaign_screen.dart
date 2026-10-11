import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

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
        MaterialPageRoute<void>(
          builder: (_) =>
              const DialogueScreen(title: '서장 · 기명석', lines: prologue),
        ),
      );
      p.codex.add('서장');
      await _store.save();
    }
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => DialogueScreen(title: s.title, lines: s.intro),
      ),
    );
    Match? last;
    final won = await nav.push<bool>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          config: Campaign.configFor(p, s),
          title: s.title,
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
    );
    await _store.save();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(won ? '승리!' : '패배'),
        content: Text(
          won
              ? [
                  '엽전 +${r.coins}${r.first ? ' (처음 깬 판 ×2)' : ''}',
                  if (r.silver > 0) '은자 +${r.silver}',
                  if (r.fine > 0) '백성 돌 배상 −${r.fine}',
                  if (r.hero != null)
                    '새 캐릭터: ${r.hero!.label} — ${r.hero!.trait}',
                ].join('\n')
              : '${s.boss}에게 졌습니다. 목인항에서 내공을 쌓거나 다시 도전하세요.'
                    '${r.fine > 0 ? '\n백성 돌 배상 −${r.fine}' : ''}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!won || !mounted) return;
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => DialogueScreen(title: s.title, lines: s.outro),
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
      MaterialPageRoute(
        builder: (_) => GameScreen(
          title: '폐관수련동',
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
    return Scaffold(
      appBar: AppBar(title: const Text('강호행')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: campaign.length + 1,
        itemBuilder: (_, i) {
          if (i == campaign.length) {
            final open = p.stage >= 7;
            return Card(
              child: ListTile(
                key: const Key('seclusion'),
                leading: Icon(open ? Icons.whatshot : Icons.lock),
                title: const Text('폐관수련동'),
                subtitle: Text(
                  open
                      ? '경지 수련자의 끝판 — 무공을 쓰는 강적 · 예상 궤적 없음'
                      : '내공 현경(2,400) 이 필요합니다',
                ),
                enabled: open,
                onTap: open ? _seclusion : null,
              ),
            );
          }
          final s = campaign[i];
          final lock = Campaign.lockReason(p, i);
          final done = p.done.contains(s.id);
          return Card(
            child: ListTile(
              key: Key('stage-${s.id}'),
              leading: Icon(
                done
                    ? Icons.check_circle
                    : (lock == null ? Icons.play_circle : Icons.lock),
                color: done ? innerColor : null,
              ),
              title: Text(s.title),
              subtitle: Text(
                lock ??
                    '${s.boss} · ${s.arena.label} · ${s.material.label} ${s.shape.label}'
                        '${s.martial.cost > 0 ? ' · 무공 ${s.martial.label}' : ''}'
                        '${s.weather != Weather.clear ? ' · 천기 ${s.weather.label}' : ''}'
                        '${s.features.isNotEmpty ? ' · 지물 ${{for (final f in s.features) f.kind.label}.join('·')}' : ''}'
                        '${s.civilians.isNotEmpty ? ' · 백성 돌 ${s.civilians.length}' : ''}'
                        '${s.shiftingFloor ? ' · 빙판↔불꽃 바닥' : ''}',
              ),
              enabled: lock == null,
              onTap: lock == null ? () => _play(i) : null,
            ),
          );
        },
      ),
    );
  }
}
