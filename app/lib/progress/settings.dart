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

  /// 손맛 보정 −0.3~+0.3: 세기 기준(1,500화소/초)에 (1 + 값)을 곱한다.
  /// 빠른 손이면 + 로 올려 같은 손놀림이 덜 세게, 느린 손이면 − 로.
  double feel = 0;

  /// 위아래 타격점(닿은 넓이)을 쓴다.
  bool hitArea = true;

  /// 왼손잡이: 가까이 보기 화면 단추를 오른쪽으로.
  bool leftHanded = false;

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
    'feel': feel,
    'hitArea': hitArea,
    'leftHanded': leftHanded,
  };

  void apply(Map<String, Object?> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    sfx = d('sfx', 0.8).clamp(0.0, 1.0);
    music = d('music', 0.5).clamp(0.0, 1.0);
    vibration = j['vibration'] as bool? ?? true;
    feel = d('feel', 0).clamp(feelMin, feelMax);
    hitArea = j['hitArea'] as bool? ?? true;
    leftHanded = j['leftHanded'] as bool? ?? false;
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
abstract final class Buzz {
  static void tick() {
    if (Settings.instance.vibration) HapticFeedback.selectionClick();
  }

  static void heavy() {
    if (Settings.instance.vibration) HapticFeedback.heavyImpact();
  }
}
