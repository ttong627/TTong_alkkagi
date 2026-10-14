import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱이 갑자기 꺼진 까닭(2026-10-14 형 「갤럭시 울트라22 … 자꾸 튕기는 증상」).
///
/// 폰에서만 일어나는 꺼짐은 코드만 보고 원인을 확정할 수 없다 → 안드로이드가 적어 둔 「지난번 끝난 까닭」
/// (`tanji/diag` · Diag.kt)과 최근 Dart 오류를 모아, 비정상으로 꺼졌으면 다음에 켤 때 한 번 보여 준다.
/// 밖으로 보내지 않는다 — 형이 「복사」해서 전해 준다.
abstract final class CrashLog {
  static const _ch = MethodChannel('tanji/diag');
  static const _seenKey = 'diag.seenExit';
  static const _errorsKey = 'diag.dartErrors';
  static const _reportKey = 'diag.lastReport';

  /// 남겨 두는 Dart 오류 수 · 하나의 최대 길이.
  static const keep = 5, maxLength = 1500;

  /// Dart 오류를 적어 두기 시작한다(원래 처리는 그대로).
  static void install() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      note(d.exceptionAsString(), d.stack);
      prev?.call(d);
    };
    final prevAsync = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (e, s) {
      note('$e', s);
      return prevAsync?.call(e, s) ?? false;
    };
  }

  /// 바로 앞에 적은 오류 · 이번 실행에 적은 수 · 차례 — 매 장면 되풀이되는 오류가 저장소를 두드리지 않게
  /// (같은 것은 건너뛰고 한 번 실행에 [maxPerRun] 개까지 · 차례대로 써서 서로 덮지 않게 · 2026-10-14 점검).
  static String? _last;
  static int _written = 0;
  static const maxPerRun = 20;
  static Future<void> _chain = Future.value();

  /// 오류 하나를 적는다(최근 [keep] 개).
  static Future<void> note(String error, StackTrace? stack) {
    if (error == _last || _written >= maxPerRun) return Future.value();
    _last = error;
    _written++;
    return _chain = _chain.then((_) => _write(error, stack));
  }

  static Future<void> _write(String error, StackTrace? stack) async {
    final lines = (stack?.toString() ?? '').split('\n').take(12).join('\n');
    final entry = '${DateTime.now().toIso8601String()} $error\n$lines';
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_errorsKey) ?? [];
      final next = [
        ...list,
        entry.length > maxLength ? entry.substring(0, maxLength) : entry,
      ];
      await prefs.setStringList(
        _errorsKey,
        next.length > keep ? next.sublist(next.length - keep) : next,
      );
    } catch (_) {}
  }

  /// 지난번에 비정상으로 꺼졌으면 그 까닭(한 번만 · 이미 본 것이면 null). 안드로이드가 아니면 null.
  static Future<String?> pendingReport() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final m = await _ch.invokeMapMethod<String, Object?>('lastExit');
      if (m == null || m['abnormal'] != true) return null;
      final time = (m['time'] as num?)?.toInt() ?? 0;
      final prefs = await SharedPreferences.getInstance();
      if (time <= (prefs.getInt(_seenKey) ?? 0)) return null;
      final errors = prefs.getStringList(_errorsKey) ?? const [];
      final report = [
        '${m['text'] ?? ''}'.trim(),
        if (errors.isNotEmpty)
          '최근 앱 안 오류 ${errors.length}개:\n${errors.join('\n---\n')}',
      ].join('\n\n');
      await prefs.setInt(_seenKey, time);
      await prefs.setString(_reportKey, report);
      // 보고에 실은 오류는 비운다(다음 꺼짐 보고에 옛 오류가 섞이지 않게).
      await prefs.remove(_errorsKey);
      return report;
    } catch (_) {
      return null;
    }
  }

  /// 마지막으로 보여 준 꺼짐 기록(설정에서 다시 볼 때 · 없으면 null).
  static Future<String?> lastReport() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_reportKey);
    } catch (_) {
      return null;
    }
  }
}
