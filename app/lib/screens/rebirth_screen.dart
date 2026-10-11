import 'package:flutter/material.dart';

import '../progress/profile.dart';
import '../progress/store.dart';
import '../ui/kit.dart';

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
        title: const Text('환골탈태 — 환생 전용 캐릭터 하나를 만든다'),
        children: [
          for (final f in Fighter.values.where((f) => f.rebirth))
            SimpleDialogOption(
              key: Key('rebirth-${f.name}'),
              onPressed: () => Navigator.pop(c, f),
              child: ListTile(
                title: Text(f.label),
                subtitle: Text(f.trait),
                trailing: p.heroes.contains(f) ? const Text('이미 있음') : null,
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
    final t = Theme.of(context).textTheme;
    return GameScaffold(
      background: 'murimIce',
      appBar: AppBar(title: Text('비승 · 환생 ${p.rebirths}회')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('환골탈태(換骨奪胎)', style: t.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    '조건: 6장 우승 ${p.done.contains('c6') ? '✓' : '✗'} · '
                    '내공 생사경 ${p.stage >= naegongStages.length ? '✓' : '✗(${p.stageName})'}',
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '맹주: 「탄지는 끝이 없다. 다시 처음부터 걸어 보겠느냐.」 — 환생하면 같은 강호가 '
                    '어두운 마교 세계로 바뀌고, 묵현은 다른 문파의 무공을 익혀 다시 나타난다.',
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    key: const Key('rebirth-start'),
                    onPressed: p.canRebirth ? _rebirth : null,
                    child: const Text('환생하기'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('윤회천기 · 천년내단 ${p.danCores}개', style: t.titleMedium),
          for (final n in TreeNode.values)
            Card(
              child: ListTile(
                key: Key('tree-${n.name}'),
                title: Text(
                  '${n.label}  ${'●' * p.tree[n]!}${'○' * (TreeNode.maxLevel - p.tree[n]!)}',
                ),
                subtitle: Text(n.help),
                trailing: FilledButton(
                  onPressed: p.danCores > 0 && p.tree[n]! < TreeNode.maxLevel
                      ? () async {
                          p.openTree(n);
                          await _store.save();
                          if (mounted) setState(() {});
                        }
                      : null,
                  child: const Text('열기'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
