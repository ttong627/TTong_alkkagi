import 'package:flutter/material.dart';

import '../game/flick.dart';
import '../progress/settings.dart';

/// 설정 화면(설계서 §16.6).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = Settings.instance;

  void _set(void Function() f) {
    setState(f);
    s.save();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final range = TouchProfile.shared.range;
    final pct = (s.feel * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
