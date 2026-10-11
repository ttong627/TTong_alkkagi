import 'package:flutter/material.dart';

import '../progress/profile.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 비승 — 환골탈태(설계서 §10)와 윤회천기(§10.3).
class RebirthScreen extends StatefulWidget {
  const RebirthScreen({super.key});

  @override
  State<RebirthScreen> createState() => _RebirthScreenState();
}

class _RebirthScreenState extends State<RebirthScreen> {
  final _store = ProfileStore.instance;

  Future<void> _rebirth() async {
    final p = _store.profile;
    final chosen = await showDialog<Fighter>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('환골탈태 — 새 캐릭터 고르기'),
        children: [
          for (final f in Fighter.values.where((f) => f.rebirth))
            SimpleDialogOption(
              key: Key('rebirth-${f.name}'),
              onPressed: () => Navigator.pop(c, f),
              child: Row(
                children: [
                  Portrait(id: f.name, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.label,
                          style: const TextStyle(
                            fontFamily: titleFont,
                            fontFamilyFallback: fallbackFonts,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          f.trait,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Palette.dim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (p.heroes.contains(f)) const StateBadge('있음'),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('정말 환생하겠습니까?'),
        content: const Text(
          '처음으로: 내공·능력치·강호행 진행·엽전·수련 포인트·문파\n'
          '그대로: 은자·징표·재질·모양·외형·꾸미기·캐릭터·도감·기인방 효과\n'
          '얻음: 천년내단 1 · 환생 전용 캐릭터 · 어두운 마교 세계(블랙홀·지뢰석)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('그만두기'),
          ),
          FilledButton(
            key: const Key('rebirth-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('환골탈태'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    p.rebirth(chosen);
    await _store.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final cleared = p.done.contains('c6');
    final topStage = p.stage >= naegongStages.length;
    final unopened = TreeNode.values.any((n) => p.tree[n]! < TreeNode.maxLevel);
    return GameScaffold(
      background: 'murimIce',
      appBar: AppBar(
        title: const Text('비승'),
        actions: [
          InfoPill(icon: 'rebirth', text: '${p.rebirths}회'),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Image.asset(Art.icon('rebirth'), height: 80)),
                const SizedBox(height: 6),
                const Text(
                  '환골탈태(換骨奪胎)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: titleFont, fontSize: 22),
                ),
                const SizedBox(height: 4),
                const Text(
                  '「다시 처음부터 걸어 보겠느냐.」',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Palette.dim),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Cond('6장 우승', cleared),
                    _Cond(topStage ? '생사경' : '생사경 (${p.stageName})', topStage),
                  ],
                ),
                const SizedBox(height: 12),
                GameButton(
                  key: const Key('rebirth-start'),
                  label: '환생하기',
                  icon: 'rebirth',
                  height: 60,
                  onTap: p.canRebirth ? _rebirth : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SectionHead(
            '윤회천기',
            icon: 'dan',
            trailing: InfoPill(icon: 'dan', text: '${p.danCores}'),
          ),
          if (p.danCores == 0 && unopened)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '천년내단이 필요해요 · 환생하면 1개',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Palette.dim),
              ),
            ),
          for (final n in TreeNode.values)
            RowCard(
              key: Key('tree-${n.name}'),
              title:
                  '${n.label}  ${'●' * p.tree[n]!}${'○' * (TreeNode.maxLevel - p.tree[n]!)}',
              sub: n.help,
              trailing: p.tree[n]! >= TreeNode.maxLevel
                  ? const StateBadge('최고')
                  : SizedBox(
                      width: 100,
                      child: GameButton(
                        height: 44,
                        color: Palette.red,
                        onTap: p.danCores > 0
                            ? () async {
                                p.openTree(n);
                                await _store.save();
                                if (mounted) setState(() {});
                              }
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(Art.icon('dan'), height: 26),
                            const SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '열기',
                                  style: TextStyle(
                                    fontFamily: titleFont,
                                    fontSize: 18,
                                    color: p.danCores > 0
                                        ? Colors.white
                                        : Colors.white60,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

/// 조건 한 칸: ✔ 또는 ✗ + 짧은 이름.
class _Cond extends StatelessWidget {
  const _Cond(this.text, this.ok);
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ok ? Palette.jade : Palette.red),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          size: 20,
          color: ok ? Palette.jade : Palette.red,
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 16)),
      ],
    ),
  );
}
