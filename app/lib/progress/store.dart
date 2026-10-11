import 'dart:convert';
import 'dart:io';

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

  /// 진행 백업 코드(설계서 §16.13): 폰을 바꿀 때 옮기려고. 저장 내용을 압축·base64 로 감싸고
  /// 앞에 확인 글자(합계 끝 4자리)를 붙인다 — 잘못 붙여 넣은 코드를 걸러 내려는 것이지 조작 방지는 아니다.
  String exportCode() {
    final raw = gzip.encode(utf8.encode(profile.encode()));
    final body = base64Url.encode(raw);
    return 'TJ1-${_sum(body)}-$body';
  }

  /// 백업 코드로 불러오기. 코드가 틀리면 false(지금 진행은 그대로).
  Future<bool> importCode(String code) async {
    final c = code.trim().replaceAll(RegExp(r'\s'), '');
    final m = RegExp(r'^TJ1-([0-9a-f]{4})-([A-Za-z0-9_=-]+)$').firstMatch(c);
    if (m == null || _sum(m.group(2)!) != m.group(1)) return false;
    try {
      final json = utf8.decode(gzip.decode(base64Url.decode(m.group(2)!)));
      profile = Profile.decode(json);
    } catch (_) {
      return false;
    }
    await save();
    return true;
  }

  static String _sum(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0xFFFF;
    }
    return h.toRadixString(16).padLeft(4, '0');
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
