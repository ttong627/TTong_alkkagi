import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../version.dart';

/// 어느 판인가. CI 가 `--dart-define=APP_CHANNEL=sideload|play` 로 넣는다.
/// sideload(휴대폰 시험판)만 스스로 업데이트한다. play(스토어 판)는 스토어가 업데이트한다.
const appChannel = String.fromEnvironment('APP_CHANNEL', defaultValue: 'dev');

/// 최신 시험판 정보(version.json). CI 의 test-latest 작업이 올린다.
const updateUrl = String.fromEnvironment(
  'UPDATE_URL',
  defaultValue: 'https://github.com/ttong627/TTong_alkkagi/releases/download/test-latest/version.json',
);

/// version.json 내용.
class UpdateInfo {
  const UpdateInfo({
    required this.build,
    required this.apk,
    this.sha256 = '',
    this.size = 0,
    this.notes = '',
  });

  /// APK 를 받을 수 있는 곳(우리 저장소의 깃허브 릴리스).
  static const allowedHosts = {'github.com'};

  /// 빌드 번호(첫 화면 「빌드 N」과 같은 수).
  final int build;

  /// 내려받을 APK 주소.
  final String apk;

  /// 받은 APK 의 SHA-256(소문자 16진수 64자). 맞지 않으면 설치하지 않는다.
  final String sha256;

  /// APK 크기(바이트). 이보다 크게 오면 멈춘다.
  final int size;

  /// 바뀐 점 한 줄.
  final String notes;

  /// 올바른 내용이 아니면 null.
  static UpdateInfo? parse(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map) return null;
      final b = j['build'], a = j['apk'], h = j['sha256'], z = j['size'];
      if (b is! int || a is! String) return null;
      // https · 우리 릴리스 주소만 · 지문과 크기가 있어야 받는다(2026-10-11 점검).
      final u = Uri.tryParse(a);
      if (u == null || u.scheme != 'https' || !allowedHosts.contains(u.host)) {
        return null;
      }
      if (h is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(h)) return null;
      if (z is! int || z <= 0 || z > 300 * 1024 * 1024) return null;
      final n = j['notes'];
      return UpdateInfo(
        build: b,
        apk: a,
        sha256: h,
        size: z,
        notes: n is String ? n : '',
      );
    } on FormatException {
      return null;
    }
  }

  /// 지금 깔린 빌드보다 새것인가.
  bool newerThan(int current) => build > current;
}

/// 업데이트 진행 상태.
enum UpdateStage {
  /// 아무 일 없음(시험판이 아니거나 이미 최신).
  idle,
  checking,

  /// 처음 한 번: 이 앱에 「출처를 알 수 없는 앱 설치」를 허용해야 한다.
  needsPermission,
  downloading,
  installing,
  failed,
}

/// 켤 때 새 판을 확인하고, 있으면 내려받아 스스로 업데이트한다.
class Updater extends ChangeNotifier {
  Updater() {
    _ch.setMethodCallHandler(_onNative);
  }

  static const _ch = MethodChannel('tanji/updater');

  UpdateStage stage = UpdateStage.idle;
  int percent = 0;
  String message = '';
  UpdateInfo? target;

  bool get enabled => appChannel == 'sideload' && !kIsWeb && Platform.isAndroid;

  void _set(UpdateStage s, {String msg = ''}) {
    stage = s;
    message = msg;
    notifyListeners();
  }

  Future<void> _onNative(MethodCall call) async {
    switch (call.method) {
      case 'progress':
        percent = call.arguments as int;
        _set(UpdateStage.downloading);
      case 'installing':
        _set(UpdateStage.installing);
      case 'failed':
        _set(UpdateStage.failed, msg: '${call.arguments}');
    }
  }

  /// 새 판 확인 → 있으면 바로 내려받아 설치(형 요청: 자동 업데이트).
  Future<void> run() async {
    if (!enabled) return;
    if (stage == UpdateStage.downloading || stage == UpdateStage.installing) {
      return;
    }
    final current = int.tryParse(appBuild);
    if (current == null) return;
    _set(UpdateStage.checking);
    final UpdateInfo? info;
    try {
      info = UpdateInfo.parse(await _fetch(updateUrl));
    } catch (_) {
      _set(UpdateStage.idle); // 인터넷이 안 되면 조용히 다음에.
      return;
    }
    if (info == null || !info.newerThan(current)) {
      _set(UpdateStage.idle);
      return;
    }
    target = info;
    final can = await _ch.invokeMethod<bool>('canInstall') ?? false;
    if (!can) {
      _set(UpdateStage.needsPermission);
      return;
    }
    percent = 0;
    _set(UpdateStage.downloading);
    await _ch.invokeMethod<void>('install', {
      'url': info.apk,
      'sha256': info.sha256,
      'size': info.size,
    });
  }

  /// 「출처를 알 수 없는 앱 설치」 설정 화면을 연다. 돌아오면 [resumed] 가 다시 확인한다.
  Future<void> openPermission() => _ch.invokeMethod<void>('openPermission');

  /// 설정에서 돌아왔을 때.
  void resumed() {
    if (stage == UpdateStage.needsPermission) unawaited(run());
  }

  static Future<String> _fetch(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      // 캐시를 피하려고 시각을 붙인다.
      final uri = Uri.parse(url).replace(
        queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
      );
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      return await res.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }
}
