import 'dart:async';

import 'package:flutter/material.dart';

import '../game/flick.dart';
import '../input/touch_feed.dart';
import '../progress/settings.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'tutorial_screen.dart';

/// 설정 화면(설계서 §16.6).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = Settings.instance;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // 센서 점검 숫자가 살아 움직이게.
    _poll = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _set(void Function() f) {
    setState(f);
    s.save();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final range = TouchProfile.shared.range;
    final pct = (s.feel * 100).round();
    return GameScaffold(
      background: 'lobby',
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 입문(설계서 §16.10)을 다시: 사부와 수련 넷을 처음부터.
          GameButton(
            key: const Key('replay-tutorial'),
            label: '입문 수련 다시 하기',
            icon: 'training',
            color: Palette.jade,
            height: 56,
            fontSize: 20,
            onTap: () => Navigator.of(context).push(gameRoute<void>(const TutorialScreen())),
          ),
          const SizedBox(height: 16),
          Text('소리', style: t.titleMedium),
          ListTile(
            title: const Text('효과음'),
            subtitle: Slider(
              key: const Key('set-sfx'),
              value: s.sfx,
              onChanged: (v) => _set(() => s.sfx = v),
            ),
            trailing: Text('${(s.sfx * 100).round()}'),
          ),
          ListTile(
            title: const Text('음악'),
            subtitle: Slider(
              key: const Key('set-music'),
              value: s.music,
              onChanged: (v) => _set(() => s.music = v),
            ),
            trailing: Text('${(s.music * 100).round()}'),
          ),
          SwitchListTile(
            key: const Key('set-vibration'),
            title: const Text('진동'),
            value: s.vibration,
            onChanged: (v) => _set(() => s.vibration = v),
          ),
          const Divider(),
          Text('손맛', style: t.titleMedium),
          ListTile(
            title: Text(
              '손맛 보정 ${pct > 0 ? '+' : ''}$pct% '
              '(세기 기준 ${s.tuning.fullPxPerSec.round()}화소/초)',
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  key: const Key('set-feel'),
                  value: s.feel,
                  min: Settings.feelMin,
                  max: Settings.feelMax,
                  divisions: 12,
                  onChanged: (v) => _set(() => s.feel = v),
                ),
                const Text('손이 빨라 돌이 너무 세게 나가면 + 로, 느려서 약하게 나가면 − 로.'),
              ],
            ),
          ),
          SwitchListTile(
            key: const Key('set-hit-area'),
            title: const Text('위아래 타격점(손끝 닿은 넓이) 쓰기'),
            subtitle: Text(
              range == null
                  ? '평소 넓이를 배우는 중 — ${TouchProfile.shared.count}/30번 닿음'
                  : '배움 끝 — 넓게 닿으면 아래(떠서 날기), 살짝 닿으면 위(튀어 오르기)',
            ),
            value: s.hitArea,
            onChanged: (v) => _set(() => s.hitArea = v),
          ),
          ListTile(
            title: const Text('다시 배우기'),
            subtitle: const Text('평소 손끝 넓이 기록을 지우고 처음부터 배운다(폰을 바꿨을 때)'),
            trailing: OutlinedButton(
              key: const Key('set-relearn'),
              onPressed: () async {
                await s.resetAreas();
                if (mounted) setState(() {});
              },
              child: const Text('지우기'),
            ),
          ),
          const Divider(),
          Text('센서 점검', style: t.titleMedium),
          ListTile(
            key: const Key('sensor-check'),
            title: Text(
              '손가락 띄움(닿지 않은 손) 감지: '
              '${TouchFeed.instance.hoverPoints > 0 ? '됨 ✓ (${TouchFeed.instance.hoverPoints}점 받음)' : '아직 0점'}',
            ),
            subtitle: const Text(
              '손가락을 화면에 닿지 않게 1cm 위에서 움직여 보세요. 숫자가 오르면 이 폰은 안 닿고 '
              '돌 위를 스친 손을 「돌 위쪽(상단) 타격」으로 읽습니다. 0 에서 안 오르면 이 폰의 화면은 '
              '닿지 않은 손가락을 알려 주지 못합니다 — 그때는 아주 살짝 스치면 상단입니다.',
            ),
          ),
          ListTile(
            title: Text(
              '손끝 점 받기(안드로이드): ${TouchFeed.instance.active ? '됨 ✓' : '아직 — 화면을 한 번 만져 보세요'} · '
              '평소 넓이 ${TouchProfile.shared.count}번 모음',
            ),
          ),
          const Divider(),
          SwitchListTile(
            key: const Key('set-left'),
            title: const Text('왼손잡이'),
            subtitle: const Text('가까이 보기 화면의 단추를 오른쪽으로'),
            value: s.leftHanded,
            onChanged: (v) => _set(() => s.leftHanded = v),
          ),
        ],
      ),
    );
  }
}
