import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/match.dart';
import '../progress/drills.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import 'encounter_flow.dart';
import 'game_screen.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 목인항: 목각 더미를 맞힐 때마다 1타. 하루 처음 30타는 내공 3배(깨달음), 그 뒤 0.1배
/// (설계서 §5.2). 꾸준히 매일 30타가 가장 빨리 큰다.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  @override
  void initState() {
    super.initState();
    // 첫 방문 안내(설계서 §16.13).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          firstVisit(context, 'training', '목각 더미를 맞혀라. 하루 처음 30타는 내공이 세 배다!'),
    );
  }

  final _store = ProfileStore.instance;
  final _rand = math.Random();
  double _gained = 0;
  String _last = '목각 더미를 맞히세요';

  /// 마지막으로 저장을 마친 시각(2026-10-14 형 「저장 기능 … 알 수 있게」). 실패하면 null.
  DateTime? _savedAt;
  bool _saveFailed = false;

  @override
  void dispose() {
    // 나갈 때도 한 번 더 저장한다(수련은 칠 때마다 저장되지만, 끝맺음을 분명히).
    _store.save();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await _store.save();
    if (!mounted) return;
    setState(() {
      _saveFailed = !ok;
      if (ok) _savedAt = DateTime.now();
    });
  }

  /// 지금 하는 수련 단계(0~9 · drills.dart · 2026-10-14 형 「목인항 수련 단계별로」).
  late int _drill = _store.profile.drillIndex.clamp(
    0,
    Drills.open(_store.profile) - 1,
  );

  Drill get _d => drills[_drill];

  void _onTurnEnd(Match m) {
    final p = _store.profile;
    final dummies = [
      for (final s in m.table.stones)
        if (s.team == 1) s,
    ];
    final touched = dummies.where((s) => m.touchedThisTurn.contains(s.id));
    final hitAny = touched.isNotEmpty;
    if (hitAny) {
      final g = p.trainHit(today());
      // 경지가 오르면 바로 축하.
      if (p.stage > p.celebratedStage) celebrateStage(context);
      _gained += g;
      _last = g >= Training.bonus ? '깨달음! 내공 +$g' : '내공 +$g';
    } else {
      _last = '빗나감 — 더미를 맞혀야 1타';
    }
    // 단계 수련: 이 수가 세어지나.
    final step = Drills.record(
      p,
      _drill,
      DrillShot(
        touched: touched.length,
        out: dummies.where((s) => s.out).length,
        critical: m.lastCritical,
        hit: m.lastHit,
        flick: m.lastFlick,
        inner: m.lastMode != StrikeMode.plain,
      ),
    );
    if (step.counted) _last = '${_d.name} 성공! · $_last';
    _save();
    // 30타가 「1판」 — 기연을 뽑는다(설계서 §5.3).
    if (hitAny && p.trainingHits % 30 == 0) {
      afterRound(context);
    }
    if (_d.fullQi) m.addQi(0, maxQi);
    // 더미를 새 자리로(장외·박살 수련은 판 끝 가까이).
    m.resetTraining(
      -8 + _rand.nextDouble() * 16,
      _d.edge ? -(m.table.half - 3.5) : -8 + _rand.nextDouble() * 10,
    );
    if (step.cleared) _cleared(step);
  }

  /// 단계를 깼다: 보상 창 → 다음 단계로.
  Future<void> _cleared(DrillStep step) async {
    Sound.play('unlock');
    final r = step.reward;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('drill-cleared'),
        title: Text('수련 ${_drill + 1} 「${_d.name}」 통과!'),
        content: Text(
          r == null
              ? '다시 익혔다.'
              : '내공 +${r.naegong} · 수련 포인트 +${r.tp}'
                    '${r.perk == null ? '' : '\n${r.perk} 익힘 — ${drillPerkHelp(r.perk!)}'}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('다음 수련'),
          ),
        ],
      ),
    );
    await _store.save();
    if (!mounted) return;
    setState(
      () => _drill = (_drill + 1).clamp(0, Drills.open(_store.profile) - 1),
    );
  }

  /// 수련 단계 고르기(깬 단계 + 다음 한 단계).
  Future<void> _pickDrill() async {
    final p = _store.profile;
    final i = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Palette.panel,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: [
            for (var k = 0; k < drills.length; k++)
              ListTile(
                key: Key('drill-$k'),
                enabled: k < Drills.open(p),
                leading: Icon(
                  k < p.drillCleared
                      ? Icons.check_circle
                      : (k < Drills.open(p) ? Icons.play_circle : Icons.lock),
                  color: k < p.drillCleared ? Palette.jade : Palette.gold,
                ),
                title: Text('${k + 1}. ${drills[k].name}'),
                subtitle: Text(
                  '${drills[k].how}'
                  '${drills[k].perk == null ? '' : ' · 익힘: ${drills[k].perk}'}',
                ),
                onTap: () => Navigator.pop(c, k),
              ),
          ],
        ),
      ),
    );
    if (i == null || !mounted) return;
    setState(() => _drill = i);
  }

  String _info() => '이번에 내공 +${_gained.toStringAsFixed(1)} · $_last';

  /// 진행 칸: 다음 경지까지 · 오늘 깨달음 30타 · 저장 상태(2026-10-14 형 「다음 목표치와 진행 상황」).
  Widget _panel() {
    final p = _store.profile;
    final g = TrainingGoal.of(p, today());
    final saved = _savedAt;
    return Padding(
      key: const Key('training-panel'),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 단계 수련 — 지금 단계 · 할 일 · 진행.
          Row(
            children: [
              Expanded(
                child: _bar(
                  '수련 ${_drill + 1}/${drills.length} · ${_d.name} — ${_d.how}'
                  ' · ${p.drillIndex == _drill ? p.drillProgress : 0}/${_d.goal}',
                  (p.drillIndex == _drill ? p.drillProgress : 0) / _d.goal,
                  const Color(0xFFE08A2E),
                  const Key('goal-drill'),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                key: const Key('drill-pick'),
                onPressed: _pickDrill,
                child: const Text('단계'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _bar(
            g.nextName == null
                ? '${g.stageName} · 마지막 경지'
                : '${g.stageName} → ${g.nextName} · 내공 ${g.have.floor()}/${g.need.floor()}',
            g.stageProgress,
            Palette.gold,
            const Key('goal-stage'),
          ),
          const SizedBox(height: 4),
          _bar(
            g.todayHits >= Training.enlightened
                ? '오늘 깨달음 다 채움 — 이제 1타 내공 0.1'
                : '오늘 깨달음 ${g.todayHits}/${Training.enlightened}타 (내공 3배)',
            g.todayHits / Training.enlightened,
            Palette.jade,
            const Key('goal-today'),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _saveFailed
                    ? '저장 실패 — 다시 눌러 주세요'
                    : saved == null
                    ? '칠 때마다 저절로 저장돼요'
                    : '저장됨 · ${saved.hour.toString().padLeft(2, '0')}:${saved.minute.toString().padLeft(2, '0')}',
                key: const Key('training-saved'),
                style: TextStyle(
                  fontSize: 13,
                  color: _saveFailed ? Palette.red : Palette.dim,
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                key: const Key('training-save'),
                onPressed: _save,
                child: const Text('저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(String label, double value, Color color, Key key) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 2),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: 7,
          color: color,
          backgroundColor: Colors.white12,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    return GameScreen(
      // 단계가 바뀌면 판을 새로(더미 수·내공이 다르다).
      key: ValueKey('drill-$_drill'),
      title: '목인항 · ${_d.name}',
      config: MatchConfig(
        mode: MatchMode.practice,
        training: true,
        opponentName: '목각 더미',
        myMaterial: p.material,
        myShape: p.shape,
        powerScale: p.maxSpeed / baseMaxSpeed,
        spinScale: p.spinScale,
        trainingDummies: _d.dummies,
        myStartQi: _d.fullQi ? maxQi : 0,
      ),
      onTurnEnd: _onTurnEnd,
      info: _info,
      panel: _panel,
    );
  }
}
