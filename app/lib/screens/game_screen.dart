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
import '../progress/quests.dart';
import '../progress/settings.dart';
import '../progress/store.dart';
import '../story/puzzles.dart' show trickStars;
import '../ui/art.dart';
import '../ui/ghost_hand.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'flick_view.dart';
import 'qi_clash.dart';

/// 한 판 화면: 위에 두 사람 얼굴·남은 돌, 가운데 대전장, 아래 내공 구슬.
/// 내 돌을 누르면 그 돌을 가까이 보는 화면으로 바뀌고, 거기서 손끝으로 튕긴다.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.config,
    this.title,
    this.onTurnEnd,
    this.onPause,
    this.info,
    this.panel,
    this.quips = const [],
    this.boss = false,
    this.coach = false,
    this.stageId,
    this.coachLines = const [],
    this.timeLimit,
  });

  /// 시간 제한(초 · 묘수풀이 트릭샷). 겨누는 동안만 줄고, 다 되면 실패. 별은 남은 시간으로.
  final int? timeLimit;

  /// 고수전(강호행·폐관수련동)이면 이길 때 절명기 연출(설계서 §4).
  final bool boss;

  /// 고수 한마디 6줄(설계서 §16.7 · [Stage.quips] 와 같은 순서).
  final List<String> quips;
  final MatchConfig config;

  /// 한 수가 끝날 때마다(목인항 등).
  final void Function(Match match)? onTurnEnd;

  /// 일시정지(중지)할 때 부른다. 돌려준 글을 멈춤 창에 띄운다(목인항 「수련 저장됨 · 시:분」).
  final Future<String> Function()? onPause;

  /// 판 아래 안내 글(목인항 수련 수 등). 없으면 대전장 이름.
  final String Function()? info;

  /// 판 아래 안내 글 위에 놓는 칸(목인항 진행 막대·저장 등).
  final Widget Function(Match match)? panel;

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

  /// 시간 제한 판: 남은 시간(초)과 재는 시계.
  double _timeLeft = 0;
  Timer? _clock;

  void _tickClock(Timer _) {
    if (!mounted) return;
    final running =
        !_paused &&
        !_intro &&
        !_clashing &&
        _result == null &&
        !_match.isOver &&
        !_match.isMoving;
    if (!running) return;
    setState(() => _timeLeft = math.max(0, _timeLeft - 0.1));
    if (_timeLeft <= 0) {
      Sound.play('error');
      _match.timeUp();
    } else if (_timeLeft <= 5 && (_timeLeft * 10).round() % 10 == 0) {
      Sound.play('countdown', 0.6);
    }
  }

  /// 절명기 연출 중이면 그 이름(설계서 §4: 보스의 마지막 돌 장외).
  String? _finisher;

  /// 내공 겨루기 연타 화면이 떠 있나.
  bool _clashing = false;

  /// 이번 겨루기의 놀이와 고수 점수 — 겨루기가 시작될 때 한 번만 정한다
  /// (예전엔 그릴 때마다 고수 연타 수를 새로 뽑아 막대가 들쭉날쭉했다).
  ClashGame _clashGame = ClashGame.mash;
  int _clashAi = 0;

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
    Difficulty.skilled => 'mukhyeon',
    Difficulty.hard => 'mukgaek',
  };

  /// [first] 와 그다음 줄 가운데 하나를 2.6초 띄운다.
  void _say(int first) {
    if (widget.quips.length < first + 2) return;
    _show(widget.quips[first + _rand.nextInt(2)], _foeId);
  }

  /// 회심 부적을 썼다 — 다음 내 한 수는 반드시 회심.
  bool _critCharm = false;

  /// 일회용 아이템을 쓸 수 있는 판(혼자 하기 계열 · 묘수풀이·목인항·입문 빼고 · 2026-10-14).
  bool get _itemsAllowed =>
      widget.config.mode == MatchMode.vsAi &&
      widget.config.layout == null &&
      !widget.config.training &&
      !widget.coach;

  /// 지금 쓸 수 있나(내 차례 · 돌이 멈춤 · 판이 안 끝남).
  bool get _myCalmTurn =>
      _match.turn == 0 &&
      !_match.isMoving &&
      !_aiTurn &&
      !_aiThinking &&
      _result == null;

  /// 가방 창: 아이템 셋과 남은 수 · 「쓰기」.
  Future<void> _openItems() async {
    Sound.play('ui_open');
    final used = await showModalBottomSheet<Item>(
      context: context,
      backgroundColor: Palette.panel,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OutlinedText('일회용 아이템', size: 24, title: true),
              const SizedBox(height: 8),
              for (final it in Item.values)
                _itemRow(c, it, Bag.count(_store.profile, it.key)),
            ],
          ),
        ),
      ),
    );
    if (used == null || !mounted || !_myCalmTurn) return;
    if (!Bag.take(_store.profile, used.key)) return;
    unawaited(_store.save());
    switch (used) {
      case Item.critCharm:
        _critCharm = true;
        _show('회심 부적 — 다음 한 수는 반드시 회심!', _myId);
      case Item.guardCharm:
        _match.guard(0);
        _show('철벽 부적 — 상대가 칠 동안 내 돌이 버틴다', _myId);
      case Item.qiPill:
        _match.addQi(0, 2);
        _show('내공 단약 — 내공 2칸!', _myId);
    }
    Sound.play('unlock');
    Buzz.heavy();
    setState(() {});
  }

  Widget _itemRow(BuildContext c, Item it, int n) {
    final usable =
        n > 0 &&
        _myCalmTurn &&
        switch (it) {
          Item.critCharm => !_critCharm,
          Item.guardCharm => _match.guardTeam == null,
          Item.qiPill => _match.qi(0) < maxQi,
        };
    return ListTile(
      key: Key('item-${it.name}'),
      title: Text('${it.label}  ×$n'),
      subtitle: Text(it.help),
      trailing: FilledButton(
        onPressed: usable ? () => Navigator.pop(c, it) : null,
        child: const Text('쓰기'),
      ),
    );
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
      !widget.coach &&
      !widget.config.training &&
      e2eDemoMode.isEmpty &&
      !e2eFlick;

  @override
  void initState() {
    super.initState();
    _live++;
    // 숙적(묵현)·폐관 고수와는 긴박한 고수전 곡, 나머지는 대전장 곡.
    final rival =
        widget.config.opponentName == '묵현' ||
        (widget.config.opponentName?.startsWith('폐관') ?? false);
    if (rival) {
      Sound.track('bgm_boss');
    } else {
      Sound.music(widget.config.arena);
    }
    _newMatch();
    if (widget.timeLimit case final sec?) {
      _clock = Timer.periodic(const Duration(milliseconds: 100), _tickClock);
      _timeLeft = sec.toDouble();
    }
    _intro = _showIntro;
    if (_intro) {
      Sound.play('go');
      // 0.9초 — 눌러도 바로 넘어간다(매 판 1.5초를 기다리게 하던 것 · 2026-10-11 점검).
      Future<void>.delayed(const Duration(milliseconds: 900), () {
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

  /// 판 번호: 「처음부터」로 판이 바뀌면 늦게 도착한 옛 판의 결과·AI 수를 버린다
  /// (새 판 위에 지난 판 결과가 뜨던 것 · 2026-10-11 점검).
  int _gen = 0;

  /// 떠 있는 대전 화면 수 — 닫히는 옛 판이 새 판(입문 다음 수련)의 음악을 로비 곡으로 덮지 않게.
  static int _live = 0;

  void _newMatch() {
    _gen++;
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

  /// 일시정지: 손만 막는 것이 아니라 물리·AI 도 멈춘다(창 아래에서 상대가 두던 것 · 2026-10-11 점검).
  void _setPaused(bool v) {
    if (_paused == v) return;
    // 판이 끝나 결과를 기다리는 동안(절명기 연출 1.9초 등)은 멈출 수 없다 — 이긴 판을 「나가기」로
    // 진 판으로 만들던 것(2026-10-14 점검).
    if (v && _match.isOver) return;
    setState(() => _paused = v);
    _game.paused = v;
    if (!v) WidgetsBinding.instance.addPostFrameCallback((_) => _onMatch());
    if (v && widget.onPause != null) {
      // 2026-10-14 형 「목인항 수련하다가 중지하면 저장되게」.
      setState(() => _pauseNote = '저장 중…');
      widget.onPause!().then((note) {
        if (mounted) setState(() => _pauseNote = note);
      });
    }
  }

  /// 멈출 때 [GameScreen.onPause] 가 돌려준 글.
  String? _pauseNote;

  Future<void> _restart() async {
    if (AiGate.busy) {
      // AI 계산이 끝난 뒤에 새 물리 세계를 만든다([AiGate]) · 늦게 오는 옛 수는 판 번호로 버린다.
      _gen++;
      await AiGate.idle;
      if (!mounted) return;
    }
    // 옛 판은 멈춰 두고 화면이 새 판으로 바뀐 뒤에 치운다 — 옛 그리기(Flame 한 장)·사라지는 손끝 화면이
    // 한 번 더 읽는다(2026-10-14 점검 · 치운 물리 세계를 읽으면 앱이 꺼진다).
    final old = _match..removeListener(_onMatch);
    _game.paused = true;
    setState(() {
      _paused = false;
      _aiThinking = false;
      _newMatch();
      _timeLeft = (widget.timeLimit ?? 0).toDouble();
    });
    Future<void>.delayed(const Duration(milliseconds: 500), old.dispose);
  }

  bool _wasMoving = false;

  /// 이번 판에서 센 일(임무·업적, 설계서 §16.9).
  void _record(Deed d, [int n = 1]) {
    // 자유 대전·입문은 세지 않는다(「보상 없음」인 자유 대전 연습으로 임무를 채우던 것 — 2026-10-11).
    if (widget.coach || widget.title == null) return;
    if (widget.config.training && d != Deed.knock) return;
    Missions.record(_store.profile, d, today(), n);
  }

  void _onMatch() {
    if (!mounted) return;
    setState(() {});
    if (_match.clash != null && !_clashing) {
      // 준비 장면이 대치·북소리를 낸다(바로 연타로 들어가지 않는다 · 2026-10-11 형 지시).
      _clashing = true;
      _clashGame = ClashGame.values[_rand.nextInt(ClashGame.values.length)];
      _clashAi = QiClash.aiScore(_clashGame, widget.config.difficulty, _rand);
      Sound.play('clash', 0.7);
      _selected = null;
    }
    if (_wasMoving && !_match.isMoving) {
      // 먼저 내린다: onTurnEnd(목인항 더미 다시 세우기)가 알림을 다시 보내 여기로 곧장 되돌아오면
      // 끝없이 다시 불려 판이 터졌다(2026-10-11 점검 · 한 번 치면 1000번 넘게 불림).
      _wasMoving = false;
      widget.onTurnEnd?.call(_match);
      if (_match.lastShooter == 0 && _match.lastKnocked > 0) {
        _record(Deed.knock, _match.lastKnocked);
      }
      if (_match.lastKnocked >= 2) _say(_match.lastShooter == 0 ? 2 : 4);
      if (widget.coach && _match.lastShooter == 0 && _match.lastKnocked > 0) {
        _show(
          _match.lastKnocked >= 2 ? '일타쌍피! 훌륭하다!' : '좋다! 바로 그거다!',
          'sabu',
          1600,
        );
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
      final gen = _gen;
      if (boss) {
        Sound.play('finisher');
        setState(() => _finisher = finisherName(widget.config.martial));
        Future<void>.delayed(const Duration(milliseconds: 1900), () {
          if (!mounted || gen != _gen) return;
          setState(() => _finisher = null);
          _showResult();
        });
      } else {
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (mounted && gen == _gen) _showResult();
        });
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
    if (_aiTurn &&
        !_match.isMoving &&
        !_aiThinking &&
        !_match.isOver &&
        !_paused &&
        !_intro) {
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
          _critCharm ||
          (widget.config.critWidth > CriticalRule.maxOffset &&
              shot.offset <= widget.config.critWidth &&
              shot.power >= CriticalRule.minPower &&
              shot.power <= CriticalRule.maxPower),
      curl: shot.curl,
      flick: shot.flick,
    );
    // 회심 부적은 한 번 친 수에 쓰인다(내공 타격이면 회심이 없으니 그대로 남긴다).
    if (_match.lastMode == StrikeMode.plain) _critCharm = false;
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
    final h = _match.table.half;
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
          (o.position - s.position).length <
              (best.position - s.position).length) {
        best = o;
      }
    }
    if (best == null) return -math.pi / 2;
    final d = best.position - s.position;
    return math.atan2(d.y, d.x);
  }

  /// AI 계산이 실패했을 때 둘 수: 칠 수 있는 첫 돌로 가장 가까운 상대 돌을 겨눈다(없으면 null).
  AiShot? _fallbackShot() {
    final stones = _match.table.stones;
    for (final me in stones) {
      if (!_match.canShoot(me)) continue;
      phys.Stone? best;
      for (final o in stones) {
        if (o.out || o.team == me.team) continue;
        if (best == null ||
            (o.position - me.position).length <
                (best.position - me.position).length) {
          best = o;
        }
      }
      final d = best == null ? phys.Vector2(0, 1) : best.position - me.position;
      return AiShot(me.id, math.atan2(d.y, d.x), 80, 0);
    }
    return null;
  }

  Future<void> _playAi() async {
    final gen = _gen;
    setState(() => _aiThinking = true);
    final started = DateTime.now();
    AiShot? planned;
    try {
      planned = await chooseAiShot(_match);
    } catch (e) {
      // 계산이 실패해도 판이 멈추지 않게 — 가장 가까운 상대 돌을 향해 평범하게 한 수(2026-10-14 점검).
      debugPrint('AI 계산 실패: $e');
    }
    if (!mounted || gen != _gen) return;
    final shot = planned ?? _fallbackShot();
    if (shot == null) {
      setState(() => _aiThinking = false);
      return;
    }
    final waited = DateTime.now().difference(started);
    if (waited < const Duration(milliseconds: 700)) {
      await Future<void>.delayed(const Duration(milliseconds: 700) - waited);
    }
    // 멈춘 동안은 두지 않고 기다린다.
    while (mounted && _paused && gen == _gen) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!mounted || gen != _gen) return;
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
    final limit = widget.timeLimit;
    final stars = widget.config.mode == MatchMode.twoPlayer
        ? 0
        : (limit != null
              // 트릭샷: 남은 시간으로 별.
              ? (won ? trickStars(_timeLeft / limit) : 0)
              : starsFor(won: won, myLeft: _match.alive(0), myStart: _myStart));
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
    String title;
    if (_match.isDraw) {
      title = '비김';
    } else if (widget.config.mode == MatchMode.twoPlayer) {
      title = _match.winner == 0 ? '흰 돌 승리' : '검은 돌 승리';
    } else if (widget.config.mode == MatchMode.practice &&
        widget.title == null &&
        !widget.coach) {
      title = '연습 끝';
    } else {
      title = won ? '승리!' : '패배';
    }
    // 규칙 판은 어떻게 끝났는지 한 줄 덧붙인다.
    final why = switch (_match.rule) {
      MatchRule.general when !_match.isDraw => '장수가 떨어졌다',
      MatchRule.score => '${_match.scores[0]} : ${_match.scores[1]}',
      MatchRule.shots => '남은 돌 ${_match.alive(0)} : ${_match.alive(1)}',
      _ => null,
    };
    if (why != null) title = '$title\n$why';
    Sound.play(won ? 'jingle_win' : 'jingle_lose');
    setState(
      () => _result = _Result(
        title,
        won,
        stars,
        _match.bonusCoins,
        _match.bestKnock,
      ),
    );
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
    _clock?.cancel();
    _myStrike.dispose();
    _foeStrike.dispose();
    Sound.slide(0);
    _live--;
    if (_live == 0) Sound.lobby();
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
    if (!widget.coach ||
        _aiTurn ||
        _aiThinking ||
        _selected != null ||
        _match.isMoving ||
        _match.isOver) {
      return null;
    }
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
        (widget.coach
            ? '사부'
            : (vsAi
                  ? '상대'
                  : (widget.config.mode == MatchMode.twoPlayer
                        ? '검은 돌'
                        : '표적')));
    final hint = _tapHint;
    return PopScope(
      // 시스템 뒤로 가기는 늘 일시정지(결과 없이 닫혀 투기장 패배가 사라지던 구멍 — 2026-10-11).
      // 나가려면 일시정지의 「나가기」(= 진 판).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _result != null) return;
        // 가까이 보기 중이면 「다른 돌 고르기」, 시작 연출이면 건너뛰기.
        if (_selected != null && !widget.coach) {
          setState(() => _selected = null);
          return;
        }
        if (_intro) {
          setState(() => _intro = false);
          return;
        }
        if (widget.coach || _clashing) return;
        _setPaused(!_paused);
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
                            onTap: () => _setPaused(true),
                          ),
                        if (_itemsAllowed) ...[
                          const SizedBox(width: 6),
                          _RoundIcon(
                            key: const Key('items'),
                            icon: Icons.backpack_rounded,
                            label: '아이템',
                            onTap: _openItems,
                          ),
                        ],
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
                            name:
                                vsAi ||
                                    widget.config.opponentName != null ||
                                    widget.coach
                                ? '나'
                                : '흰 돌',
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
                  if (widget.timeLimit != null)
                    Padding(
                      key: const Key('time-left'),
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 22,
                            color: _timeLeft <= 5
                                ? const Color(0xFFFF6B5B)
                                : Palette.gold,
                          ),
                          const SizedBox(width: 4),
                          OutlinedText(
                            _timeLeft.ceil().toString(),
                            size: 24,
                            title: true,
                            color: _timeLeft <= 5
                                ? const Color(0xFFFF6B5B)
                                : Palette.gold,
                          ),
                        ],
                      ),
                    ),
                  if (widget.title != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: OutlinedText(
                        widget.title!,
                        size: 16,
                        color: Palette.gold,
                      ),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: GameWidget(game: _game)),
                        if (hint != null)
                          Positioned.fill(
                            child: Ghost(
                              builder: (tt) => GhostTapPainter(
                                at: _game.screenOf(
                                  hint.position.x,
                                  hint.position.y,
                                ),
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
                            // 구슬만 있으면 무엇인지 모른다 — 이름을 붙인다(2026-10-11 점검).
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: OutlinedText('내공', size: 15),
                            ),
                            for (var i = 0; i < maxQi; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: _QiOrb(full: i < _match.qi(0)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_status.isNotEmpty)
                          OutlinedText(_status, size: 20, title: true),
                        const SizedBox(height: 2),
                        ?widget.panel?.call(_match),
                        Text(
                          widget.info?.call() ??
                              _match.ruleStatus ??
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
                        demo: widget.coach || !_store.profile.tutorialDone,
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
                  me: _myId,
                  foe: _foeId,
                  game: _clashGame,
                  aiTaps: _clashAi,
                  onDone: (mine, theirs) {
                    _match.resolveClash(mine, theirs, _clashGame);
                    setState(() => _clashing = false);
                  },
                ),
              ),
            if (_finisher != null)
              Positioned.fill(child: FinisherOverlay(name: _finisher!)),
            if (_intro)
              Positioned.fill(
                child: VersusIntro(
                  onSkip: () => setState(() => _intro = false),
                  me: _myId,
                  foe: _foeId,
                  foeName: foeName,
                  title: widget.title ?? widget.config.arena.label,
                ),
              ),
            if (_paused)
              Positioned.fill(
                child: _PauseMenu(
                  onResume: () => _setPaused(false),
                  // 판을 거는 판(강호행·투기장·기연 등)은 다시 하기로 진 판을 지울 수 없다.
                  onRestart: widget.title == null ? _restart : null,
                  // 진 판이 되는 판(강호행·투기장 등)은 한 번 묻는다. 목인항은 지는 판이 아니다.
                  quitLoses: widget.title != null && !widget.config.training,
                  note: widget.onPause == null ? null : _pauseNote,
                  onQuit: () {
                    _setPaused(false);
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
                  best: r.best,
                  character: r.won ? _myId : _foeId,
                  onAgain: widget.title == null && !widget.coach
                      ? _restart
                      : null,
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
  _Result(this.title, this.won, this.stars, this.coins, this.best);
  final String title;
  final bool won;
  final int stars;
  final int coins;
  final int best;
}

/// 둥근 아이콘 단추(일시정지 등).
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.label = '잠시 멈춤',
  });
  final IconData icon;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sound.play('ui_tap', 0.7);
        onTap();
      },
      child: _roundBody(),
    ),
  );

  Widget _roundBody() => Container(
    width: 48,
    height: 48,
    margin: const EdgeInsets.only(right: 6),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.black54,
      border: Border.all(
        color: Palette.gold.withValues(alpha: 0.6),
        width: 1.5,
      ),
    ),
    child: Icon(icon, color: Palette.text),
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
      crossAxisAlignment: mirror
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedText(
          name,
          size: 15,
          color: active ? Palette.gold : Colors.white,
        ),
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
        border: Border.all(
          color: active ? Palette.gold : Colors.white12,
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Palette.gold.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: mirror
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
        colors: full
            ? [Colors.white, innerColor]
            : const [Color(0xFF4A4050), Color(0xFF1E1822)],
      ),
      border: Border.all(
        color: full ? Colors.white : Colors.white24,
        width: 1.5,
      ),
      boxShadow: full
          ? [
              BoxShadow(
                color: innerColor.withValues(alpha: 0.8),
                blurRadius: 10,
              ),
            ]
          : null,
    ),
  );
}

