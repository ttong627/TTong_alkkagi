import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/match.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import 'encounter_flow.dart';
import 'game_screen.dart';

/// 목인항: 목각 더미를 맞힐 때마다 1타. 하루 처음 30타는 내공 3배(깨달음), 그 뒤 0.1배
/// (설계서 §5.2). 꾸준히 매일 30타가 가장 빨리 큰다.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final _store = ProfileStore.instance;
  final _rand = math.Random();
  double _gained = 0;
  String _last = '목각 더미를 맞히세요';

  void _onTurnEnd(Match m) {
    final p = _store.profile;
    if (m.touchedThisTurn.contains(1)) {
      final g = p.trainHit(today());
      _gained += g;
      _last = g >= Training.bonus ? '깨달음! 내공 +$g' : '내공 +$g';
    } else {
      _last = '빗나감 — 더미를 맞혀야 1타';
    }
    _store.save();
    // 30타가 「1판」 — 기연을 뽑는다(설계서 §5.3).
    if (m.touchedThisTurn.contains(1) && p.trainingHits % 30 == 0) {
      afterRound(context);
    }
    // 더미를 새 자리로.
    m.resetTraining(-8 + _rand.nextDouble() * 16, -8 + _rand.nextDouble() * 10);
  }

  String _info() {
    final p = _store.profile;
    final todayHits = p.trainingDay == today() ? p.trainingHits : 0;
    final left = math.max(0, Training.enlightened - todayHits);
    return '오늘 $todayHits타 · 깨달음 $left타 남음 · 이번에 내공 +${_gained.toStringAsFixed(1)} · $_last';
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    return GameScreen(
      title: '목인항 · 수련',
      config: MatchConfig(
        mode: MatchMode.practice,
        training: true,
        opponentName: '목각 더미',
        myMaterial: p.material,
        myShape: p.shape,
        powerScale: p.maxSpeed / baseMaxSpeed,
        spinScale: p.spinScale,
      ),
      onTurnEnd: _onTurnEnd,
      info: _info,
    );
  }
}
