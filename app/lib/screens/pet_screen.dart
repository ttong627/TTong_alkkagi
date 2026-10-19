import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/pets.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 영수(펫) 화면 — 데려오기 · 먹이(레벨) · 데리고 다니기(2026-10-20).
class PetScreen extends StatefulWidget {
  const PetScreen({super.key});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  final _store = ProfileStore.instance;

  Future<void> _act(bool ok, String fail) async {
    if (!ok) {
      Sound.play('error');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(fail)));
      return;
    }
    Sound.play('coin');
    await _store.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    return GameScaffold(
      background: 'lobby',
      appBar: AppBar(
        title: const Text('영수'),
        actions: [
          CurrencyPill(icon: 'coin', value: p.coins),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '한 마리를 데리고 다닌다 · 강호행·투기장·강호유랑에서 함께 싸운다 · 엽전 먹이로 레벨이 오른다',
              style: TextStyle(fontSize: 14, color: Palette.dim),
            ),
          ),
          for (final k in PetKind.values) _card(k),
        ],
      ),
    );
  }

  Widget _card(PetKind k) {
    final p = _store.profile;
    final lv = p.pets[k];
    final owned = lv != null;
    final withMe = p.pet == k;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        key: Key('pet-${k.name}'),
        borderColor: withMe ? Palette.gold : null,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: owned ? 1 : 0.45,
              child: Image.asset(Art.icon(k.art), width: 92),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owned ? '${k.label} · Lv.$lv' : k.label,
                    style: const TextStyle(
                      fontFamily: titleFont,
                      fontSize: 19,
                      color: Palette.gold,
                    ),
                  ),
                  Text(k.role, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    k.detail(lv ?? 1),
                    style: const TextStyle(fontSize: 13, color: Palette.dim),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (!owned)
                        FilledButton(
                          key: Key('pet-adopt-${k.name}'),
                          onPressed: () =>
                              _act(p.adoptPet(k), '엽전이 모자라요 — ${k.price} 필요'),
                          child: Text('데려오기 · 엽전 ${k.price}'),
                        )
                      else ...[
                        if (lv < PetKind.maxLevel)
                          OutlinedButton(
                            key: Key('pet-feed-${k.name}'),
                            onPressed: () => _act(
                              p.feedPet(k),
                              '엽전이 모자라요 — ${PetKind.feedCost(lv)} 필요',
                            ),
                            child: Text('먹이 · 엽전 ${PetKind.feedCost(lv)}'),
                          ),
                        if (!withMe)
                          FilledButton(
                            key: Key('pet-take-${k.name}'),
                            onPressed: () {
                              p.pet = k;
                              _act(true, '');
                            },
                            child: const Text('함께 다니기'),
                          )
                        else
                          const StateBadge('함께 다니는 중'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
