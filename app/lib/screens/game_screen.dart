import 'dart:async';
import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart' as phys;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../e2e.dart';
import '../game/arena.dart';
import '../game/ai.dart';
import '../game/board_game.dart';
import '../game/flick.dart';
import '../game/fx_colors.dart';
import '../game/match.dart';
import '../progress/daily.dart';
import '../progress/profile.dart';
import '../progress/settings.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/ghost_hand.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'flick_view.dart';

/// 한 판 화면: 위에 두 사람 얼굴·남은 돌, 가운데 대전장, 아래 내공 구슬.
/// 내 돌을 누르면 그 돌을 가까이 보는 화면으로 바뀌고, 거기서 손끝으로 튕긴다.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.config,
    this.title,
    this.onTurnEnd,
    this.info,
    this.quips = const [],
    this.boss = false,
    this.coach = false,
    this.stageId,
    this.coachLines = const [],
  });

  /// 고수전(강호행·폐관수련동)이면 이길 때 절명기 연출(설계서 §4).
  final bool boss;

  /// 고수 한마디 6줄(설계서 §16.7 · [Stage.quips] 와 같은 순서).
  final List<String> quips;
  final MatchConfig config;

  /// 한 수가 끝날 때마다(목인항 등).
  final void Function(Match match)? onTurnEnd;

  /// 판 아래 안내 글(목인항 수련 수 등). 없으면 대전장 이름.
  final String Function()? info;

  /// 강호행 판이면 제목(예: 「1장 · 하산의 길」). 이때는 판이 끝나면 이겼는지(bool)를 돌려주고 닫는다.
  final String? title;

  /// 입문(설계서 §16.10): 시범 손가락을 띄우고, 지면 저절로 다시, 나가기 없음.
  final bool coach;

  /// 사부 한마디(입문 판 시작 때 띄움).
  final List<String> coachLines;

  /// 별을 남길 판 이름(강호행 판 id 등). null 이면 별은 보이기만 하고 남기지 않는다.
  final String? stageId;

  /// 마지막으로 끝난 판의 별(부른 화면이 보상과 함께 쓴다).
  static int lastStars = 0;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Match _match;
  late BoardGame _game;
  phys.Stone? _selected;
  bool _aiThinking = false;
  bool _resultShown = false;
  final _rand = math.Random();
  int _myStart = 0;

  /// 지금 말풍선에 띄운 한마디와 말한 사람 그림.
  String? _quip;
  String? _quipBy;
  Timer? _quipTimer;

  /// 절명기 연출 중이면 그 이름(설계서 §4: 보스의 마지막 돌 장외).
  String? _finisher;

  /// 내공 겨루기 연타 화면이 떠 있나.
  bool _clashing = false;

  /// 판 시작 「나 VS 상대」 연출.
  bool _intro = true;

  /// 일시정지 창.
  bool _paused = false;

  /// 판 끝 결과 창.
  _Result? _result;

  /// 내 얼굴이 공격 동작을 할 때마다 늘린다.
  final _myStrike = ValueNotifier<int>(0);
  final _foeStrike = ValueNotifier<int>(0);

  final _store = ProfileStore.instance;

  String get _myId => _store.profile.hero?.name ?? 'seokdu';
  String? get _foeId => widget.coach
      ? 'sabu'
      : (Art.bossId(widget.config.opponentName) ??
            (widget.config.mode == MatchMode.vsAi ? _aiFace : null));

  /// 이름 없는 AI 상대는 난이도마다 얼굴.
  String get _aiFace => switch (widget.config.difficulty) {
    Difficulty.easy => 'banDal',
    Difficulty.normal => 'jagaek',
    Difficulty.hard => 'mukgaek',
  };

  /// [first] 와 그다음 줄 가운데 하나를 2.6초 띄운다.
  void _say(int first) {
    if (widget.quips.length < first + 2) return;
    _show(widget.quips[first + _rand.nextInt(2)], _foeId);
  }

  void _show(String line, String? by, [int ms = 2600]) {
    _quipTimer?.cancel();
    setState(() {
      _quip = line;
      _quipBy = by;
    });
    _quipTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _quip = null);
    });
  }

  bool get _aiTurn => widget.config.mode == MatchMode.vsAi && _match.turn == 1;

  bool get _showIntro =>
      !widget.coach && !widget.config.training && e2eDemoMode.isEmpty && !e2eFlick;

  @override
  void initState() {
    super.initState();
    // 숙적(묵현)·폐관 고수와는 긴박한 고수전 곡, 나머지는 대전장 곡.
    final rival = widget.config.opponentName == '묵현' ||
        (widget.config.opponentName?.startsWith('폐관') ?? false);
    if (rival) {
      Sound.track('bgm_boss');
    } else {
      Sound.music(widget.config.arena);
    }
    _newMatch();
    _intro = _showIntro;
    if (_intro) {
      Sound.play('go');
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _intro = false);
      });
    }
    if (widget.coach && widget.coachLines.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _show(widget.coachLines.first, 'sabu', 3600),
      );
    }
    if (e2eDemoMode.isNotEmpty) {
      Future<void>.delayed(const Duration(milliseconds: 1500), _demoShot);
    }
  }

  /// 연출 확인용(E2E_DEMO): 가운데 내 돌을 위로 세게 친다.
  void _demoShot() {
    if (!mounted) return;
    final s = _e2eStone();
    if (s == null) return;
    final mode = StrikeMode.values.firstWhere(
      (m) => m.name == e2eDemoMode,
      orElse: () => StrikeMode.plain,
    );
    // ignore: invalid_use_of_visible_for_testing_member
    _match.grantQi(0, maxQi);
    setState(() => _selected = null);
    _match.shoot(
      s,
      -math.pi / 2,
      110,
      0,
      lift: true,
      mode: mode,
      critical: mode == StrikeMode.plain,
      curl: 1,
    );
  }

  void _newMatch() {
    _match = Match(widget.config)..addListener(_onMatch);
    _game = BoardGame(
      _match,
      canTouch: () => !_aiTurn && !_aiThinking && !_paused && _result == null,
      onSelect: (s) => setState(() => _selected = s),
      selected: () => _selected,
    );
    _selected = null;
    _resultShown = false;
    _result = null;
    _myStart = _match.alive(0);
    if (e2eFlick && e2eDemoMode.isEmpty) _selected = _e2eStone();
  }

  /// 시험 판: 판 가운데에 가장 가까운 내 돌을 고른다.
  phys.Stone? _e2eStone() {
    phys.Stone? best;
    for (final s in _match.table.stones) {
      if (!_match.canShoot(s)) continue;
      if (best == null || s.position.length < best.position.length) best = s;
    }
    return best;
  }

  void _restart() {
    setState(() {
      _paused = false;
      _match
        ..removeListener(_onMatch)
        ..dispose();
      _newMatch();
    });
  }

  bool _wasMoving = false;

  /// 이번 판에서 센 일(임무·업적, 설계서 §16.9).
  void _record(Deed d, [int n = 1]) {
    if (widget.config.training && d != Deed.knock) return;
    Missions.record(_store.profile, d, today(), n);
  }

  void _onMatch() {
    if (!mounted) return;
    setState(() {});
    if (_match.clash != null && !_clashing) {
      _clashing = true;
      Sound.play('clash');
      _selected = null;
    }
    if (_wasMoving && !_match.isMoving) {
      widget.onTurnEnd?.call(_match);
      if (_match.lastShooter == 0 && _match.lastKnocked > 0) {
        _record(Deed.knock, _match.lastKnocked);
      }
      if (_match.lastKnocked >= 2) _say(_match.lastShooter == 0 ? 2 : 4);
      if (widget.coach && _match.lastShooter == 0 && _match.lastKnocked > 0) {
        _show(_match.lastKnocked >= 2 ? '일타쌍피! 훌륭하다!' : '좋다! 바로 그거다!', 'sabu', 1600);
      }
    }
    _wasMoving = _match.isMoving;
    if (_match.isOver && !_match.isMoving && !_resultShown) {
      _resultShown = true;
      final boss =
          widget.boss &&
          widget.config.mode == MatchMode.vsAi &&
          _match.winner == 0 &&
          !_match.isDraw;
      if (boss) {
        Sound.play('finisher');
        setState(() => _finisher = finisherName(widget.config.martial));
        Future<void>.delayed(const Duration(milliseconds: 1900), () {
          if (mounted) setState(() => _finisher = null);
          _showResult();
        });
      } else {
        Future<void>.delayed(const Duration(milliseconds: 500), _showResult);
      }
      return;
    }
    if (e2eFlick &&
        e2eDemoMode.isEmpty &&
        !_match.isMoving &&
        _selected == null &&
        !_match.isOver) {
      setState(() => _selected = _e2eStone());
    }
    if (_aiTurn && !_match.isMoving && !_aiThinking && !_match.isOver && !_intro) {
      unawaited(_playAi());
    }
  }

  void _shoot(FlickShot shot, StrikeMode mode) {
    final s = _selected;
    setState(() => _selected = null);
    if (s == null) return;
    _myStrike.value++;
    _match.shoot(
      s,
      shot.angle,
      shot.speed * widget.config.powerScale,
      shot.hit,
      lift: true,
      mode: mode,
      // 정각: 회심 가운데 폭이 넓다.
      critical:
          shot.critical ||
          (widget.config.critWidth > CriticalRule.maxOffset &&
              shot.offset <= widget.config.critWidth &&
              shot.power >= CriticalRule.minPower &&
              shot.power <= CriticalRule.maxPower),
      curl: shot.curl,
    );
    if (_match.lastCritical) {
      _record(Deed.critical);
      _say(0);
    }
    if (_match.lastMode != StrikeMode.plain) _record(Deed.inner);
  }

  /// 고른 돌이 판 어디 있는지에 맞춰 가까이 보기 화면이 그 자리에서 커져 나온다.
  Alignment get _zoomFrom {
    final s = _selected;
    if (s == null) return Alignment.center;
    const h = phys.PhysicsConstants.halfBoard;
    return Alignment(s.position.x / h * 0.85, s.position.y / h * 0.6);
  }

  /// 시범 손가락이 튕길 쪽: 고른 돌에서 가장 가까운 상대 돌(없으면 위).
  double get _demoAngle {
    final s = _selected;
    if (s == null) return -math.pi / 2;
    phys.Stone? best;
    for (final o in _match.table.stones) {
      if (o.out || o.team == s.team) continue;
      if (best == null ||
          (o.position - s.position).length < (best.position - s.position).length) {
        best = o;
      }
    }
    if (best == null) return -math.pi / 2;
    final d = best.position - s.position;
    return math.atan2(d.y, d.x);
  }

  Future<void> _playAi() async {
    setState(() => _aiThinking = true);
    final started = DateTime.now();
    final shot = await chooseAiShot(_match);
    final waited = DateTime.now().difference(started);
    if (waited < const Duration(milliseconds: 700)) {
      await Future<void>.delayed(const Duration(milliseconds: 700) - waited);
    }
    if (!mounted) return;
    setState(() => _aiThinking = false);
    _foeStrike.value++;
    _match.shoot(
      _match.table.stones[shot.stoneId],
      shot.angle,
      shot.speed,
      shot.hit,
      mode: shot.mode,
    );
  }

  Future<void> _showResult() async {
    if (!mounted) return;
    final won = _match.winner == 0 && !_match.isDraw;
    final p = _store.profile;
    if (!widget.config.training) {
      _record(Deed.play);
      if (won && widget.config.mode == MatchMode.vsAi) _record(Deed.win);
    }
    final stars = widget.config.mode == MatchMode.twoPlayer
        ? 0
        : starsFor(won: won, myLeft: _match.alive(0), myStart: _myStart);
    GameScreen.lastStars = stars;
    if (widget.stageId != null) recordStars(p, widget.stageId!, stars);
    unawaited(_store.save());
    // 입문: 지면 사부가 한마디 하고 저절로 다시(강제 수련).
    if (widget.coach && !won) {
      _show('괜찮다. 다시 해 보거라.', 'sabu', 1800);
      Sound.play('error');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) _restart();
      return;
    }
    final String title;
    if (_match.isDraw) {
      title = '비김';
    } else if (widget.config.mode == MatchMode.twoPlayer) {
      title = _match.winner == 0 ? '흰 돌 승리' : '검은 돌 승리';
    } else if (widget.config.mode == MatchMode.practice && widget.title == null && !widget.coach) {
      title = '연습 끝';
    } else {
      title = won ? '승리!' : '패배';
    }
    Sound.play(won ? 'jingle_win' : 'jingle_lose');
    setState(() => _result = _Result(title, won, stars, _match.bonusCoins));
  }

  void _leave() {
    if (widget.title != null || widget.coach) {
      Navigator.of(context).pop(_match.winner == 0 && !_match.isDraw);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _quipTimer?.cancel();
    _myStrike.dispose();
    _foeStrike.dispose();
    Sound.slide(0);
    Sound.lobby();
    _match
      ..removeListener(_onMatch)
      ..dispose();
    super.dispose();
  }

  String get _status {
    if (_match.isOver) return '판이 끝났습니다';
    if (_match.isMoving && _match.steersLeft > 0) {
      return '어기어석! 판을 끌어 돌을 꺾으세요';
    }
    if (_match.isMoving) return '';
    switch (widget.config.mode) {
      case MatchMode.practice:
        return '내 돌을 누르세요';
      case MatchMode.vsAi:
        return _match.turn == 0
            ? '내 차례 · 돌을 누르세요'
            : (_aiThinking ? '상대가 수를 읽는 중…' : '상대 차례');
      case MatchMode.twoPlayer:
        return _match.turn == 0 ? '흰 돌 차례' : '검은 돌 차례';
    }
  }

  /// 입문: 아직 돌을 안 골랐으면 눌러야 할 내 돌 위에 톡톡 손.
  phys.Stone? get _tapHint {
    if (!widget.coach || _selected != null || _match.isMoving || _match.isOver) return null;
    for (final s in _match.table.stones) {
      if (_match.canShoot(s)) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final vsAi = widget.config.mode == MatchMode.vsAi;
    final foeName =
        widget.config.opponentName ??
        (widget.coach ? '사부' : (vsAi ? '상대' : (widget.config.mode == MatchMode.twoPlayer ? '검은 돌' : '표적')));
    final hint = _tapHint;
    return PopScope(
      canPop: !widget.coach,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !widget.coach) setState(() => _paused = true);
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: SceneBackground(
                asset: Art.arenaBackground(widget.config.arena),
                dim: 0.55,
                motes: switch (widget.config.arena) {
                  Arena.kubiForest => Motes.fireflies,
                  Arena.murimIce => Motes.snow,
                  Arena.oilyTable => Motes.embers,
                  _ => Motes.none,
                },
                child: const SizedBox.shrink(),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // ── 위: 일시정지 · 상대 · 나.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                    child: Row(
                      children: [
                        if (!widget.coach)
                          _RoundIcon(
                            key: const Key('pause'),
                            icon: Icons.pause_rounded,
                            onTap: () => setState(() => _paused = true),
                          ),
                        Expanded(
                          child: _Fighter(
                            id: _foeId,
                            name: foeName,
                            left: _match.alive(1),
                            dark: true,
                            active: _match.turn == 1 && !_match.isOver,
                            strike: _foeStrike,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _Fighter(
                            id: _myId,
                            name: vsAi || widget.config.opponentName != null || widget.coach ? '나' : '흰 돌',
                            left: _match.alive(0),
                            dark: false,
                            active: _match.turn == 0 && !_match.isOver,
                            strike: _myStrike,
                            mirror: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.title != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: OutlinedText(widget.title!, size: 16, color: Palette.gold),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: GameWidget(game: _game)),
                        if (hint != null)
                          Positioned.fill(
                            child: Ghost(
                              builder: (tt) => GhostTapPainter(
                                at: _game.screenOf(hint.position.x, hint.position.y),
                                t: tt,
                                size: 70,
                                ring: _game.stoneRadiusPx * 1.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // ── 아래: 내 내공 구슬 · 차례 · 안내.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < maxQi; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: _QiOrb(full: i < _match.qi(0)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_status.isNotEmpty)
                          OutlinedText(_status, size: 20, title: true),
                        const SizedBox(height: 2),
                        Text(
                          widget.info?.call() ??
                              '${widget.config.arena.chapter} · ${widget.config.arena.label}',
                          style: t.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.25, end: 1.0).animate(anim),
                    alignment: _zoomFrom,
                    child: child,
                  ),
                ),
                child: _selected == null
                    ? const SizedBox.shrink()
                    : FlickView(
                        key: ValueKey(_selected),
                        match: _match,
                        stone: _selected!,
                        onShot: _shoot,
                        onCancel: () => setState(() => _selected = null),
                        demo: widget.coach || _store.profile.lifetime[Deed.play] == null,
                        demoAngle: _demoAngle,
                      ),
              ),
            ),
            if (_quip != null && (_selected == null || widget.coach))
              Positioned(
                top: MediaQuery.paddingOf(context).top + 70,
                left: 12,
                right: 12,
                child: IgnorePointer(
                  child: _SpeechBubble(
                    key: const Key('boss-quip'),
                    by: _quipBy,
                    name: _quipBy == 'sabu' ? '사부' : foeName,
                    text: _quip!,
                  ),
                ),
              ),
            if (_clashing)
              Positioned.fill(
                child: QiClashOverlay(
                  opponent: widget.config.opponentName ?? '상대',
                  aiTaps: QiClash.aiTaps(widget.config.difficulty, _rand),
                  onDone: (mine, theirs) {
                    _match.resolveClash(mine, theirs);
                    setState(() => _clashing = false);
                  },
                ),
              ),
            if (_finisher != null)
              Positioned.fill(child: FinisherOverlay(name: _finisher!)),
            if (_intro)
              Positioned.fill(
                child: VersusIntro(
                  me: _myId,
                  foe: _foeId,
                  foeName: foeName,
                  title: widget.title ?? widget.config.arena.label,
                ),
              ),
            if (_paused)
              Positioned.fill(
                child: _PauseMenu(
                  onResume: () => setState(() => _paused = false),
                  onRestart: _restart,
                  onQuit: () {
                    setState(() => _paused = false);
                    if (widget.title != null) {
                      Navigator.of(context).pop(false);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            if (_result case final r?)
              Positioned.fill(
                child: ResultOverlay(
                  title: r.title,
                  won: r.won,
                  stars: r.stars,
                  coins: r.coins,
                  character: r.won ? _myId : _foeId,
                  onAgain: widget.title == null && !widget.coach ? _restart : null,
                  onDone: _leave,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Result {
  _Result(this.title, this.won, this.stars, this.coins);
  final String title;
  final bool won;
  final int stars;
  final int coins;
}

/// 둥근 아이콘 단추(일시정지 등).
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      Sound.play('ui_tap', 0.7);
      onTap();
    },
    child: Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black54,
        border: Border.all(color: Palette.gold.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Icon(icon, color: Palette.text),
    ),
  );
}

/// 위쪽 한 사람: 얼굴 · 이름 · 남은 돌. 차례면 금빛으로 빛난다. 공격하면 얼굴이 튀어나온다.
class _Fighter extends StatelessWidget {
  const _Fighter({
    required this.id,
    required this.name,
    required this.left,
    required this.dark,
    required this.active,
    required this.strike,
    this.mirror = false,
  });
  final String? id;
  final String name;
  final int left;
  final bool dark;
  final bool active;
  final ValueNotifier<int> strike;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final face = ValueListenableBuilder<int>(
      valueListenable: strike,
      builder: (_, n, _) => TweenAnimationBuilder<double>(
        key: ValueKey(n),
        tween: Tween(begin: n == 0 ? 0 : 1, end: 0),
        duration: const Duration(milliseconds: 600),
        builder: (_, k, _) => Transform.scale(
          scale: 1 + 0.25 * k,
          child: Portrait(
            id: id,
            size: 50,
            attack: k > 0.2,
            ring: active ? Palette.gold : Colors.white24,
          ),
        ),
      ),
    );
    final info = Column(
      crossAxisAlignment: mirror ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedText(name, size: 15, color: active ? Palette.gold : Colors.white),
        const SizedBox(height: 3),
        // 돌이 많으면 칸에 맞춰 작게.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < left; i++)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.4, -0.4),
                      colors: dark
                          ? const [Color(0xFF6A6A74), Color(0xFF15151A)]
                          : const [Colors.white, Color(0xFFC9C2B2)],
                    ),
                    border: Border.all(color: Colors.black54),
                  ),
                ),
              ),
          ],
          ),
        ),
      ],
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.black.withValues(alpha: active ? 0.55 : 0.35),
        border: Border.all(color: active ? Palette.gold : Colors.white12, width: active ? 2 : 1),
        boxShadow: active ? [BoxShadow(color: Palette.gold.withValues(alpha: 0.35), blurRadius: 12)] : null,
      ),
      child: Row(
        mainAxisAlignment: mirror ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: mirror
            ? [Flexible(child: info), const SizedBox(width: 6), face]
            : [face, const SizedBox(width: 6), Flexible(child: info)],
      ),
    );
  }
}

