import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/flick.dart';

/// 안드로이드가 보낸 손끝 점 하나(창 기준 화소).
class NativePoint {
  const NativePoint(this.t, this.px, this.area);

  /// 시각(초). 안드로이드 이벤트 시각과 같은 기준이라 Flutter 포인터 이벤트 시각과 견줄 수 있다.
  final double t;
  final Offset px;

  /// 닿은 넓이(닿은 길이를 알려 주는 폰은 그 값, 아니면 넓이 비율). 모르면 null.
  final double? area;
}

/// 손끝 한 번의 이벤트(누름·움직임·뗌·취소)와 그 사이에 찍힌 점들.
class NativeTouch {
  const NativeTouch(this.action, this.points);

  /// 0 누름, 1 뗌, 2 움직임, 3 취소 · 손가락 띄움(호버) 9 들어옴, 7 움직임, 10 나감.
  final int action;
  final List<NativePoint> points;

  bool get isDown => action == 0;
  bool get isEnd => action == 1 || action == 3;

  /// 화면에 닿지 않은 손가락(띄움)인가.
  bool get isHover => action == 7 || action == 9 || action == 10;
  bool get isHoverEnd => action == 10;
}

/// 안드로이드에서 손끝 점을 빠짐없이 받는다(MainActivity.dispatchTouchEvent).
///
/// Flutter 는 화면 한 장 사이에 찍힌 점 가운데 마지막 것만 넘겨주므로, 돌을 맞히는 순간을
/// 더 촘촘히 잡으려고 따로 받는다. 받은 모든 손대기의 닿은 넓이는 [TouchProfile.shared] 에 모은다.
/// 안드로이드가 아니면(웹·시험) 아무것도 오지 않고 [active] 는 거짓이다.
class TouchFeed {
  TouchFeed._();
  static final instance = TouchFeed._();

  final _events = StreamController<NativeTouch>.broadcast();
  final _hovers = StreamController<NativeTouch>.broadcast();

  /// 이 폰에서 받은 손가락 띄움 점 수(설정의 센서 점검이 보여 준다). 0 이면 이 폰은 띄움을 못 알리거나
  /// 아직 손가락을 띄워 움직여 보지 않았다.
  int hoverPoints = 0;

  /// 닿지 않은 손가락(띄움) 이벤트.
  Stream<NativeTouch> get hovers => _hovers.stream;
  bool _active = false;
  StreamSubscription<dynamic>? _sub;

  /// 안드로이드에서 손끝 점이 한 번이라도 왔는가.
  bool get active => _active;

  Stream<NativeTouch> get events => _events.stream;

  void start() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _sub ??= const EventChannel('tanji/touch')
        .receiveBroadcastStream()
        .listen(_on, onError: (Object _) {});
  }

  /// 안드로이드가 보낸 묶음을 읽는다: [동작, 점 수, (시각ms, x, y, 닿은 길이, 넓이 비율, 누른 힘) × 점 수].
  @visibleForTesting
  static NativeTouch? parse(Object? data) {
    if (data is! Float64List || data.length < 2) return null;
    final n = data[1].toInt();
    if (n < 1 || data.length < 2 + n * 6) return null;
    final pts = <NativePoint>[];
    for (var i = 0; i < n; i++) {
      final k = 2 + i * 6;
      final major = data[k + 3], size = data[k + 4];
      final area = major > 0 ? major : (size > 0 ? size : null);
      pts.add(
        NativePoint(data[k] / 1000, Offset(data[k + 1], data[k + 2]), area),
      );
    }
    return NativeTouch(data[0].toInt(), pts);
  }

  /// 시험: 안드로이드가 보낸 것처럼 묶음 하나를 넣는다.
  @visibleForTesting
  void inject(Object? data) => _on(data);

  void _on(dynamic data) {
    final e = parse(data as Object?);
    if (e == null) return;
    if (e.isHover) {
      hoverPoints += e.points.length;
      _hovers.add(e);
      return;
    }
    _active = true;
    for (final p in e.points) {
      TouchProfile.shared.add(p.area);
    }
    _events.add(e);
  }
}
