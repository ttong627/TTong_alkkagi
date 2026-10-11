import 'dart:async';

import 'package:flutter/material.dart';

import '../game/flick.dart';
import '../input/touch_feed.dart';
import '../progress/settings.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'tutorial_screen.dart';

import 'package:flutter/services.dart';

import '../progress/store.dart';

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

  /// 백업 코드를 붙여 넣어 진행을 바꾼다(지금 진행은 덮어씀 — 한 번 더 묻는다).
  Future<void> _restore(BuildContext context) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('코드로 불러오기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('지금 진행은 지워지고 코드의 진행으로 바뀝니다.'),
            const SizedBox(height: 10),
            TextField(
              key: const Key('backup-field'),
              controller: ctl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'TJ1-…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('그만두기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('불러오기'),
          ),
        ],
      ),
    );
    final code = ctl.text;
    ctl.dispose();
    if (ok != true || !context.mounted) return;
    final done = await ProfileStore.instance.importCode(code);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(done ? '불러왔습니다.' : '코드가 맞지 않습니다. 지금 진행은 그대로입니다.')),
    );
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
            onTap: () =>
                Navigator.of(context)
                    .push(gameRoute<void>(const TutorialScreen())),
          ),
          const SizedBox(height: 10),
          // 진행 백업(설계서 §16.13): 서버가 없어 폰을 바꾸면 진행이 사라진다 → 코드로 옮긴다.
          Row(
            children: [
              Expanded(
                child: GameButton(
                  key: const Key('backup-copy'),
                  label: '백업 코드 복사',
                  color: Palette.sky,
                  height: 50,
                  fontSize: 17,
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: ProfileStore.instance.exportCode()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('백업 코드를 복사했습니다. 메모·메신저에 붙여 넣어 두세요.'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GameButton(
                  key: const Key('backup-restore'),
                  label: '코드로 불러오기',
                  color: Palette.sky,
                  height: 50,
                  fontSize: 17,
                  onTap: () => _restore(context),
                ),
              ),
            ],
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
