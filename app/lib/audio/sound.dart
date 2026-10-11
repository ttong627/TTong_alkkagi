import 'dart:async';
import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../game/arena.dart';
import '../progress/settings.dart';

/// 소리(설계서 §16.5). 효과음·음악은 `tool/make_audio.py` 로 직접 합성한 OGG 다(국악 악기 합성 · 잔향 · 이음매 없는 반복).
///
/// [init] 을 부르기 전(시험 등)에는 아무 소리도 내지 않는다. 소리를 못 내도 판은 그대로 간다.
abstract final class Sound {
  static bool _ready = false;
  static final _pools = <String, AudioPool>{};
  static AudioPlayer? _music;
  static AudioPlayer? _slide;
  static String? _track;
  static double _slideLevel = 0;

  /// 한 번에 겹쳐 낼 수 있는 수.
  static const _voices = {
    'touch': 2,
    'hit_cheongok': 4,
    'hit_wood': 4,
    'hit_hyeoncheol': 4,
    'hit_ice': 4,
    'out_thud': 3,
  };

  /// 미리 읽어 두는 효과음 이름(assets/sounds/이름.ogg · `tool/make_audio.py` 로 합성).
  static const effects = [
    'touch',
    'hit_cheongok',
    'hit_wood',
    'hit_hyeoncheol',
    'hit_ice',
    'critical',
    'inner',
    'tech_swordQi',
    'tech_stomp',
    'tech_taiji',
    'tech_clone',
    'tech_absorb',
    'ultimate',
    'out_thud',
    'out_crowd',
    'clash',
    'finisher',
    'terrain_gong',
    'terrain_mine',
    // 화면·보상(설계서 §16.5).
    'ui_tap',
    'ui_back',
    'ui_open',
    'coin',
    'reward',
    'star',
    'unlock',
    'error',
    'tutorial_ok',
    'whoosh',
    'countdown',
    'go',
    // 짧은 곡(한 번만).
    'jingle_win',
    'jingle_lose',
    'jingle_levelup',
    'jingle_reward',
    'jingle_chapter',
  ];

  static Future<void> init() async {
    try {
      // 다른 앱 소리를 끊지 않고 섞는다.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
      for (final n in effects) {
        _pools[n] = await AudioPool.createFromAsset(
          path: 'sounds/$n.ogg',
          maxPlayers: _voices[n] ?? 2,
          playerMode: PlayerMode.lowLatency,
        );
      }
      _music = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      _slide = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _slide!.setSource(AssetSource('sounds/slide.ogg'));
      await _slide!.setVolume(0);
      _ready = true;
      Settings.instance.addListener(_applyVolumes);
      if (_pending != null) track(_pending);
    } catch (e) {
      debugPrint('소리 준비 실패: $e');
    }
  }

  static void _applyVolumes() {
    final m = _music;
    if (m != null) unawaited(m.setVolume(Settings.instance.music));
    if (Settings.instance.sfx <= 0) slide(0);
  }

  /// 효과음 하나. [gain] 0~1 은 효과음 크기에 곱한다.
  static void play(String name, [double gain = 1]) {
    if (!_ready) return;
    final v = (Settings.instance.sfx * gain).clamp(0.0, 1.0);
    final pool = _pools[name];
    if (pool == null || v <= 0.01) return;
    unawaited(pool.start(volume: v).then((_) {}, onError: (_) {}));
  }

  /// 손끝이 돌에 닿음 — 세기([power] 0~1)에 따라 크기.
  static void touch([double power = 0.5]) => play('touch', 0.4 + 0.6 * power);

  /// 충돌: 재질별 소리, 다가온 빠르기로 크기(20cm/s 아래는 작게).
  static void hit(StoneMaterial m, double speed) {
    if (speed < 3) return;
    play('hit_${m.name}', math.min(1, 0.15 + speed / 90));
  }

  static void technique(Technique t) {
    if (t == Technique.none) return;
    play('tech_${t.name}');
  }

  /// 미끄러지는 소리: [level] 0~1(가장 빠른 돌의 빠르기). 0 이면 멈춤.
  static void slide(double level) {
    final p = _slide;
    if (!_ready || p == null) return;
    final v = (level * Settings.instance.sfx * 0.6).clamp(0.0, 1.0);
    if ((v - _slideLevel).abs() < 0.03 && !(v == 0 && _slideLevel > 0)) return;
    final was = _slideLevel;
    _slideLevel = v;
    unawaited(() async {
      try {
        await p.setVolume(v);
        if (v > 0 && was == 0) await p.resume();
        if (v == 0) await p.pause();
      } catch (_) {}
    }());
  }

  /// 대전장 배경 음악(장마다 다름). null 이면 끈다.
  static void music(Arena? arena) =>
      track(arena == null ? null : 'bgm_${arena.name}');

  /// 로비 음악.
  static void lobby() => track('bgm_lobby');

  /// 배경 음악 하나(assets/sounds/이름.ogg, 이어서 되풀이). null 이면 끈다.
  static void track(String? name) {
    final p = _music;
    if (!_ready || p == null) {
      _pending = name;
      return;
    }
    if (name == _track) return;
    _track = name;
    unawaited(() async {
      try {
        if (name == null) {
          await p.stop();
          return;
        }
        await p.stop();
        await p.setVolume(Settings.instance.music);
        await p.play(AssetSource('sounds/$name.ogg'));
      } catch (_) {}
    }());
  }

  /// 소리가 준비되기 전에 부른 음악(준비되면 튼다).
  static String? _pending;
}
