import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../progress/profile.dart';
import '../progress/store.dart';
import 'shop_screen.dart';
import '../ui/kit.dart';

/// 능력치(설계서 §2.3·§16.4)·캐릭터(§2.2·§16.3)·내 돌(산 재질·모양) 고르기.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _store = ProfileStore.instance;

  Future<void> _save() async {
    await _store.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final t = Theme.of(context).textTheme;
    return GameScaffold(
      background: 'kubiForest',
      appBar: AppBar(
        title: Text('능력치 · 수련 포인트 ${p.trainingPoints.toStringAsFixed(1)}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('능력치', style: t.titleMedium),
          if (p.codexBonus > 0)
            Text('도감 세트 보너스 +${p.codexBonus} (모든 능력치)', style: t.bodySmall),
          for (final s in Stat.values)
            Card(
              child: ListTile(
                title: Text('${s.label} · ${p.stats[s]}단계 / $maxStatLevel'),
                subtitle: Text(
                  '${s.help}\n지금: ${switch (s) {
                    Stat.power => '${p.maxSpeed.toStringAsFixed(0)}cm/s',
                    Stat.finesse => '×${p.spinScale.toStringAsFixed(2)}',
                    Stat.control => '${p.steerSeconds.toStringAsFixed(2)}초',
                  }}',
                ),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: p.canRaise(s)
                      ? () {
                          p.raise(s);
                          _save();
                        }
                      : null,
                  child: Text(
                    p.stats[s]! >= maxStatLevel
                        ? '최고'
                        : '+1 (${statCost(p.stats[s]!)})',
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text('캐릭터', style: t.titleMedium),
          for (final h in Fighter.values)
            Card(
              child: ListTile(
                leading: Icon(
                  p.hero == h
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                enabled: p.heroes.contains(h),
                onTap: () {
                  p.hero = h;
                  _save();
                },
                title: Text(p.heroes.contains(h) ? h.label : '${h.label} (잠김)'),
                subtitle: Text(h.trait),
              ),
            ),
          const SizedBox(height: 12),
          Text('내 돌 (만물상에서 산 것)', style: t.titleMedium),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in StoneMaterial.values)
                ChoiceChip(
                  avatar: stoneIcon(m, p.shape),
                  label: Text(m.label),
                  selected: p.material == m,
                  onSelected: p.materials.contains(m)
                      ? (_) {
                          p.material = m;
                          _save();
                        }
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in StoneShape.values)
                ChoiceChip(
                  avatar: stoneIcon(p.material, s),
                  label: Text(s.label),
                  selected: p.shape == s,
                  onSelected: p.shapes.contains(s)
                      ? (_) {
                          p.shape = s;
                          _save();
                        }
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
