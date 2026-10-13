import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/flick.dart';

/// 설정(설계서 §16.6): 소리·진동·손맛 보정·위아래 타격점·왼손잡이. 기기에 따로 저장한다.
class Settings extends ChangeNotifier {
  Settings._();

  static const _key = 'settings.v1';
  static const _areasKey = 'touch_areas.v1';

  /// 앱 전체가 함께 쓰는 하나.
  static final instance = Settings._();

  /// 효과음·음악 크기(0~1).
  double sfx = 0.8;
  double music = 0.5;

  /// 진동.
  bool vibration = true;

  /// 진동 세기 배수(약 0.6 · 보통 1 · 강 1.4) — 폰마다 진동 모터가 달라서(2026-10-13 형 「진동이 확실하게」).
  double vibeLevel = 1;
  static const vibeLevels = [(0.6, '약'), (1.0, '보통'), (1.4, '강')];

  /// 카메라 연출(돌을 따라 당기고 눕히기). 어지러운 분은 끈다.
  bool camera = true;

  /// 손맛 보정 −0.3~+0.3: 세기 기준(1,500화소/초)에 (1 + 값)을 곱한다.
  /// 빠른 손이면 + 로 올려 같은 손놀림이 덜 세게, 느린 손이면 − 로.
  double feel = 0;

  /// 위아래 타격점(닿은 넓이)을 쓴다.
  bool hitArea = true;

  /// 왼손잡이: 가까이 보기 화면 단추를 오른쪽으로.
  bool leftHanded = false;

  /// 조작 방식: false = 검지로 튕기기(기본), true = 돌을 잡고 당겨 쏘기([PullReader]).
  bool pull = false;

  static const double feelMin = -0.3, feelMax = 0.3;

  /// 지금 손맛 보정이 들어간 쳐 내기 설정.
  StrikeTuning get tuning => feel == 0
      ? StrikeTuning.standard
      : StrikeTuning(
          fullPxPerSec: StrikeTuning.standard.fullPxPerSec * (1 + feel),
        );

  /// 위아래 타격점을 끄면 넓이를 판단에 쓰지 않는다(늘 가운데).
  TouchProfile get touchProfile =>
      hitArea ? TouchProfile.shared : TouchProfile.off;

  Map<String, Object?> toJson() => {
    'sfx': sfx,
    'music': music,
    'vibration': vibration,
    'vibeLevel': vibeLevel,
    'camera': camera,
    'feel': feel,
    'hitArea': hitArea,
    'leftHanded': leftHanded,
    'pull': pull,
  };

  void apply(Map<String, Object?> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    sfx = d('sfx', 0.8).clamp(0.0, 1.0);
    music = d('music', 0.5).clamp(0.0, 1.0);
    vibration = j['vibration'] as bool? ?? true;
    vibeLevel = d('vibeLevel', 1).clamp(0.6, 1.4);
    camera = j['camera'] as bool? ?? true;
    feel = d('feel', 0).clamp(feelMin, feelMax);
    hitArea = j['hitArea'] as bool? ?? true;
    leftHanded = j['leftHanded'] as bool? ?? false;
    pull = j['pull'] as bool? ?? false;
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_key);
      if (s != null) {
        instance.apply((jsonDecode(s) as Map).cast<String, Object?>());
      }
      final areas = prefs.getStringList(_areasKey);
      if (areas != null) {
        TouchProfile.shared.restore(
          areas.map(double.tryParse).whereType<double>(),
        );
      }
    } catch (_) {
      // 깨진 설정이면 기본값.
    }
  }

  Future<void> save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (_) {}
  }

  /// 평소 손끝 넓이 기록을 저장한다(다음에 켜도 위아래 타격점을 바로 쓰게).
  static Future<void> saveAreas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_areasKey, [
        for (final a in TouchProfile.shared.areas) a.toStringAsFixed(4),
      ]);
    } catch (_) {}
  }

  /// 다시 배우기: 평소 넓이 기록을 지운다.
  Future<void> resetAreas() async {
    TouchProfile.shared.clear();
    await saveAreas();
    notifyListeners();
  }
}

