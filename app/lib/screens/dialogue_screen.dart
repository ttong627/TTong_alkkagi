import 'package:flutter/material.dart';

import '../story/chapters.dart';

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

/// 대사 화면: 한 줄씩 눌러 넘긴다. 다 보면 닫힌다(건너뛰기 가능).
class DialogueScreen extends StatefulWidget {
  const DialogueScreen({super.key, required this.title, required this.lines});
  final String title;
  final List<Line> lines;

  @override
  State<DialogueScreen> createState() => _DialogueScreenState();
}

class _DialogueScreenState extends State<DialogueScreen> {
  int _i = 0;

  void _next() {
    if (_i + 1 >= widget.lines.length) {
      Navigator.of(context).pop();
    } else {
      setState(() => _i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (who, text) = widget.lines[_i];
    final narrator = who == '해설';
    final c = speakerColor(who);
    return Scaffold(
      backgroundColor: const Color(0xFF14110E),
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('건너뛰기'),
          ),
        ],
      ),
      body: GestureDetector(
        key: const Key('dialogue-tap'),
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),
                if (!narrator)
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: c.withValues(alpha: 0.25),
                    child: Text(
                      who.characters.first,
                      style: t.displayMedium?.copyWith(
                        color: c,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!narrator)
                        Text(
                          who,
                          style: t.titleMedium?.copyWith(
                            color: c,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (!narrator) const SizedBox(height: 6),
                      Text(
                        text,
                        style: t.titleMedium?.copyWith(
                          height: 1.6,
                          fontStyle: narrator ? FontStyle.italic : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${_i + 1} / ${widget.lines.length} · 눌러서 넘기기',
                  style: t.bodySmall,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
