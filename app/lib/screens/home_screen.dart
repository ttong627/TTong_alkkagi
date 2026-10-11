import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../e2e.dart';
import '../progress/daily.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import '../story/campaign.dart';
import '../story/chapters.dart';
import '../ui/art.dart';
import '../ui/ghost_hand.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../update/updater.dart';
import '../version.dart';
import 'arena_screen.dart';
import 'campaign_screen.dart';
import 'codex_screen.dart';
import 'credits_screen.dart';
import 'daily_screen.dart';
import 'depot_screen.dart';
import 'free_play_screen.dart';
import 'hero_pick_screen.dart';
import 'legendary_shop_screen.dart';
import 'look_screen.dart';
import 'odds_screen.dart';
import 'puzzle_screen.dart';
import 'rebirth_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'stats_screen.dart';
import 'training_screen.dart';
import 'tutorial_screen.dart';
import 'wander_screen.dart';

/// 로비(첫 화면, 설계서 §16.11): 내 캐릭터가 서 있고, 위에 재화, 아래에 큰 출전 단추와 그림 메뉴.
/// 글을 읽지 않아도 그림으로 고른다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _updater = Updater();
  final _store = ProfileStore.instance;
  final _heroStrike = ValueNotifier<int>(0);
  final _goKey = GlobalKey();
  final _rand = math.Random();

  /// 로비 길 안내(입문 끝난 직후 한 번): 「강호행」만 눌리게 둘레를 어둡게.
  bool _tour = false;
  String? _heroLine;

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _firstRun());
      Sound.lobby();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onUpdate);
    _heroStrike.dispose();
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

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(gameRoute<void>(screen));
    if (mounted) {
      Sound.lobby();
      setState(() {});
    }
  }

  /// 처음 켰으면: 입문(강제) → 캐릭터 고르기 → 로비 길 안내. 그다음부터는 출석 보상부터.
  Future<void> _firstRun() async {
    final p = _store.profile;
    if (!p.tutorialDone) {
      await Navigator.of(context).push(gameRoute<void>(const TutorialScreen()));
      if (!mounted) return;
      setState(() => _tour = true);
      Sound.lobby();
      return;
    }
    if (p.hero == null) {
      await Navigator.of(context).push(gameRoute<void>(const HeroPickScreen()));
      if (!mounted) return;
    }
    if (Attendance.canClaim(p, today()) && mounted) {
      await _open(const DailyScreen(tab: 0));
    }
  }

  void _tapHero() {
    final p = _store.profile;
    final lines = [
      '오늘도 한 판 해 볼까!',
      '손끝에 기를 모은다…',
      '강호가 나를 부른다!',
      if (p.hero != null) p.hero!.trait.split(' · ').first,
    ];
    Sound.play('whoosh', 0.8);
    setState(() => _heroLine = lines[_rand.nextInt(lines.length)]);
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _heroLine = null);
    });
  }

  void _goCampaign() {
    if (_tour) setState(() => _tour = false);
    _open(const CampaignScreen());
  }

  /// 다음에 깰 강호행 판 이름(다 깼으면 null).
  String? get _nextStage {
    final p = _store.profile;
    for (var i = 0; i < campaign.length; i++) {
      if (!p.done.contains(campaign[i].id)) {
        return Campaign.lockReason(p, i) == null ? campaign[i].title : null;
      }
    }
    return null;
  }

  void _more() {
    final p = _store.profile;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(12),
        child: GlassPanel(
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 14,
            runSpacing: 14,
            children: [
              IconTile(
                icon: 'free',
                label: '자유 대전',
                onTap: () => _sheetGo(c, const FreePlayScreen()),
              ),
              IconTile(
                icon: 'puzzle',
                label: '묘수풀이',
                onTap: () => _sheetGo(c, const PuzzleScreen()),
              ),
              IconTile(
                icon: 'depot',
                label: '보급소',
                onTap: () => _sheetGo(c, const DepotScreen()),
              ),
              IconTile(
                icon: 'look',
                label: '꾸미기',
                onTap: () => _sheetGo(c, const LookScreen()),
              ),
              if (p.canRebirth || p.rebirths > 0)
                IconTile(
                  icon: 'rebirth',
                  label: '환생',
                  badge: p.canRebirth,
                  onTap: () => _sheetGo(c, const RebirthScreen()),
                ),
              IconTile(
                icon: 'odds',
                label: '확률',
                onTap: () => _sheetGo(c, const OddsScreen()),
              ),
              IconTile(
                icon: 'settings',
                label: '설정',
                onTap: () => _sheetGo(c, const SettingsScreen()),
              ),
              IconTile(
                icon: 'mail',
                label: '만든 이',
                onTap: () => _sheetGo(c, const CreditsScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sheetGo(BuildContext sheet, Widget screen) {
    Navigator.pop(sheet);
    _open(screen);
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final now = DateTime.now().millisecondsSinceEpoch;
    final day = today();
    final next = _nextStage;
    final heroId = p.hero?.name ?? 'seokdu';
    final stageFrac = p.toNextStage == null
        ? 1.0
        : (1 -
                  p.toNextStage! /
                      math.max(
                        1,
                        naegongStages[p.stage].$2 -
                            naegongStages[p.stage - 1].$2,
                      ))
              .clamp(0.0, 1.0);
    return Scaffold(
      body: SceneBackground(
        asset: Art.background('lobby'),
        motes: Motes.petals,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  UpdateBanner(updater: _updater),
                  // ── 위: 내 얼굴·내공 · 재화.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          key: const Key('home-avatar'),
                          onTap: () => _open(const StatsScreen()),
                          child: _ProfileChip(
                            heroId: heroId,
                            name: p.hero?.label ?? '초행자',
                            stage: '${p.stageName} ${p.stage}단',
                            frac: stageFrac,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _open(const SettingsScreen()),
                          child: Image.asset(Art.icon('settings'), width: 40),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CurrencyPill(
                          icon: 'coin',
                          value: p.coins,
                          onTap: () => _open(const ShopScreen()),
                        ),
                        const SizedBox(width: 6),
                        CurrencyPill(
                          icon: 'silver',
                          value: p.silver,
                          onTap: () => _open(const LookScreen()),
                        ),
                        const SizedBox(width: 6),
                        CurrencyPill(
                          icon: 'stamina',
                          value: p.staminaNow(now).floor(),
                        ),
                      ],
                    ),
                  ),
                  // ── 가운데: 캐릭터와 양옆 메뉴.
                  Expanded(
                    child: Stack(
                      children: [
                        Align(
                          alignment: const Alignment(0, 0.5),
                          child: CharacterSprite(
                            key: const Key('lobby-hero'),
                            id: heroId,
                            height: math.min(
                              330,
                              MediaQuery.sizeOf(context).height * 0.36,
                            ),
                            attack: _heroStrike,
                            onTap: _tapHero,
                          ),
                        ),
                        if (_heroLine != null)
                          Align(
                            alignment: const Alignment(0, -0.75),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Palette.paper,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF2A1A12),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                _heroLine!,
                                style: const TextStyle(
                                  fontFamily: bodyFont,
                                  fontSize: 18,
                                  color: Color(0xFF2A1A12),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 8,
                          top: 12,
                          child: Column(
                            children: [
                              IconTile(
                                key: const Key('menu-attendance'),
                                icon: 'attendance',
                                label: '출석',
                                size: 46,
                                badge: Attendance.canClaim(p, day),
                                onTap: () => _open(const DailyScreen(tab: 0)),
                              ),
                              const SizedBox(height: 10),
                              IconTile(
                                key: const Key('menu-missions'),
                                icon: 'mission',
                                label: '임무',
                                size: 46,
                                badge: Missions.hasClaimable(p, day),
                                onTap: () => _open(const DailyScreen(tab: 1)),
                              ),
                              const SizedBox(height: 10),
                              IconTile(
                                icon: 'medal',
                                label: '업적',
                                size: 46,
                                badge: Achievements.hasClaimable(p),
                                onTap: () => _open(const DailyScreen(tab: 2)),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 12,
                          child: Column(
                            children: [
                              IconTile(
                                icon: 'shop',
                                label: '만물상',
                                size: 46,
                                onTap: () => _open(const ShopScreen()),
                              ),
                              const SizedBox(height: 10),
                              if (p.legendaryOpen(now)) ...[
                                IconTile(
                                  icon: 'legend',
                                  label: '기인방!',
                                  size: 46,
                                  badge: true,
                                  onTap: () =>
                                      _open(const LegendaryShopScreen()),
                                ),
                                const SizedBox(height: 10),
                              ],
                              IconTile(
                                icon: 'codex',
                                label: '도감',
                                size: 46,
                                onTap: () => _open(const CodexScreen()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── 아래: 큰 출전 단추 · 그림 메뉴.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Column(
                      children: [
                        GameButton(
                          key: _goKey,
                          label: '강호행',
                          icon: 'campaign',
                          height: 74,
                          fontSize: 32,
                          color: Palette.red,
                          sound: 'ui_open',
                          onTap: _goCampaign,
                        ),
                        if (next != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: OutlinedText(
                              '다음: $next',
                              size: 15,
                              color: Palette.gold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconTile(
                          icon: 'training',
                          label: '목인항',
                          size: 50,
                          badge: p.trainingDay != day,
                          onTap: () => _open(const TrainingScreen()),
                        ),
                        IconTile(
                          icon: 'arena',
                          label: '투기장',
                          size: 50,
                          onTap: () => _open(const ArenaScreen()),
                        ),
                        IconTile(
                          icon: 'wander',
                          label: '유랑',
                          size: 50,
                          onTap: () => _open(const WanderScreen()),
                        ),
                        IconTile(
                          icon: 'stats',
                          label: '성장',
                          size: 50,
                          badge: Stat.values.any(p.canRaise),
                          onTap: () => _open(const StatsScreen()),
                        ),
                        IconTile(
                          icon: 'chest',
                          label: '더보기',
                          size: 50,
                          onTap: _more,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    versionLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
            if (_tour) _Spotlight(targetKey: _goKey, onTap: _goCampaign),
          ],
        ),
      ),
    );
  }
}

/// 위 왼쪽 내 얼굴 · 이름 · 내공 경지 막대.
class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.heroId,
    required this.name,
    required this.stage,
    required this.frac,
  });
  final String heroId;
  final String name;
  final String stage;
  final double frac;

  @override
  Widget build(BuildContext context) {
    final w = 54.0;
    final iw = w * 1.8, ih = iw * 520 / 440;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: Palette.gold.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: w,
            height: w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Palette.gold, width: 2.5),
              gradient: const RadialGradient(
                colors: [Color(0xFF5A4636), Color(0xFF241A14)],
              ),
            ),
            child: ClipOval(
              child: Stack(
                children: [
                  Positioned(
                    left: w / 2 - iw / 2,
                    top: w / 2 - ih * 0.337,
                    width: iw,
                    height: ih,
                    child: Image.asset(Art.character(heroId), fit: BoxFit.fill),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedText(name, size: 18, title: true),
              const SizedBox(height: 3),
              Row(
                children: [
                  Image.asset(Art.icon('naegong'), width: 18),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 84,
                    height: 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: frac,
                        backgroundColor: Colors.white12,
                        color: Palette.gold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                stage,
                style: const TextStyle(fontSize: 12, color: Palette.dim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 길 안내: 대상 단추 둘레만 밝게 두고 나머지는 어둡게. 단추를 눌러야 지나간다.
class _Spotlight extends StatefulWidget {
  const _Spotlight({required this.targetKey, required this.onTap});
  final GlobalKey targetKey;
  final VoidCallback onTap;

  @override
  State<_Spotlight> createState() => _SpotlightState();
}

class _SpotlightState extends State<_Spotlight> {
  Rect? _rect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = widget.targetKey.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (box is RenderBox && me is RenderBox && box.attached) {
      final tl = box.localToGlobal(Offset.zero, ancestor: me);
      setState(() => _rect = tl & box.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _rect;
    return Positioned.fill(
      child: GestureDetector(
        key: const Key('spotlight'),
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          if (r != null && r.inflate(8).contains(d.localPosition)) {
            widget.onTap();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _HolePainter(r))),
            if (r != null) ...[
              Positioned.fill(
                child: Ghost(
                  builder: (t) => GhostTapPainter(
                    at: r.center + const Offset(40, 0),
                    t: t,
                    size: 80,
                    ring: 44,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: r.top - 70,
                child: const Center(
                  child: OutlinedText(
                    '여기를 눌러 강호로!',
                    size: 24,
                    title: true,
                    color: Palette.gold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  _HolePainter(this.hole);
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final h = hole;
    final path = h == null
        ? all
        : Path.combine(
            PathOperation.difference,
            all,
            Path()..addRRect(
              RRect.fromRectAndRadius(h.inflate(10), const Radius.circular(28)),
            ),
          );
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
    if (h != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(h.inflate(10), const Radius.circular(28)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Palette.gold,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HolePainter old) => old.hole != hole;
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
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
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
