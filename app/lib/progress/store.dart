import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

/// 진행 상태를 기기에 저장하고 화면에 알린다.
class ProfileStore extends ChangeNotifier {
  ProfileStore._(this.profile);

  static const _key = 'profile.v1';
  static ProfileStore? _instance;

  /// 앱 전체가 함께 쓰는 하나. [load] 를 먼저 부른다.
  static ProfileStore get instance => _instance ??= ProfileStore._(Profile());

  Profile profile;

  /// 저장된 진행을 읽는다(없거나 깨졌으면 새로 시작).
  static Future<ProfileStore> load() async {
    final store = instance;
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_key);
      if (s != null) store.profile = Profile.decode(s);
    } catch (_) {
      // 깨진 저장이면 새로 시작한다(지우지는 않고 덮어쓴다).
    }
    return store;
  }

  /// 바꾼 뒤 부른다: 저장하고 화면에 알린다.
  Future<void> save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, profile.encode());
    } catch (_) {}
  }
}
