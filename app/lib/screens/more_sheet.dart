import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../progress/profile.dart';
import '../progress/settings.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'codex_screen.dart';
import 'credits_screen.dart';
import 'depot_screen.dart';
import 'free_play_screen.dart';
import 'legendary_shop_screen.dart';
import 'look_screen.dart';
import 'odds_screen.dart';
import 'puzzle_screen.dart';
import 'rebirth_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

/// 로비 「더보기」 (2026-10-19 형 「더 보기 기능들도 더 업그레이드 … 기능도 더 활성화」).
/// 묶음마다 그림 · 이름 · 한 줄 설명. 아직 못 여는 기능도 숨기지 않고 잠금과 여는 법을 보여 준다
/// (예전엔 환생은 조건 전엔 안 보였고, 기인방·만물상·도감은 로비 오른쪽에만 있었다).
class MoreSheet extends StatelessWidget {
  const MoreSheet({super.key, required this.profile, required this.open});

  final Profile profile;

  /// 화면 열기(시트를 닫은 뒤 로비가 연다).
  final void Function(Widget screen) open;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final now = DateTime.now();
    final legend = p.legendaryOpen(now.millisecondsSinceEpoch);
    final depot = p.depotOpen(now);
    final rebirth = p.canRebirth || p.rebirths > 0;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: ListView(
            controller: scroll,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Palette.dim,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const Center(child: OutlinedText('더 보기', size: 22)),
              _group('겨루기', [
                _MoreItem(
                  key: const Key('more-free'),
                  icon: 'free',
                  label: '자유 대전',
                  help: '대전장·상대·재질을 골라 한 판 · 둘이 하기',
                  onTap: () => open(const FreePlayScreen()),
                ),
                _MoreItem(
                  key: const Key('more-puzzle'),
                  icon: 'puzzle',
                  label: '묘수풀이',
                  help: '정해진 수 안에 모두 떨어뜨리기 · 별 셋 도전',
                  onTap: () => open(const PuzzleScreen()),
                ),
              ]),
              _group('상점', [
                _MoreItem(
                  key: const Key('more-shop'),
                  icon: 'shop',
                  label: '만물상',
                  help: '엽전으로 재질 돌 · 모양 · 재료',
                  onTap: () => open(const ShopScreen()),
                ),
                _MoreItem(
                  key: const Key('more-depot'),
                  icon: 'depot',
                  label: '무림맹 보급소',
                  help: depot
                      ? '징표로 비급 · 메달'
                      : '주말 · 목인항 1,000타 · 6장 격파 중 하나면 열림',
                  locked: !depot,
                  onTap: () => open(const DepotScreen()),
                ),
                _MoreItem(
                  key: const Key('more-legend'),
                  icon: 'legend',
                  label: '기인방',
                  help: legend
                      ? '지금 열려 있어요 — 10분만!'
                      : '판을 하다 기연으로 나타나면 10분 동안 열림',
                  locked: !legend,
                  badge: legend,
                  onTap: legend
                      ? () => open(const LegendaryShopScreen())
                      : null,
                ),
              ]),
              _group('성장 · 꾸미기', [
                _MoreItem(
                  key: const Key('more-codex'),
                  icon: 'codex',
                  label: '도감',
                  help: '모은 재질 · 모양 · 고수 · 천기 · 지물 (세트 보너스)',
                  onTap: () => open(const CodexScreen()),
                ),
                _MoreItem(
                  key: const Key('more-look'),
                  icon: 'look',
                  label: '꾸미기',
                  help: '내 돌이 날아갈 때 남는 잔상 고르기',
                  onTap: () => open(const LookScreen()),
                ),
                _MoreItem(
                  key: const Key('more-rebirth'),
                  icon: 'rebirth',
                  label: '환생 · 비승',
                  help: rebirth
                      ? (p.canRebirth ? '지금 환생할 수 있어요' : '환생 캐릭터 · 윤회천기')
                      : '6장을 깨고 내공 「${naegongStages.last.$1}」에 오르면 열림',
                  locked: !rebirth,
                  badge: p.canRebirth,
                  onTap: rebirth ? () => open(const RebirthScreen()) : null,
                ),
              ]),
              _group('안내', [
                _MoreItem(
                  key: const Key('more-odds'),
                  icon: 'odds',
                  label: '확률',
                  help: '기연 · 기인방 · 상자에서 나올 확률',
                  onTap: () => open(const OddsScreen()),
                ),
                _MoreItem(
                  key: const Key('more-settings'),
                  icon: 'settings',
                  label: '설정',
                  help: '소리 · 진동 · 조작 · 앱 꺼짐 기록',
                  onTap: () => open(const SettingsScreen()),
                ),
                _MoreItem(
                  key: const Key('more-credits'),
                  icon: 'mail',
                  label: '만든 이',
                  help: '알까기 · 탄지무림을 만든 사람들',
                  onTap: () => open(const CreditsScreen()),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(String title, List<Widget> items) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            title,
            style: const TextStyle(
              color: Palette.gold,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...items,
      ],
    ),
  );
}

/// 한 줄: 그림 · 이름 · 설명. 잠겨 있으면 흐리게 + 자물쇠, 누르면 여는 법을 알린다.
class _MoreItem extends StatelessWidget {
  const _MoreItem({
    super.key,
    required this.icon,
    required this.label,
    required this.help,
    required this.onTap,
    this.locked = false,
    this.badge = false,
  });

  final String icon;
  final String label;
  final String help;
  final VoidCallback? onTap;
  final bool locked;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.white.withValues(alpha: locked ? 0.03 : 0.07),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Sound.play('ui_tap', 0.7);
            Buzz.tick();
            final go = onTap;
            if (locked && go == null) {
              // 아래 시트 위에서는 알림 띠가 가려져 작은 창으로 알린다.
              showDialog<void>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text('$label — 아직 잠겨 있어요'),
                  content: Text(help),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('알겠어요'),
                    ),
                  ],
                ),
              );
              return;
            }
            go?.call();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Opacity(
                        opacity: locked ? 0.4 : 1,
                        child: Image.asset(Art.icon(icon), width: 48),
                      ),
                      if (locked)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Image.asset(Art.icon('lock'), width: 22),
                        ),
                      if (badge)
                        const Positioned(right: -2, top: -2, child: RedDot()),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: locked ? Palette.dim : Palette.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        help,
                        style: const TextStyle(
                          color: Palette.dim,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  locked ? Icons.lock_outline : Icons.chevron_right,
                  color: Palette.dim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
