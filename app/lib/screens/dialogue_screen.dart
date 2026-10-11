import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../progress/store.dart';
import '../story/chapters.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 말하는 사람마다 빛깔.
Color speakerColor(String who) => switch (who) {
  '촌장' => const Color(0xFFE6C38A),
  '통통' => const Color(0xFFFFA45C),
  '묵현' => const Color(0xFFB07CFF),
  '자객' => const Color(0xFF9AA4B2),
  '쿠비' => const Color(0xFF8FD16A),
  '로직' => const Color(0xFF7FD4FF),
  '맹주' => const Color(0xFFFFD34D),
  _ => const Color(0xFFDDDDDD),
};

/// 대사 화면(설계서 §16.11): 말하는 사람이 그림으로 서서 말한다. 글자는 한 자씩 나온다.
/// 누르면 다음 줄(글자가 다 안 나왔으면 먼저 다 보여 준다).
/// 아래 큰 「건너뛰기」를 누르면 `true` 로 닫힌다 — 부른 쪽이 이어지는 대사도 함께 건너뛸 수 있다.
/// 끝까지 읽고 닫으면 `null`.
class DialogueScreen extends StatefulWidget {
  const DialogueScreen({
    super.key,
    required this.title,
    required this.lines,
    this.scene = 'lobby',
  });
  final String title;
  final List<Line> lines;

  /// 배경 그림 이름([Art.background]).
  final String scene;

  @override
  State<DialogueScreen> createState() => _DialogueScreenState();
}

class _DialogueScreenState extends State<DialogueScreen>
    with SingleTickerProviderStateMixin {
  int _i = 0;
  late final _type = AnimationController(vsync: this);
  final _strike = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final (_, text) = widget.lines[_i];
    _type
      ..duration = Duration(milliseconds: (text.length * 28).clamp(300, 2600))
      ..forward(from: 0);
    _strike.value++;
  }

  @override
  void dispose() {
    _type.dispose();
    _strike.dispose();
    super.dispose();
  }

  void _next() {
    if (_type.isAnimating) {
      _type.value = 1;
      return;
    }
    Sound.play('ui_tap', 0.6);
    if (_i + 1 >= widget.lines.length) {
      Navigator.of(context).pop();
    } else {
      setState(() => _i++);
      _start();
    }
  }

  /// 말하는 사람 그림 이름(「나」는 내 캐릭터).
  String? _face(String who) => who == '나'
      ? (ProfileStore.instance.profile.hero?.name ?? 'seokdu')
      : Art.bossId(who);

  @override
  Widget build(BuildContext context) {
    final (who, text) = widget.lines[_i];
    final narrator = who == '해설';
    final c = speakerColor(who);
    final face = narrator ? null : _face(who);
    // 사람이 바뀔 때마다 왼쪽·오른쪽을 번갈아 선다.
    final left = _i.isEven;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(widget.title)),
      body: SceneBackground(
        asset: Art.background(widget.scene),
        dim: narrator ? 0.55 : 0.3,
        child: GestureDetector(
          key: const Key('dialogue-tap'),
          behavior: HitTestBehavior.opaque,
          onTap: _next,
          child: SafeArea(
            child: Stack(
              children: [
                if (face != null)
                  AnimatedAlign(
                    key: ValueKey('who-$_i'),
                    duration: const Duration(milliseconds: 300),
                    alignment: Alignment(left ? -0.75 : 0.75, 0.25),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutBack,
                      builder: (_, k, child) => Transform.translate(
                        offset: Offset((left ? -1 : 1) * 60 * (1 - k), 0),
                        child: Opacity(opacity: k.clamp(0, 1), child: child),
                      ),
                      child: CharacterSprite(
                        id: face,
                        height: math.min(
                          360,
                          MediaQuery.sizeOf(context).height * 0.42,
                        ),
                        attack: _strike,
                        flip: !left,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 150),
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                          decoration: BoxDecoration(
                            color: narrator
                                ? Colors.black.withValues(alpha: 0.7)
                                : Palette.paper,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: narrator
                                  ? Palette.gold
                                  : const Color(0xFF2A1A12),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: AnimatedBuilder(
                            animation: _type,
                            builder: (_, _) {
                              final n = (text.length * _type.value).round();
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!narrator)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        who,
                                        style: const TextStyle(
                                          fontFamily: titleFont,
                                          fontSize: 16,
                                          color: Color(0xFF2A1A12),
                                        ),
                                      ),
                                    ),
                                  if (!narrator) const SizedBox(height: 8),
                                  Text(
                                    text.substring(0, n),
                                    style: TextStyle(
                                      fontFamily: bodyFont,
                                      fontSize: 21,
                                      height: 1.45,
                                      color: narrator
                                          ? Palette.text
                                          : const Color(0xFF2A1A12),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Opacity(
                                      opacity: _type.isAnimating ? 0 : 1,
                                      child: Text(
                                        '${_i + 1}/${widget.lines.length} ▼',
                                        style: TextStyle(
                                          color: narrator
                                              ? Palette.dim
                                              : const Color(0x992A1A12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      // 큰 건너뛰기: 이어지는 대사까지 한꺼번에(부른 쪽이 true 를 받는다).
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GameButton(
                          key: const Key('dialogue-skip'),
                          label: '건너뛰기 ▶▶',
                          color: Palette.skyDeep,
                          height: 46,
                          width: 200,
                          fontSize: 20,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