/// 내공 구슬 하나(차면 빛난다).
class _QiOrb extends StatelessWidget {
  const _QiOrb({required this.full});
  final bool full;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: full ? [Colors.white, innerColor] : const [Color(0xFF4A4050), Color(0xFF1E1822)],
      ),
      border: Border.all(color: full ? Colors.white : Colors.white24, width: 1.5),
      boxShadow: full ? [BoxShadow(color: innerColor.withValues(alpha: 0.8), blurRadius: 10)] : null,
    ),
  );
}

/// 말풍선: 얼굴 + 이름 + 한마디.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({super.key, required this.by, required this.name, required this.text});
  final String? by;
  final String name;
  final String text;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutBack,
    builder: (_, k, child) => Transform.scale(scale: 0.8 + 0.2 * k, child: Opacity(opacity: k.clamp(0, 1), child: child)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Portrait(id: by, size: 58),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: Palette.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2A1A12), width: 2.5),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(fontFamily: titleFont, fontSize: 14, color: Palette.redDeep)),
                Text(text, style: const TextStyle(fontFamily: bodyFont, fontSize: 19, color: Color(0xFF2A1A12))),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// 판 시작: 두 사람이 양쪽에서 미끄러져 들어오고 가운데 「VS」.
class VersusIntro extends StatefulWidget {
  const VersusIntro({super.key, required this.me, required this.foe, required this.foeName, required this.title});
  final String me;
  final String? foe;
  final String foeName;
  final String title;

