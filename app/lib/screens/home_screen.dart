import 'package:flutter/material.dart';

import '../e2e.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import '../update/updater.dart';
import '../version.dart';
import 'arena_screen.dart';
import 'campaign_screen.dart';
import 'codex_screen.dart';
import 'depot_screen.dart';
import 'free_play_screen.dart';
import 'legendary_shop_screen.dart';
import 'odds_screen.dart';
import 'puzzle_screen.dart';
import 'rebirth_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'stats_screen.dart';
import 'training_screen.dart';
import 'wander_screen.dart';

/// 첫 화면: 내 진행(캐릭터·문파·내공 단계·재화)과 메뉴.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _updater = Updater();
  final _store = ProfileStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updater.addListener(_onUpdate);
    _store.addListener(_onUpdate);
    _updater.run();
    if (e2eFlick) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _open(const FreePlayScreen(autoPractice: true)),
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickHeroIfNew());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onUpdate);
    _updater
      ..removeListener(_onUpdate)
      ..dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _updater.resumed();
  }

  Future<void> _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  /// 처음 켰으면 캐릭터를 고른다(설계서 §2.1).
  Future<void> _pickHeroIfNew() async {
    if (_store.profile.hero != null || !mounted) return;
    final h = await showDialog<Fighter>(
      context: context,
      barrierDismissible: false,
      builder: (c) => SimpleDialog(
        title: const Text('누구로 강호에 나서겠습니까?'),
        children: [
          for (final h in Fighter.values.where((h) => h.starter))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, h),
              child: ListTile(title: Text(h.label), subtitle: Text(h.trait)),
            ),
        ],
      ),
    );
    if (h == null) return;
    _store.profile
      ..hero = h
      ..heroes.add(h)
      ..codex.add('캐릭터:${h.name}');
    await _store.save();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = _store.profile;
    final next = p.toNextStage;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            UpdateBanner(updater: _updater),
            Text(
              '탄지무림 알까기',
              textAlign: TextAlign.center,
              style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '손끝으로 펼치는 무협 알까기',
              textAlign: TextAlign.center,
              style: t.titleMedium,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.hero?.label ?? '이름 없는 초행자'} · '
                      '${p.school == null ? '평민(1장을 깨면 문파 각성)' : '${p.school!.label} 문파'}',
                      style: t.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '내공 ${p.stageName}(${p.stage}단계) · ${p.naegong.toStringAsFixed(1)}'
                      '${next == null ? '' : ' · 다음 단계까지 ${next.toStringAsFixed(1)}'}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '엽전 ${p.coins} · 은자 ${p.silver} · 징표 ${p.tokens} · '
                      '수련 포인트 ${p.trainingPoints.toStringAsFixed(1)} · '
                      '진기 ${p.staminaNow(DateTime.now().millisecondsSinceEpoch).floor()}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _MenuButton(
              icon: Icons.landscape,
              label: '강호행',
              help: '줄거리 6장 · 숙적 묵현',
              onTap: () => _open(const CampaignScreen()),
              primary: true,
            ),
            _MenuButton(
              icon: Icons.sports_martial_arts,
              label: '목인항',
              help: '하루 처음 30타는 내공 3배',
              onTap: () => _open(const TrainingScreen()),
            ),
            _MenuButton(
              icon: Icons.extension,
              label: '목인항 묘수풀이',
              help: '정해진 수로 표적 모두 떨어뜨리기',
              onTap: () => _open(const PuzzleScreen()),
            ),
            _MenuButton(
              icon: Icons.emoji_events,
              label: '투기장',
              help: 'AI 연승전 · 진기 10',
              onTap: () => _open(const ArenaScreen()),
            ),
            _MenuButton(
              icon: Icons.map,
              label: '강호유랑',
              help: '매주 바뀌는 지도 · 기연 찾기',
              onTap: () => _open(const WanderScreen()),
            ),
            if (p.legendaryOpen(DateTime.now().millisecondsSinceEpoch))
              _MenuButton(
                icon: Icons.auto_awesome,
                label: '기인방 (열림!)',
                help: '10분 동안만 — 전설 상점',
                onTap: () => _open(const LegendaryShopScreen()),
                primary: true,
              ),
            _MenuButton(
              icon: Icons.storefront,
              label: '만물상',
              help: '엽전으로 재질·모양 사기',
              onTap: () => _open(const ShopScreen()),
            ),
            _MenuButton(
              icon: Icons.trending_up,
              label: '능력치 · 캐릭터 · 내 돌',
              help: '수련 포인트로 성장',
              onTap: () => _open(const StatsScreen()),
            ),
            _MenuButton(
              icon: Icons.menu_book,
              label: '도감',
              help: '모은 것 · 세트 보너스',
              onTap: () => _open(const CodexScreen()),
            ),
            _MenuButton(
              icon: Icons.flag,
              label: '무림맹 보급소',
              help: '주말·1,000타·6장 격파 때 · 징표',
              onTap: () => _open(const DepotScreen()),
            ),
            _MenuButton(
              icon: Icons.percent,
              label: '확률 안내',
              help: '기연·기인방·흥정 확률',
              onTap: () => _open(const OddsScreen()),
            ),
            _MenuButton(
              icon: Icons.sports_esports,
              label: '자유 대전',
              help: '혼자·둘이·연습 (보상 없음)',
              onTap: () => _open(const FreePlayScreen()),
            ),
            if (p.canRebirth || p.rebirths > 0)
              _MenuButton(
                icon: Icons.autorenew,
                label: p.canRebirth ? '비승 · 환생 (열림!)' : '비승 · 윤회천기',
                help: '환골탈태 · 천년내단 ${p.danCores}',
                onTap: () => _open(const RebirthScreen()),
                primary: p.canRebirth,
              ),
            _MenuButton(
              icon: Icons.settings,
              label: '설정',
              help: '소리·진동·손맛 보정·왼손잡이',
              onTap: () => _open(const SettingsScreen()),
            ),
            const SizedBox(height: 16),
            Text(
              versionLabel,
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(
                color: t.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.help,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final String help;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 18)),
                Text(help, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: primary
          ? FilledButton(onPressed: onTap, child: child)
          : FilledButton.tonal(onPressed: onTap, child: child),
    );
  }
}

/// 시험판 자동 업데이트 알림 줄. 할 일이 없으면 보이지 않는다.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.updater});
  final Updater updater;

  @override
  Widget build(BuildContext context) {
    final u = updater;
    final build = u.target?.build;
    final (String text, Widget? action) = switch (u.stage) {
      UpdateStage.idle || UpdateStage.checking => ('', null),
      UpdateStage.needsPermission => (
        '새 판(빌드 $build)이 있습니다. 처음 한 번만 「이 출처 허용」을 켜 주세요. '
            '그다음부터는 저절로 업데이트됩니다.',
        FilledButton(onPressed: u.openPermission, child: const Text('허용하러 가기')),
      ),
      UpdateStage.downloading => ('새 판(빌드 $build) 받는 중 ${u.percent}%', null),
      UpdateStage.installing => (
        '새 판(빌드 $build) 설치 중 — 끝나면 앱이 닫힙니다. 다시 열어 주세요.',
        null,
      ),
      UpdateStage.failed => (
        '업데이트하지 못했습니다: ${u.message}',
        TextButton(onPressed: u.run, child: const Text('다시 시도')),
      ),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
              if (u.stage == UpdateStage.downloading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: u.percent / 100),
              ],
              if (action != null) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
