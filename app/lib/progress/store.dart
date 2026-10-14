import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

/// 진행 상태를 기기에 저장하고 화면에 알린다.
class ProfileStore extends ChangeNotifier {
  ProfileStore._(this.profile);

  static const _key = 'profile.v1';

  /// 직전 정상 저장(저장이 깨지면 이걸로 되살린다).
  static const _backupKey = 'profile.v1.bak';

  /// 읽지 못한 저장은 지우지 않고 여기 옮겨 둔다(나중에 살펴보게).
  static const _corruptKey = 'profile.v1.corrupt';

  /// 백업 코드 최대 길이(글자)와 풀었을 때 최대 크기(바이트). 실제 코드는 수 KB 다.
  static const maxCodeLength = 64 * 1024;
  static const _maxInflated = 512 * 1024;
  static ProfileStore? _instance;

  /// 앱 전체가 함께 쓰는 하나. [load] 를 먼저 부른다.
  static ProfileStore get instance => _instance ??= ProfileStore._(Profile());

  Profile profile;

  /// 저장된 진행을 읽는다(없거나 깨졌으면 새로 시작).
  static Future<ProfileStore> load() async {
    final store = instance;
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      store._loadFailed = true;
      return store;
    }
    final s = prefs.getString(_key);
    if (s == null) return store;
    try {
      store.profile = Profile.decode(s);
    } catch (_) {
      // 깨진 저장: 따로 옮겨 두고, 직전 정상본이 있으면 그것으로 되살린다
      // (예전엔 새로 시작해 다음 저장이 덮어써서 진행이 통째로 사라졌다 · 2026-10-11 점검).
      store.loadNote = '저장이 손상되어 새로 시작했어요 — 손상된 저장은 따로 보관했어요';
      try {
        await prefs.setString(_corruptKey, s);
        final b = prefs.getString(_backupKey);
        if (b != null) {
          store.profile = Profile.decode(b);
          store.loadNote = '저장이 손상되어 직전 저장으로 되살렸어요';
        }
      } catch (_) {}
    }
    return store;
  }

  /// 읽을 때 일어난 일(손상 복구 등) — 첫 화면이 한 번 알린다(조용히 새로 시작하던 것 · 2026-10-14 점검).
  String? loadNote;

  /// 진행 백업 코드(설계서 §16.13): 폰을 바꿀 때 옮기려고. 저장 내용을 압축·base64 로 감싸고
  /// 앞에 확인 글자(합계 끝 4자리)를 붙인다 — 잘못 붙여 넣은 코드를 걸러 내려는 것이지 조작 방지는 아니다.
  String exportCode() {
    final raw = gzip.encode(utf8.encode(profile.encode()));
    final body = base64Url.encode(raw);
    return 'TJ1-${_sum(body)}-$body';
  }

  /// 백업 코드로 불러오기. 코드가 틀리면 false(지금 진행은 그대로).
  Future<bool> importCode(String code) async {
    if (code.length > maxCodeLength * 2) return false;
    final c = code.trim().replaceAll(RegExp(r'\s'), '');
    if (c.length > maxCodeLength) return false;
    final m = RegExp(r'^TJ1-([0-9a-f]{4})-([A-Za-z0-9_=-]+)$').firstMatch(c);
    if (m == null || _sum(m.group(2)!) != m.group(1)) return false;
    final Profile next;
    try {
      final raw = inflateCapped(base64Url.decode(m.group(2)!), _maxInflated);
      next = Profile.decode(utf8.decode(raw));
    } catch (_) {
      return false;
    }
    final old = profile;
    profile = next;
    if (!await save()) {
      profile = old;
      notifyListeners();
      return false;
    }
    return true;
  }

  /// gzip 을 풀되 [limit] 바이트를 넘으면 멈춘다(작은 코드가 수백 MB 로 불어나는 압축 폭탄 막기).
  @visibleForTesting
  static List<int> inflateCapped(List<int> data, int limit) {
    final out = _CappedSink(limit);
    final conv = gzip.decoder.startChunkedConversion(out);
    const step = 1024;
    for (var i = 0; i < data.length; i += step) {
      conv.add(
        data.sublist(i, i + step > data.length ? data.length : i + step),
      );
    }
    conv.close();
    return out.bytes.takeBytes();
  }

  static String _sum(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0xFFFF;
    }
    return h.toRadixString(16).padLeft(4, '0');
  }

  /// 바꾼 뒤 부른다: 저장하고 화면에 알린다. 쓰기에 실패하면 false.
  /// 저장은 차례대로 한다(겹쳐 쓰다 옛 내용이 나중에 들어가지 않게).
  Future<bool> save() {
    notifyListeners();
    // 시작할 때 저장소를 못 읽었으면 빈 진행으로 진짜 저장을 덮어쓰지 않는다(2026-10-14 점검).
    if (_loadFailed) return Future.value(_failed());
    final String text;
    try {
      text = profile.encode();
    } catch (e) {
      // 숫자가 깨져(NaN 등) 글로 못 바꿀 때 — 조용히 넘기지 않는다.
      debugPrint('저장 실패(바꾸기): $e');
      return Future.value(_failed());
    }
    final next = _saving
        .then((_) => _write(text))
        .then((ok) => ok || _failed());
    _saving = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _saving = Future.value();

  /// 시작할 때 저장소를 읽지 못했나([load]).
  bool _loadFailed = false;

  /// 저장에 실패하면 부른다(앱이 「저장하지 못했어요」를 띄운다 · 2026-10-14 점검 — 환생·구매 뒤 조용히 실패해
  /// 다시 켜면 되돌아가 있던 것).
  static void Function()? onSaveFailed;

  static bool _failed() {
    onSaveFailed?.call();
    return false;
  }

  static Future<bool> _write(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prev = prefs.getString(_key);
      // 읽을 수 없는 옛 저장으로 좋은 백업을 덮어쓰지 않는다(2026-10-14 점검).
      if (prev != null && prev != text && _readable(prev)) {
        await prefs.setString(_backupKey, prev);
      }
      return await prefs.setString(_key, text);
    } catch (e) {
      debugPrint('저장 실패: $e');
      return false;
    }
  }

  static bool _readable(String s) {
    try {
      Profile.decode(s);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _CappedSink implements Sink<List<int>> {
  _CappedSink(this.limit);
  final int limit;
  final bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    bytes.add(chunk);
    if (bytes.length > limit) throw const FormatException('백업 코드가 너무 큽니다');
  }

  @override
  void close() {}
}