  @override
  State<VersusIntro> createState() => _VersusIntroState();
}

class _VersusIntroState extends State<VersusIntro> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          final inK = Curves.easeOutBack.transform((v / 0.35).clamp(0, 1));
          final out = v > 0.82 ? (v - 0.82) / 0.18 : 0.0;
          final w = MediaQuery.sizeOf(context).width;
          return Opacity(
            opacity: 1 - out,
            child: Container(
              key: const Key('versus'),
              color: Colors.black.withValues(alpha: 0.65),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 90,
                    left: -w * 0.6 * (1 - inK),
                    child: CharacterSprite(id: widget.foe ?? 'jagaek', height: 230),
                  ),
                  Positioned(
                    bottom: 90,
                    right: -w * 0.6 * (1 - inK),
                    child: CharacterSprite(id: widget.me, height: 230, flip: true),
                  ),
                  Transform.scale(
                    scale: 0.5 + 0.5 * Curves.elasticOut.transform(((v - 0.2) / 0.5).clamp(0, 1)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const OutlinedText('VS', size: 76, title: true, color: Palette.gold),
                        OutlinedText(widget.title, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 일시정지: 계속 · 다시 · 소리 · 나가기.
class _PauseMenu extends StatefulWidget {
  const _PauseMenu({required this.onResume, required this.onRestart, required this.onQuit});
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  State<_PauseMenu> createState() => _PauseMenuState();
}

class _PauseMenuState extends State<_PauseMenu> {
  @override
  Widget build(BuildContext context) {
    final st = Settings.instance;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: SizedBox(
          width: 300,
          child: GlassPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OutlinedText('잠시 멈춤', size: 30, title: true, color: Palette.gold),
                const SizedBox(height: 16),
                GameButton(key: const Key('resume'), label: '계속', color: Palette.jade, onTap: widget.onResume),
                const SizedBox(height: 10),
                GameButton(label: '처음부터', color: Palette.sky, onTap: widget.onRestart),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.music_note, color: Palette.text),
                    Expanded(
                      child: Slider(
                        value: st.music,
                        onChanged: (v) => setState(() => st.music = v),
                        onChangeEnd: (_) => st.save(),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.volume_up, color: Palette.text),
                    Expanded(
                      child: Slider(
                        value: st.sfx,
                        onChanged: (v) => setState(() => st.sfx = v),
                        onChangeEnd: (_) => st.save(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                GameButton(label: '나가기', color: Palette.red, onTap: widget.onQuit, height: 52, fontSize: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 판 끝: 큰 제목 · 별이 하나씩 박힘 · 엽전 · 캐릭터.
class ResultOverlay extends StatefulWidget {
  const ResultOverlay({
    super.key,
    required this.title,
    required this.won,
    required this.stars,
    required this.coins,
    required this.character,
    required this.onDone,
    this.onAgain,
  });
  final String title;
  final bool won;
  final int stars;
  final int coins;
  final String? character;
  final VoidCallback onDone;
  final VoidCallback? onAgain;

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  final _attack = ValueNotifier<int>(0);
  int _rang = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      // 별이 박힐 때마다 딩.
      final due = ((_c.value - 0.35) / 0.15).floor() + 1;
      while (_rang < widget.stars && _rang < due) {
        _rang++;
        Sound.play('star');
        Buzz.tick();
      }
    });
    if (widget.won) Future<void>.delayed(const Duration(milliseconds: 300), () => _attack.value++);
  }

  @override
  void dispose() {
    _c.dispose();
    _attack.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final pop = Curves.elasticOut.transform((v / 0.4).clamp(0, 1));
        return Container(
          key: const Key('result'),
          color: Colors.black.withValues(alpha: 0.72 * (v / 0.2).clamp(0, 1)),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.character != null)
                    CharacterSprite(id: widget.character!, height: 200, attack: _attack),
                  Transform.scale(
                    scale: 0.4 + 0.6 * pop,
                    child: OutlinedText(
                      widget.title,
                      size: 54,
                      title: true,
                      color: widget.won ? Palette.gold : const Color(0xFFB0B8C8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.stars > 0 || widget.won)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Builder(
                            builder: (_) {
                              final k = ((v - 0.35 - i * 0.15) / 0.15).clamp(0.0, 1.0);
                              final on = i < widget.stars && k > 0;
                              return Transform.translate(
                                offset: Offset(0, i == 1 ? -12 : 0),
                                child: Transform.scale(
                                  scale: on ? 0.6 + 0.4 * Curves.easeOutBack.transform(k) * 1.0 : 0.85,
                                  child: Image.asset(
                                    Art.icon(on ? 'star' : 'star_empty'),
                                    width: i == 1 ? 74 : 60,
                                    key: Key(on ? 'star-on' : 'star-off'),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  if (widget.coins > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(Art.icon('coin'), width: 32),
                        const SizedBox(width: 6),
                        OutlinedText('+${widget.coins} 일타쌍피', size: 20, color: Palette.gold),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Opacity(
                    opacity: ((v - 0.6) / 0.3).clamp(0, 1),
                    child: SizedBox(
                      width: 300,
                      child: Row(
                        children: [
                          if (widget.onAgain != null) ...[
                            Expanded(
                              child: GameButton(label: '한 판 더', color: Palette.sky, onTap: widget.onAgain, fontSize: 20),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: GameButton(
                              key: const Key('result-done'),
                              label: widget.onAgain != null ? '나가기' : '계속',
                              color: widget.won ? Palette.red : Palette.jade,
                              onTap: v > 0.6 ? widget.onDone : null,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 절명기 이름(설계서 §4): 문파마다 결정타.
String finisherName(phys.Technique martial) => switch (martial) {
  phys.Technique.swordQi => '일도양단(一刀兩斷)',
  phys.Technique.stomp => '정권 찌르기',
  phys.Technique.taiji => '태극 회선(太極回旋)',
  phys.Technique.clone => '만천화우(滿天花雨)',
  _ => '탄지일격(彈指一擊)',
};

/// 절명기 컷: 화면이 어두워지고 빛줄기가 가르며 이름이 박힌다(판정과 무관).
class FinisherOverlay extends StatefulWidget {
  const FinisherOverlay({super.key, required this.name});
  final String name;

  @override
  State<FinisherOverlay> createState() => _FinisherOverlayState();
}

class _FinisherOverlayState extends State<FinisherOverlay>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final fade = t < 0.15 ? t / 0.15 : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
        return CustomPaint(
          key: const Key('finisher'),
          painter: _FinisherPainter(t, fade.clamp(0.0, 1.0), widget.name),
        );
      },
    ),
  );
}

class _FinisherPainter extends CustomPainter {
  _FinisherPainter(this.t, this.fade, this.name);
  final double t;
  final double fade;
  final String name;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.75 * fade),
    );
    // 대각선 빛줄기가 화면을 가른다.
    final cut = (t / 0.35).clamp(0.0, 1.0);
    final a = Offset(-size.width * 0.1, size.height * 0.75);
    final b = Offset(size.width * 1.1, size.height * 0.25);
    final end = Offset.lerp(a, b, Curves.easeOutCubic.transform(cut))!;
    canvas.drawLine(
      a,
      end,
      Paint()
        ..color = innerColor.withValues(alpha: fade)
        ..strokeWidth = 6 + 20 * (1 - cut)
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      a,
      end,
      Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..strokeWidth = 2,
    );
    if (t < 0.3) return;
    final grow = Curves.elasticOut.transform(((t - 0.3) / 0.4).clamp(0.0, 1.0));
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '절명기\n',
            style: TextStyle(
              fontFamily: bodyFont,
              fontFamilyFallback: fallbackFonts,
              fontSize: 20,
              color: Colors.white.withValues(alpha: fade),
              letterSpacing: 8,
            ),
          ),
          TextSpan(
            text: name,
            style: TextStyle(
              fontFamily: titleFont,
              fontFamilyFallback: fallbackFonts,
              fontSize: 40 * grow,
              color: innerColor.withValues(alpha: fade),
              shadows: const [Shadow(blurRadius: 16, color: Colors.black)],
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 32);
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _FinisherPainter old) => true;
}

/// 내공 겨루기(설계서 §4): 3초 동안 연타. 고수의 연타 수는 정해 두고 막대로 차오른다.
/// 초당 15회를 넘긴 연타는 무효(0회로 친다).
class QiClashOverlay extends StatefulWidget {
  const QiClashOverlay({
    super.key,
    required this.opponent,
    required this.aiTaps,
    required this.onDone,
  });
  final String opponent;
  final int aiTaps;
  final void Function(int mine, int theirs) onDone;

  @override
  State<QiClashOverlay> createState() => _QiClashOverlayState();
}

class _QiClashOverlayState extends State<QiClashOverlay>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (QiClash.seconds * 1000).round()),
  );
  int _taps = 0;
  String? _result;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((st) {
      if (st != AnimationStatus.completed) return;
      final d = QiClash.swing(_taps, widget.aiTaps);
      final cap = (QiClash.maxRate * QiClash.seconds).round();
      setState(() {
        _result = _taps > cap
            ? '무효 — 초당 ${QiClash.maxRate}회를 넘겼다'
            : (d > 0
                  ? '이겼다! 반발 +${(d * 100).round()}%'
                  : (d < 0 ? '밀렸다… 반발 ${(d * 100).round()}%' : '팽팽하다'));
      });
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) widget.onDone(_taps, widget.aiTaps);
      });
    });
    // 기기 진동·알림 없이도 시작을 알 수 있게 0.4초 뒤 시작.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cap = (QiClash.maxRate * QiClash.seconds).toDouble();
    return GestureDetector(
      key: const Key('qi-clash'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (_c.isAnimating) setState(() => _taps++);
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final ai = (widget.aiTaps * _c.value).round();
            Widget bar(String who, int n, Color c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 90, child: Text(who, style: t.titleMedium)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (n / cap).clamp(0.0, 1.0),
                      minHeight: 18,
                      color: c,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text('$n', textAlign: TextAlign.end),
                  ),
                ],
              ),
            );
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '내공 겨루기!',
                  style: t.displaySmall?.copyWith(
                    color: innerColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _result ??
                      (_c.isAnimating
                          ? '화면을 마구 두드려라! ${(QiClash.seconds * (1 - _c.value)).toStringAsFixed(1)}초'
                          : '준비…'),
                  style: t.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                bar('나', _taps, innerColor),
                bar(widget.opponent, ai, const Color(0xFFFF6B6B)),
                const SizedBox(height: 16),
                Text(
                  '연타 수가 많은 쪽 돌이 더 세게 튕겨 낸다(반발 ±${(QiClash.maxSwing * 100).round()}%)',
                  style: t.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