/// 진동(설정에서 끌 수 있다).
///
/// 2026-10-11 형 「손맛이 조금 더 전해지도록 진동」: 안드로이드에서는 길이·세기(1~255)를 정해 떤다
/// (`tanji/haptic` · MainActivity 의 Haptics). 못 쓰는 곳(시험·다른 기기)은 플러터 기본 햅틱으로.
abstract final class Buzz {
  static const _ch = MethodChannel('tanji/haptic');

  /// 안드로이드 진동기를 쓸 수 있나(한 번 실패하면 기본 햅틱으로만).
  static bool _native =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 충돌이 한 장면에 몰려도 0.045초에 한 번만 떤다(가장 센 것).
  static int _lastMs = 0;
  static const _gapMs = 45;

  /// 마지막으로 낸 진동(시험용 · (길이ms, 세기)).
  @visibleForTesting
  static final log = <(int, int)>[];

  static void tick() {
    if (!Settings.instance.vibration) return;
    if (!_pulse(20, 120)) HapticFeedback.selectionClick();
  }

  static void heavy() {
    if (!Settings.instance.vibration) return;
    if (!_pulse(60, 255)) HapticFeedback.heavyImpact();
  }

  /// 부딪힘·타격: [strength] 0~1 만큼(길이 20~70ms · 세기 110~255).
  /// 2026-10-13 형 「진동이 확실하게」: 예전 바닥(10ms · 50)은 손에 거의 안 느껴졌다.
  static void impact(double strength) {
    if (!Settings.instance.vibration) return;
    final k = strength.clamp(0.0, 1.0);
    if (k < 0.04) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < _gapMs) return;
    _lastMs = now;
    final ms = (20 + 50 * k).round(), amp = (110 + 145 * k).round();
    if (_pulse(ms, amp)) return;
    if (k > 0.66) {
      HapticFeedback.heavyImpact();
    } else if (k > 0.33) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// 여러 번 떨기: (길이ms, 세기 0~255 — 0 이면 쉼) 목록.
  static void pattern(List<(int, int)> raw) {
    if (!Settings.instance.vibration || raw.isEmpty) return;
    final steps = [for (final (ms, amp) in raw) (ms, _scale(amp))];
    _lastMs = DateTime.now().millisecondsSinceEpoch;
    log.addAll(steps.where((s) => s.$2 > 0));
    if (_native) {
      _ch
          .invokeMethod<bool>('pattern', {
            'ms': [for (final s in steps) s.$1],
            'amp': [for (final s in steps) s.$2],
          })
          .catchError((_) {
            _native = false;
            return false;
          });
      return;
    }
    HapticFeedback.heavyImpact();
  }

  /// 회심·궁극기: 쿵-쿵 두 번.
  static void burst() => pattern(const [(0, 0), (40, 255), (60, 0), (70, 200)]);

  /// 장외(돌이 판 밖으로): 길게 묵직하게.
  static void thud() => pattern(const [(0, 0), (90, 230), (40, 0), (30, 120)]);

  /// 내공 겨루기 심장 박동: 쿵-쿵.
  static void heartbeat() =>
      pattern(const [(0, 0), (35, 200), (110, 0), (25, 120)]);

  /// 설정의 진동 세기를 곱한다(쉬는 칸 0 은 그대로 · 1~255).
  static int _scale(int amp) =>
      amp <= 0 ? 0 : (amp * Settings.instance.vibeLevel).round().clamp(1, 255);

  static bool _pulse(int ms, int raw) {
    final amp = _scale(raw);
    log.add((ms, amp));
    if (log.length > 64) log.removeRange(0, log.length - 64);
    if (!_native) return false;
    _ch.invokeMethod<bool>('pulse', {'ms': ms, 'amp': amp}).catchError((_) {
      _native = false;
      return false;
    });
    return true;
  }
}
