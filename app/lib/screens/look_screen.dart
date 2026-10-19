import 'package:flutter/material.dart';

import '../game/fx_colors.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 꾸미기: 내 돌이 날아갈 때 남는 잔상 고르기.
///
/// 2026-10-19 형 「꾸미기가 엉망인데 위치도 그렇고 이미지도 하나도 안맞고 완전 개판」·「이상하면 꾸미기 기능을 빼던지」:
/// 예전 얼굴·머리·도복은 코드로 그린 작은 인형이라 무협 캐릭터 그림과 맞지 않았고 다른 화면 어디에도 쓰이지 않았다 → 뺐다.
/// 대신 모아도 고를 곳이 없던 잔상(보급소·수레 객잔·기인방·무공 「불꽃 궤적」)을 여기서 고른다.
class LookScreen extends StatefulWidget {
  const LookScreen({super.key});

  @override
  State<LookScreen> createState() => _LookScreenState();
}

/// 잔상 이름 · 얻는 곳.
const trailCatalog = [
  ('기본', '처음부터'),
  ('금빛 잔상', '기인방'),
  ('불꽃', '무공 「불꽃 궤적」'),
  ('달맞이', '무림맹 보급소 · 강호유랑 수레 객잔'),
  ('청죽', '무림맹 보급소 · 강호유랑 수레 객잔'),
  ('먹물', '무림맹 보급소 · 강호유랑 수레 객잔'),
];

class _LookScreenState extends State<LookScreen> {
  final _store = ProfileStore.instance;

  Future<void> _pick(String name) async {
    _store.profile.trail = name;
    await _store.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final hero = p.hero;
    return GameScaffold(
      background: 'lobby',
      appBar: AppBar(title: const Text('꾸미기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (hero != null)
            SizedBox(
              height: 300,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Image.asset(
                    Art.character(Art.fighterId(hero)),
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: OutlinedText(hero.label, size: 22),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          GlassPanel(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHead('돌 잔상', icon: 'look'),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '내 돌이 날아갈 때 남는 빛 — 모든 판에 나와요',
                    style: TextStyle(fontSize: 14, color: Palette.dim),
                  ),
                ),
                for (final (name, where) in trailCatalog)
                  _TrailRow(
                    key: Key('trail-$name'),
                    name: name,
                    where: where,
                    owned: name == '기본' || p.trails.contains(name),
                    selected: p.trail == name,
                    onTap: () => _pick(name),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '능력치와 무관 · 환생해도 유지',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Palette.dim),
          ),
        ],
      ),
    );
  }
}

/// 잔상 한 줄: 색 띠 미리보기 · 이름 · 얻는 곳(못 가졌을 때) · 고름 표시.
class _TrailRow extends StatelessWidget {
  const _TrailRow({
    super.key,
    required this.name,
    required this.where,
    required this.owned,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String where;
  final bool owned;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = trailColor(name) ?? Palette.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected
            ? Palette.gold.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: owned ? 0.07 : 0.03),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: owned ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                // 색 띠: 왼쪽은 옅고 돌 쪽(오른쪽)으로 진해지는 꼬리.
                Container(
                  width: 64,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0),
                        color.withValues(alpha: owned ? 0.95 : 0.3),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: owned ? Palette.text : Palette.dim,
                        ),
                      ),
                      if (!owned)
                        Text(
                          '얻는 곳: $where',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Palette.dim,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: Palette.gold)
                else if (!owned)
                  Image.asset(Art.icon('lock'), width: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
