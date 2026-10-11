import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/flick.dart';
import '../input/touch_feed.dart';
import '../progress/settings.dart';
import '../progress/store.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'tutorial_screen.dart';

/// 설정 화면(설계서 §16.6): 자주 쓰는 것(소리·진동·왼손잡이·백업)을 위에, 손맛·센서·입문 다시는 「고급」 안에.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = Settings.instance;

  /// 끌어서 바꾼 값이 아직 저장 전인가(끌기를 마칠 때 한 번만 저장한다).
  bool _dirty = false;

  @override
  void dispose() {
    // 끝맺음 없이 화면을 떠나도 바꾼 값은 남긴다.
    if (_dirty) s.save();
    super.dispose();
  }

  /// 값은 바로 바꾸고(소리가 곧장 달라짐), 저장은 [_commit] 에서 한 번.
  void _live(void Function() f) {
    setState(f);
    _dirty = true;
  }

  void _commit() {
    _dirty = false;
    s.save();
  }

  /// 단추·스위치처럼 한 번에 끝나는 것은 곧장 저장.
  void _set(void Function() f) {
    setState(f);
    _commit();
  }

  /// 입문 수련을 처음부터 다시: 한 번 묻고 연다.
  Future<void> _replay() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('입문 수련을 다시 할까요?'),
        content: const Text('사부와 수련 넷을 처음부터. 언제든 「나가기」로 나올 수 있어요.'),
        actions: [
          TextButton(
            key: const Key('replay-no'),
            onPressed: () => Navigator.pop(c, false),
            child: const Text('아니요'),
          ),
          FilledButton(
            key: const Key('replay-yes'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('다시 하기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await Navigator.of(context)
        .push(gameRoute<void>(const TutorialScreen(replay: true)));
  }

  /// 백업 코드를 붙여 넣어 진행을 바꾼다(지금 진행은 덮어씀 — 한 번 더 묻는다).
  Future<void> _restore(BuildContext context) async {
    // 입력칸(컨트롤러)은 창이 들고 있다가 창과 함께 정리한다(닫히는 동안 쓰이는 것을 먼저 지우지 않게).
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _RestoreDialog(),
    );
    if (code == null || !context.mounted) return;
    final done = await ProfileStore.instance.importCode(code);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done ? '불러왔습니다.' : '불러오지 못했습니다(코드가 틀렸거나 저장에 실패). 지금 진행은 그대로입니다.',
        ),
      ),
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
          // 조작 방식(2026-10-11 형 지시 「조작 방식 고르기」): 튕기기가 어려우면 당겨 쏘기.
          Text('조작 방식', style: t.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GameChip(
                key: const Key('control-flick'),
                label: '검지로 튕기기',
                selected: !s.pull,
                onTap: () => _set(() => s.pull = false),
              ),
              GameChip(
                key: const Key('control-pull'),
                label: '잡고 당겨 쏘기',
                selected: s.pull,
                onTap: () => _set(() => s.pull = true),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.pull
                ? '돌을 누른 채 뒤로 당겼다 놓으면 반대쪽으로 · 금빛 칸에서 놓으면 회심'
                : '손끝으로 돌을 툭 쳐서 · 가운데는 곧게, 가장자리는 비스듬히',
            style: t.bodySmall,
          ),
          const Divider(),
          Text('소리', style: t.titleMedium),
          ListTile(
            title: const Text('효과음'),
            subtitle: Slider(
              key: const Key('set-sfx'),
              value: s.sfx,
              onChanged: (v) => _live(() => s.sfx = v),
              onChangeEnd: (_) => _commit(),
            ),
            trailing: Text('${(s.sfx * 100).round()}'),
          ),
          ListTile(
            title: const Text('음악'),
            subtitle: Slider(
              key: const Key('set-music'),
              value: s.music,
              onChanged: (v) => _live(() => s.music = v),
              onChangeEnd: (_) => _commit(),
            ),
            trailing: Text('${(s.music * 100).round()}'),
          ),
          SwitchListTile(
            key: const Key('set-vibration'),
            title: const Text('진동'),
            value: s.vibration,
            onChanged: (v) => _set(() => s.vibration = v),
          ),
          SwitchListTile(
            key: const Key('set-left'),
            title: const Text('왼손잡이'),
            subtitle: const Text('가까이 보기 화면의 단추를 오른쪽으로'),
            value: s.leftHanded,
            onChanged: (v) => _set(() => s.leftHanded = v),
          ),
          const Divider(),
          // 진행 백업(설계서 §16.13): 서버가 없어 폰을 바꾸면 진행이 사라진다 → 코드로 옮긴다.
          Text('내 진행 옮기기', style: t.titleMedium),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          const Divider(),
          // 고급: 처음엔 접어 둔다(손맛 숫자·센서·입문 다시 하기).
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('settings-advanced'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('고급', style: t.titleMedium),
              subtitle: const Text('손맛 · 센서 · 입문 다시 하기'),
              children: [
                ListTile(
                  title: Text('손맛 조절  ${pct > 0 ? '+' : ''}$pct%'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Slider(
                        key: const Key('set-feel'),
                        value: s.feel,
                        min: Settings.feelMin,
                        max: Settings.feelMax,
                        divisions: 12,
                        onChanged: (v) => _live(() => s.feel = v),
                        onChangeEnd: (_) => _commit(),
                      ),
                      const Text('돌이 너무 세게 나가면 +, 너무 약하면 −'),
                    ],
                  ),
                ),
                SwitchListTile(
                  key: const Key('set-hit-area'),
                  title: const Text('손끝 넓이로 위·아래 치기'),
                  subtitle: Text(
                    range == null
                        ? '내 손을 배우는 중 — ${TouchProfile.shared.count}/30번'
                        : '배움 끝 — 손끝이 넓으면 아래, 살짝 닿으면 위를 쳐요',
                  ),
                  value: s.hitArea,
                  onChanged: (v) => _set(() => s.hitArea = v),
                ),
                ListTile(
                  title: const Text('손끝 기록 지우기'),
                  subtitle: const Text('폰을 바꿨을 때 처음부터 다시 배워요'),
                  trailing: OutlinedButton(
                    key: const Key('set-relearn'),
                    onPressed: () async {
                      await s.resetAreas();
                      if (mounted) setState(() {});
                    },
                    child: const Text('지우기'),
                  ),
                ),
                const _SensorCheck(),
                const SizedBox(height: 8),
                GameButton(
                  key: const Key('replay-tutorial'),
                  label: '입문 수련 다시 하기',
                  icon: 'training',
                  color: Palette.jade,
                  height: 52,
                  fontSize: 19,
                  onTap: _replay,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 센서 점검: 숫자가 살아 움직인다. 이 부분만 다시 그린다(펼쳤을 때만 돈다).
class _SensorCheck extends StatefulWidget {
  const _SensorCheck();

  @override
  State<_SensorCheck> createState() => _SensorCheckState();
}

class _SensorCheckState extends State<_SensorCheck> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = TouchFeed.instance;
    return Column(
      children: [
        ListTile(
          key: const Key('sensor-check'),
          title: Text(
            '손가락 띄움 감지: '
            '${feed.hoverPoints > 0 ? '됨 ✓' : '아직 안 됨'}',
          ),
          subtitle: const Text(
            '화면에 닿지 않게 1cm 위에서 손가락을 움직여 보세요. '
            '「됨」이 뜨면 이 폰은 스치는 손도 읽어 돌 위쪽을 쳐요. '
            '안 뜨면 아주 살짝 스치면 위쪽이에요.',
          ),
        ),
        ListTile(
          title: Text(
            '손끝 점 받기: ${feed.active ? '됨 ✓' : '아직 — 화면을 한 번 만져 보세요'}',
          ),
          subtitle: Text('내 손 기록 ${TouchProfile.shared.count}번'),
        ),
      ],
    );
  }
}

/// 「코드로 불러오기」 창. 쓴 코드 글을 담아 닫는다(그만두면 null).
class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog();

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('코드로 불러오기'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('지금 진행은 지워지고 코드의 진행으로 바뀝니다.'),
        const SizedBox(height: 10),
        TextField(
          key: const Key('backup-field'),
          controller: _ctl,
          maxLines: 3,
          maxLength: ProfileStore.maxCodeLength,
          // 글자 수 표시는 숨긴다(상한은 걸어 두기만).
          buildCounter: (
            _, {
            required currentLength,
            required isFocused,
            maxLength,
          }) => null,
          decoration: const InputDecoration(
            hintText: 'TJ1-…',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('그만두기'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _ctl.text),
        child: const Text('불러오기'),
      ),
    ],
  );
}
