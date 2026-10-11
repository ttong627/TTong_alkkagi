import 'dart:async';
import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart' as phys;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../e2e.dart';
import '../game/ai.dart';
import '../game/board_game.dart';
import '../game/flick.dart';
import '../game/fx_colors.dart';
import '../game/match.dart';
import 'flick_view.dart';

/// 한 판 화면: 위에 차례·남은 돌, 가운데 대전장.
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

  /// 지금 말풍선에 띄운 고수 한마디.
  String? _quip;
  Timer? _quipTimer;

  /// 절명기 연출 중이면 그 이름(설계서 §4: 보스의 마지막 돌 장외).
  String? _finisher;

  /// 내공 겨루기 연타 화면이 떠 있나.
  bool _clashing = false;

  /// [first] 와 그다음 줄 가운데 하나를 2.6초 띄운다.
  void _say(int first) {
    if (widget.quips.length < first + 2) return;
    _quipTimer?.cancel();
    setState(() => _quip = widget.quips[first + _rand.nextInt(2)]);
    _quipTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _quip = null);
    });
  }

  bool get _aiTurn => widget.config.mode == MatchMode.vsAi && _match.turn == 1;

  @override
  void initState() {
    super.initState();
    _newMatch();
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
      canTouch: () => !_aiTurn && !_aiThinking,
      onSelect: (s) => setState(() => _selected = s),
      selected: () => _selected,
    );
    _selected = null;
    _resultShown = false;
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
      _match
        ..removeListener(_onMatch)
        ..dispose();
      _newMatch();
    });
  }

  bool _wasMoving = false;

  void _onMatch() {
    if (!mounted) return;
    setState(() {});
    if (_match.clash != null && !_clashing) {
      _clashing = true;
      _selected = null;
    }
    if (_wasMoving && !_match.isMoving) {
      widget.onTurnEnd?.call(_match);
      if (_match.lastKnocked >= 2) _say(_match.lastShooter == 0 ? 2 : 4);
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
        setState(() => _finisher = finisherName(widget.config.martial));
        Future<void>.delayed(const Duration(milliseconds: 1900), () {
          if (mounted) setState(() => _finisher = null);
          _showResult();
        });
      } else {
        Future<void>.delayed(const Duration(milliseconds: 400), _showResult);
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
    if (_aiTurn && !_match.isMoving && !_aiThinking && !_match.isOver) {
      unawaited(_playAi());
    }
  }

  void _shoot(FlickShot shot, StrikeMode mode) {
    final s = _selected;
    setState(() => _selected = null);
    if (s == null) return;
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
    if (_match.lastCritical) _say(0);
  }

  /// 고른 돌이 판 어디 있는지에 맞춰 가까이 보기 화면이 그 자리에서 커져 나온다.
  Alignment get _zoomFrom {
    final s = _selected;
    if (s == null) return Alignment.center;
    const h = phys.PhysicsConstants.halfBoard;
    return Alignment(s.position.x / h * 0.85, s.position.y / h * 0.6);
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
    final String title;
    if (_match.isDraw) {
      title = '비겼습니다';
    } else if (widget.config.mode == MatchMode.practice) {
      title = '연습 끝';
    } else if (widget.config.mode == MatchMode.vsAi) {
      title = _match.winner == 0 ? '이겼습니다!' : '졌습니다';
    } else {
      title = _match.winner == 0 ? '흰 돌 승리' : '검은 돌 승리';
    }
    if (widget.title != null) {
      // 강호행: 결과는 부른 화면이 보여 준다(보상·대사).
      Navigator.of(context).pop(_match.winner == 0 && !_match.isDraw);
      return;
    }
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(
          '${_match.turnCount}수 · 남은 돌 흰 ${_match.alive(0)} : 검 ${_match.alive(1)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('처음으로'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('한 판 더'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _quipTimer?.cancel();
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
    if (_match.isMoving) return '돌이 움직이는 중…';
    switch (widget.config.mode) {
      case MatchMode.practice:
        return '어느 돌로 공격할까요?';
      case MatchMode.vsAi:
        return _match.turn == 0
            ? '어느 돌로 공격할까요?'
            : (_aiThinking ? '상대가 수를 읽는 중…' : '상대 차례');
      case MatchMode.twoPlayer:
        return _match.turn == 0 ? '흰 돌 · 어느 돌로 공격할까요?' : '검은 돌 · 어느 돌로 공격할까요?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ??
              (widget.config.mode == MatchMode.vsAi
                  ? '${widget.config.mode.label} · ${widget.config.difficulty.label}'
                  : widget.config.mode.label),
        ),
        actions: [
          IconButton(
            onPressed: _restart,
            icon: const Icon(Icons.refresh),
            tooltip: '다시 시작',
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _Count(
                        label:
                            widget.config.opponentName ??
                            (widget.config.mode == MatchMode.vsAi ? '상대' : '검'),
                        n: _match.alive(1),
                        dark: true,
                      ),
                      Expanded(
                        child: Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: t.titleMedium,
                        ),
                      ),
                      _Count(
                        label:
                            widget.config.mode == MatchMode.vsAi ||
                                widget.config.opponentName != null
                            ? '나'
                            : '흰',
                        n: _match.alive(0),
                        dark: false,
                      ),
                      const SizedBox(width: 8),
                      for (var i = 0; i < maxQi; i++)
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: i < _match.qi(0) ? innerColor : Colors.white24,
                        ),
                    ],
                  ),
                ),
                Expanded(child: GameWidget(game: _game)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    widget.info?.call() ??
                        '${widget.config.arena.chapter} · ${widget.config.arena.label}',
                    style: t.bodySmall,
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
                    ),
            ),
          ),
          if (_quip != null && _selected == null)
            Positioned(
              top: 56,
              left: 24,
              right: 24,
              child: IgnorePointer(
                child: Container(
                  key: const Key('boss-quip'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    '${widget.config.opponentName ?? '상대'}: $_quip',
                    style: t.titleSmall,
                  ),
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
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.n, required this.dark});
  final String label;
  final int n;
  final bool dark;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 9,
        backgroundColor: dark
            ? const Color(0xFF1E1E22)
            : const Color(0xFFF4F1EA),
      ),
      const SizedBox(width: 6),
      Text('$label $n', style: Theme.of(context).textTheme.titleMedium),
    ],
  );
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
              fontSize: 20,
              color: Colors.white.withValues(alpha: fade),
              letterSpacing: 8,
            ),
          ),
          TextSpan(
            text: name,
            style: TextStyle(
              fontSize: 40 * grow,
              fontWeight: FontWeight.w900,
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
