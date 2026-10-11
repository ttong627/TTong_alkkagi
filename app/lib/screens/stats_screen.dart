import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../game/match.dart' show baseMaxSpeed;
import '../progress/profile.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'shop_screen.dart';

/// 능력치(설계서 §2.3·§16.4)·캐릭터(§2.2·§16.3)·내 돌(산 재질·모양) 고르기.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    // 첫 방문 안내(설계서 §16.13).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => firstVisit(context, 'stats', '수련 포인트로 힘·재주·집중을 올려라.'),
    );
  }

  final _store = ProfileStore.instance;

  Future<void> _save() async {
    await _store.save();
    if (mounted) setState(() {});
  }

  /// 아직 없는 돌을 누르면 만물상으로(다녀오면 새로 고침).
  Future<void> _toShop() async {
    await Navigator.of(context).push(gameRoute<void>(const ShopScreen()));
    if (mounted) setState(() {});
  }

  /// 능력치 지금 값을 한눈에(원시 단위 cm/s 대신 배수·초).
  String _now(Profile p, Stat s) => switch (s) {
    Stat.power => '세기 ×${(p.maxSpeed / baseMaxSpeed).toStringAsFixed(2)}',
    Stat.finesse => '회전 ×${p.spinScale.toStringAsFixed(2)}',
    Stat.control => '조준 ${p.steerSeconds.toStringAsFixed(1)}초',
  };

  static const _statIcon = {
    Stat.power: 'stats',
    Stat.finesse: 'naegong',
    Stat.control: 'wander',
  };

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final hero = p.hero;
    return GameScaffold(
      background: 'kubiForest',
      appBar: AppBar(
        title: const Text('능력치'),
        actions: [
          InfoPill(icon: 'tp', text: p.trainingPoints.toStringAsFixed(1)),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          SectionHead(
            '능력치',
            icon: 'stats',
            trailing: p.codexBonus > 0
                ? InfoPill(icon: 'codex', text: '+${p.codexBonus}')
                : null,
          ),
          for (final s in Stat.values)
            _StatRow(
              icon: _statIcon[s]!,
              name: s.label,
              level: p.stats[s]!,
              now: _now(p, s),
              canRaise: p.canRaise(s),
              cost: statCost(p.stats[s]!),
              onRaise: () {
                p.raise(s);
                _save();
              },
            ),
          const SizedBox(height: 8),
          SectionHead(
            '캐릭터',
            icon: 'free',
            trailing: InfoPill(
              text: '${p.heroes.length}/${Fighter.values.length}',
            ),
          ),
          _HeroGrid(
            profile: p,
            onPick: (h) {
              p.hero = h;
              _save();
            },
          ),
          if (hero != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                radius: 16,
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Palette.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hero.trait,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const SectionHead('내 돌', icon: 'shop'),
          GlassPanel(
            padding: const EdgeInsets.all(10),
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in StoneMaterial.values)
                      GameChip(
                        leading: stoneIcon(m, p.shape),
                        label: m.label,
                        selected: p.material == m,
                        locked: !p.materials.contains(m),
                        onTap: p.materials.contains(m)
                            ? () {
                                p.material = m;
                                _save();
                              }
                            : _toShop,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in StoneShape.values)
                      GameChip(
                        leading: stoneIcon(p.material, s),
                        label: s.label,
                        selected: p.shape == s,
                        locked: !p.shapes.contains(s),
                        onTap: p.shapes.contains(s)
                            ? () {
                                p.shape = s;
                                _save();
                              }
                            : _toShop,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 능력치 한 줄: 그림 · 이름 + 단계 막대 + 지금 값 · 올리기 단추.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.name,
    required this.level,
    required this.now,
    required this.canRaise,
    required this.cost,
    required this.onRaise,
  });
  final String icon;
  final String name;
  final int level;
  final String now;
  final bool canRaise;
  final int cost;
  final VoidCallback onRaise;

  @override
  Widget build(BuildContext context) {
    final maxed = level >= maxStatLevel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(10),
        radius: 18,
        child: Row(
          children: [
            Image.asset(Art.icon(icon), width: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: titleFont,
                            fontFamilyFallback: fallbackFonts,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      Text(
                        '$level/$maxStatLevel',
                        style: const TextStyle(color: Palette.dim),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GameBar(
                    value: level / maxStatLevel,
                    color: maxed ? Palette.jade : Palette.gold,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    now,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Palette.dim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: maxed
                  ? const Center(
                      child: Icon(
                        Icons.check_circle,
                        color: Palette.jade,
                        size: 40,
                        semanticLabel: '최고',
                      ),
                    )
                  : GameButton(
                      height: 44,
                      color: Palette.red,
                      onTap: canRaise ? onRaise : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(Art.icon('tp'), height: 26),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$cost',
                                style: TextStyle(
                                  fontFamily: titleFont,
                                  fontSize: 18,
                                  color: canRaise
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
          ],
        ),
      ),
    );
  }
}

/// 캐릭터 고르기: 가진 것은 얼굴 + 이름, 못 가진 것은 검은 그림자 + 「???」(이름·특징을 알리지 않는다).
class _HeroGrid extends StatelessWidget {
  const _HeroGrid({required this.profile, required this.onPick});
  final Profile profile;
  final ValueChanged<Fighter> onPick;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        final cols = box.maxWidth >= 360 ? 4 : 3;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final h in Fighter.values)
              SizedBox(
                width: w,
                child: _HeroTile(
                  fighter: h,
                  owned: profile.heroes.contains(h),
                  picked: profile.hero == h,
                  onTap: () => onPick(h),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({
    required this.fighter,
    required this.owned,
    required this.picked,
    required this.onTap,
  });
  final Fighter fighter;
  final bool owned;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final face = Portrait(
      id: fighter.name,
      size: 52,
      ring: picked ? Palette.gold : (owned ? Palette.goldDeep : Colors.white24),
    );
    final tile = GlassPanel(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      radius: 16,
      borderColor: picked ? Palette.gold : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              owned
                  ? face
                  : ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF0E0A12),
                        BlendMode.srcATop,
                      ),
                      child: face,
                    ),
              if (picked)
                const Positioned(
                  right: -4,
                  bottom: -2,
                  child: Icon(
                    Icons.check_circle,
                    color: Palette.jade,
                    size: 22,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              owned ? fighter.label : '???',
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                color: owned ? Palette.text : Palette.dim,
              ),
            ),
          ),
        ],
      ),
    );
    if (!owned) {
      return Semantics(
        label: '잠긴 캐릭터',
        child: ExcludeSemantics(child: tile),
      );
    }
    return Semantics(
      button: true,
      selected: picked,
      label: fighter.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      ),
    );
  }
}
