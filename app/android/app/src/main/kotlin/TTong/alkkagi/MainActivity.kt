package TTong.alkkagi

import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var touchSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 시험판(sideload)은 스스로 업데이트하고, 스토어 판(play)은 아무것도 하지 않는다.
        Updater.register(this, flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "tanji/touch")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    touchSink = events
                }

                override fun onCancel(arguments: Any?) {
                    touchSink = null
                }
            })
    }

    /**
     * 손끝 움직임을 빠짐없이 Dart 로 보낸다.
     *
     * 안드로이드는 화면 한 장(프레임) 사이에 찍힌 손끝 점들을 한 이벤트에 묶어(history) 주는데,
     * Flutter 는 그중 마지막 점만 쓴다. 돌을 맞히는 순간을 놓치지 않으려고 묶인 점까지 모두 보낸다.
     * 첫 번째 손가락만 보낸다. 보내는 값: [동작, 점 수, (시각ms, x, y, 닿은 길이, 닿은 넓이, 누른 힘) × 점 수].
     * x·y 는 창 기준 화소. 동작은 MotionEvent 의 actionMasked(0 누름, 1 뗌, 2 움직임, 3 취소,
     * 띄움은 아래 [dispatchGenericMotionEvent] — 9 들어옴, 7 움직임, 10 나감).
     */
    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        val action = ev.actionMasked
        if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_MOVE ||
            action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL
        ) {
            send(ev, action)
        }
        return super.dispatchTouchEvent(ev)
    }

    /**
     * 손가락 띄움(호버): 화면에 닿지 않은 손가락을 알려 주는 폰에서만 온다(동작 9 들어옴, 7 움직임, 10 나감).
     * 펜·마우스는 빼고 손가락만 보낸다. 닿지 않고 돌 위를 스친 손놀림 = 돌 위쪽(상단)을 친 것으로 쓴다.
     */
    override fun dispatchGenericMotionEvent(ev: MotionEvent): Boolean {
        val action = ev.actionMasked
        if ((action == MotionEvent.ACTION_HOVER_ENTER || action == MotionEvent.ACTION_HOVER_MOVE ||
                action == MotionEvent.ACTION_HOVER_EXIT) &&
            ev.getToolType(0) == MotionEvent.TOOL_TYPE_FINGER
        ) {
            send(ev, action)
        }
        return super.dispatchGenericMotionEvent(ev)
    }

    private fun send(ev: MotionEvent, action: Int) {
        val sink = touchSink ?: return
        val h = ev.historySize
        val n = h + 1
        val out = DoubleArray(2 + n * 6)
        out[0] = action.toDouble()
        out[1] = n.toDouble()
        var k = 2
        for (i in 0 until h) {
            out[k++] = ev.getHistoricalEventTime(i).toDouble()
            out[k++] = ev.getHistoricalX(0, i).toDouble()
            out[k++] = ev.getHistoricalY(0, i).toDouble()
            out[k++] = ev.getHistoricalTouchMajor(0, i).toDouble()
            out[k++] = ev.getHistoricalSize(0, i).toDouble()
            out[k++] = ev.getHistoricalPressure(0, i).toDouble()
        }
        out[k++] = ev.eventTime.toDouble()
        out[k++] = ev.getX(0).toDouble()
        out[k++] = ev.getY(0).toDouble()
        out[k++] = ev.getTouchMajor(0).toDouble()
        out[k++] = ev.getSize(0).toDouble()
        out[k] = ev.getPressure(0).toDouble()
        sink.success(out)
    }
}