/// 말풍선: 얼굴 + 이름 + 한마디.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    super.key,
    required this.by,
    required this.name,
    required this.text,
  });
  final String? by;
  final String name;
  final String text;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutBack,
    builder: (_, k, child) => Transform.scale(
      scale: 0.8 + 0.2 * k,
      child: Opacity(opacity: k.clamp(0, 1), child: child),
    ),
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
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: titleFont,
                    fontSize: 14,
                    color: Palette.redDeep,
                  ),
                ),
                Text(
                  text,
                  style: const TextStyle(
                    fontFamily: bodyFont,
                    fontSize: 19,
                    color: Color(0xFF2A1A12),
                  ),
                ),
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
  const VersusIntro({
    super.key,
    required this.me,
    required this.foe,
    required this.foeName,
    required this.title,
    this.onSkip,
  });
  final String me;
  final String? foe;
  final String foeName;
  final String title;

  /// 누르면 바로 넘어간다.
  final VoidCallback? onSkip;

  @override
  State<VersusIntro> createState() => _VersusIntroState();
}

class _VersusIntroState extends State<VersusIntro>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onSkip,
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
                    child: CharacterSprite(
                      id: widget.foe ?? 'jagaek',
                      height: 230,
                    ),
                  ),
                  Positioned(
                    bottom: 90,
                    right: -w * 0.6 * (1 - inK),
                    child: CharacterSprite(
                      id: widget.me,
                      height: 230,
                      flip: true,
                    ),
                  ),
                  Transform.scale(
                    scale:
                        0.5 +
                        0.5 *
                            Curves.elasticOut.transform(
                              ((v - 0.2) / 0.5).clamp(0, 1),
                            ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const OutlinedText(
                          'VS',
                          size: 76,
                          title: true,
                          color: Palette.gold,
                        ),
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
  const _PauseMenu({
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
    this.quitLoses = false,
    this.note,
  });
  final VoidCallback onResume;
  final VoidCallback? onRestart;
  final VoidCallback onQuit;
  final bool quitLoses;

  /// 제목 아래 한 줄(목인항 「수련 저장됨 · 시:분」).
  final String? note;

  @override
  State<_PauseMenu> createState() => _PauseMenuState();
}

class _PauseMenuState extends State<_PauseMenu> {
  /// 「처음부터」·「나가기」를 한 번 더 눌러야 실행(실수로 진 판이 되던 것 · 2026-10-11 점검).
  String? _confirm;

  void _ask(String what, VoidCallback go) {
    if (_confirm == what) {
      go();
      return;
    }
    Sound.play('ui_open');
    setState(() => _confirm = what);
  }

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
                const OutlinedText(
                  '잠시 멈춤',
                  size: 30,
                  title: true,
                  color: Palette.gold,
                ),
                if (widget.note case final note?) ...[
                  const SizedBox(height: 6),
                  Text(
                    note,
                    key: const Key('pause-note'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Palette.jade),
                  ),
                ],
                const SizedBox(height: 16),
                GameButton(
                  key: const Key('resume'),
                  label: '계속',
                  color: Palette.jade,
                  onTap: widget.onResume,
                ),
                const SizedBox(height: 10),
                if (widget.onRestart case final restart?)
                  GameButton(
                    key: const Key('restart'),
                    label: _confirm == 'restart' ? '정말 처음부터?' : '처음부터',
                    color: Palette.sky,
                    onTap: () => _ask('restart', restart),
                  ),
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
                GameButton(
                  key: const Key('quit'),
                  label: _confirm == 'quit'
                      ? (widget.quitLoses ? '진 판이 됩니다 — 나가기' : '정말 나가기')
                      : '나가기',
                  color: Palette.red,
                  onTap: () => _ask('quit', widget.onQuit),
                  height: 52,
                  fontSize: 20,
                ),
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
    this.best = 0,
  });
  final String title;
  final bool won;
  final int stars;
  final int coins;

  /// 오늘의 한 수(한 수에 가장 많이 떨어뜨린 수) — 둘 이상이면 자랑 한 줄.
  final int best;
  final String? character;
  final VoidCallback onDone;
  final VoidCallback? onAgain;

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
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
    if (widget.won) {
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        () => _attack.value++,
      );
    }
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
                    CharacterSprite(
                      id: widget.character!,
                      height: 200,
                      attack: _attack,
                    ),
                  Transform.scale(
                    scale: 0.4 + 0.6 * pop,
                    child: OutlinedText(
                      widget.title.split('\n').first,
                      size: 54,
                      title: true,
                      color: widget.won
                          ? Palette.gold
                          : const Color(0xFFB0B8C8),
                    ),
                  ),
                  // 규칙 판은 어떻게 끝났는지 한 줄(점수·남은 돌·장수).
                  if (widget.title.contains('\n'))
                    OutlinedText(widget.title.split('\n').last, size: 22),
                  const SizedBox(height: 8),
                  if (widget.stars > 0 || widget.won)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Builder(
                            builder: (_) {
                              final k = ((v - 0.35 - i * 0.15) / 0.15).clamp(
                                0.0,
                                1.0,
                              );
                              final on = i < widget.stars && k > 0;
                              return Transform.translate(
                                offset: Offset(0, i == 1 ? -12 : 0),
                                child: Transform.scale(
                                  scale: on
                                      ? 0.6 +
                                            0.4 *
                                                Curves.easeOutBack.transform(
                                                  k,
                                                ) *
                                                1.0
                                      : 0.85,
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
                        OutlinedText(
                          '+${widget.coins} 일타쌍피',
                          size: 20,
                          color: Palette.gold,
                        ),
                      ],
                    ),
                  ],
                  if (widget.best >= 2) ...[
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: ((v - 0.5) / 0.2).clamp(0, 1),
                      child: OutlinedText(
                        '오늘의 한 수 — 한 번에 ${widget.best}개!',
                        key: const Key('best-shot'),
                        size: 22,
                        color: const Color(0xFFFFE9A8),
                      ),
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
                              child: GameButton(
                                label: '한 판 더',
                                color: Palette.sky,
                                // 보이기 전에는 눌리지 않게(나가기와 같이).
                                onTap: v > 0.6 ? widget.onAgain : null,
                                fontSize: 20,
                              ),
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
