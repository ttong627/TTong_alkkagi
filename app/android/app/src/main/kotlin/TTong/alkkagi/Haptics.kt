package TTong.alkkagi

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 손맛 진동(2026-10-11 형 「손맛이 조금 더 전해지도록 진동」): 길이와 세기를 정해 떨린다.
 * 플러터 기본 햅틱은 세 단계뿐이라 돌이 부딪힌 빠르기만큼 떨 수 없었다.
 *  - pulse {ms, amp(1~255)}       한 번
 *  - pattern {ms:[…], amp:[…]}    여러 번(쉬는 칸은 amp 0)
 * 세기 조절이 안 되는 폰(진폭 미지원)은 길이만 맞춘다.
 */
object Haptics {
    fun register(context: Context, engine: FlutterEngine) {
        val vib: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "tanji/haptic").setMethodCallHandler { call, result ->
            val v = vib
            if (v == null || !v.hasVibrator()) {
                result.success(false)
                return@setMethodCallHandler
            }
            try {
                when (call.method) {
                    "pulse" -> {
                        val ms = (call.argument<Int>("ms") ?: 20).coerceIn(1, 1000).toLong()
                        val amp = (call.argument<Int>("amp") ?: 128).coerceIn(1, 255)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            v.vibrate(VibrationEffect.createOneShot(ms, if (v.hasAmplitudeControl()) amp else VibrationEffect.DEFAULT_AMPLITUDE))
                        } else {
                            @Suppress("DEPRECATION")
                            v.vibrate(ms)
                        }
                        result.success(true)
                    }
                    "pattern" -> {
                        val ms = (call.argument<List<Int>>("ms") ?: emptyList()).map { it.coerceIn(0, 1000).toLong() }
                        val amp = (call.argument<List<Int>>("amp") ?: emptyList()).map { it.coerceIn(0, 255) }
                        if (ms.isEmpty() || ms.size != amp.size) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val a = if (v.hasAmplitudeControl()) amp.toIntArray()
                            else amp.map { if (it > 0) VibrationEffect.DEFAULT_AMPLITUDE else 0 }.toIntArray()
                            v.vibrate(VibrationEffect.createWaveform(ms.toLongArray(), a, -1))
                        } else {
                            // 옛 폰: 쉬는 칸·떠는 칸을 번갈아(첫 칸은 쉼).
                            val t = ArrayList<Long>()
                            t.add(0)
                            for (i in ms.indices) {
                                val on = amp[i] > 0
                                if ((t.size % 2 == 1) == on) t.add(ms[i]) else t[t.size - 1] = t[t.size - 1] + ms[i]
                            }
                            @Suppress("DEPRECATION")
                            v.vibrate(t.toLongArray(), -1)
                        }
                        result.success(true)
                    }
                    "cancel" -> {
                        v.cancel()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }
}
