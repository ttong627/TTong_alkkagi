package TTong.alkkagi

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 앱이 갑자기 꺼진 까닭(2026-10-14 형 「갤럭시 울트라22 … 자꾸 튕기는 증상」).
 * 폰에서만 일어나 코드만 보고는 원인을 확정할 수 없어서, 다음에 켤 때 까닭을 보여 주고 복사하게 한다.
 *  - 잡히지 않은 자바 예외: 꺼지기 직전에 파일로 적는다([install]).
 *  - 안드로이드 11+ 가 적어 두는 「지난번 끝난 까닭」(응답 없음·네이티브 충돌·메모리 부족 …)과 그때의 기록 일부.
 * 밖으로 보내지 않는다 — 화면에 보여 주기만 한다.
 */
object Diag {
    private const val CRASH_FILE = "last_java_crash.txt"
    private const val MAX_TRACE = 4000
    private var installed = false

    /** 잡히지 않은 자바 예외를 파일에 적고 원래 처리기로 넘긴다(앱은 그대로 꺼진다). 한 번만 건다. */
    fun install(context: Context) {
        if (installed) return
        installed = true
        val dir = context.applicationContext.filesDir
        val prev = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { t, e ->
            try {
                File(dir, CRASH_FILE).writeText(
                    "자바 예외 · 스레드 ${t.name} · ${stamp(System.currentTimeMillis())}\n" +
                        Log.getStackTraceString(e).take(MAX_TRACE),
                )
            } catch (_: Throwable) {
            }
            prev?.uncaughtException(t, e)
        }
    }

    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "tanji/diag").setMethodCallHandler { call, result ->
            when (call.method) {
                "lastExit" -> result.success(
                    try {
                        lastExit(context)
                    } catch (e: Throwable) {
                        mapOf("time" to 0L, "abnormal" to false, "text" to "읽기 실패: $e")
                    },
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun stamp(ms: Long) =
        SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.KOREA).format(Date(ms))

    /** 지난번 끝난 까닭: {time(ms), abnormal, text}. */
    private fun lastExit(context: Context): Map<String, Any?> {
        val pm = context.packageManager
        val build = try {
            val pi = pm.getPackageInfo(context.packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) pi.longVersionCode else {
                @Suppress("DEPRECATION")
                pi.versionCode.toLong()
            }
        } catch (_: Throwable) {
            -1L
        }
        val head = StringBuilder()
            .append("알까기 시험판 ").append(build)
            .append(" · ").append(Build.MANUFACTURER).append(' ').append(Build.MODEL)
            .append(" · 안드로이드 ").append(Build.VERSION.RELEASE).append(" (API ").append(Build.VERSION.SDK_INT).append(")\n")
        val crashFile = File(context.filesDir, CRASH_FILE)
        var time = 0L
        var java: String? = null
        if (crashFile.exists()) {
            time = crashFile.lastModified()
            java = crashFile.readText()
            crashFile.delete()
        }
        var abnormal = java != null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val am = context.getSystemService(ActivityManager::class.java)
            val info = am?.getHistoricalProcessExitReasons(context.packageName, 0, 1)?.firstOrNull()
            if (info != null) {
                time = maxOf(time, info.timestamp)
                val (name, bad) = reasonOf(info)
                abnormal = abnormal || bad
                head.append("끝난 때 ").append(stamp(info.timestamp))
                    .append(" · 까닭 ").append(name)
                    .append(" · 상태 ").append(info.status)
                    .append(" · 중요도 ").append(info.importance)
                    .append(" · 메모리 ").append(info.pss / 1024).append("MB/").append(info.rss / 1024).append("MB\n")
                info.description?.let { head.append("설명: ").append(it).append('\n') }
                if (bad) traceOf(info)?.let { head.append("기록:\n").append(it).append('\n') }
            }
        }
        if (java != null) head.append(java)
        return mapOf("time" to time, "abnormal" to abnormal, "text" to head.toString())
    }

    /** 까닭 이름과 「비정상인가」. 화면에 보이던 중 강제로 죽은 것(신호)도 비정상으로 본다. */
    @RequiresApi(Build.VERSION_CODES.R)
    private fun reasonOf(info: ApplicationExitInfo): Pair<String, Boolean> {
        val visible = info.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
        return when (info.reason) {
            ApplicationExitInfo.REASON_ANR -> "응답 없음(ANR)" to true
            ApplicationExitInfo.REASON_CRASH -> "자바 예외" to true
            ApplicationExitInfo.REASON_CRASH_NATIVE -> "네이티브 충돌" to true
            ApplicationExitInfo.REASON_LOW_MEMORY -> "메모리 부족" to true
            ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "자원 과다" to true
            ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "시작 실패" to true
            ApplicationExitInfo.REASON_SIGNALED -> "신호로 끝남" to visible
            ApplicationExitInfo.REASON_EXIT_SELF -> "스스로 끝냄" to false
            ApplicationExitInfo.REASON_USER_REQUESTED -> "사용자가 끝냄" to false
            ApplicationExitInfo.REASON_USER_STOPPED -> "사용자가 멈춤" to false
            else -> "기타(${info.reason})" to false
        }
    }

    /**
     * 그때의 기록 앞부분. 응답 없음은 글(스레드 스택)이고, 네이티브 충돌은 이진 기록이라 읽을 수 있는 글자만 뽑는다
     * (신호 번호·함수 이름·라이브러리 이름이 남는다).
     */
    @RequiresApi(Build.VERSION_CODES.R)
    private fun traceOf(info: ApplicationExitInfo): String? {
        val bytes = try {
            // 앞 256KB 만(응답 없음 기록은 수 MB 일 수 있다 — 화면 스레드에서 읽는다 · 2026-10-14 점검).
            info.traceInputStream?.use { input ->
                val out = java.io.ByteArrayOutputStream()
                val buf = ByteArray(16 * 1024)
                while (out.size() < 256 * 1024) {
                    val n = input.read(buf)
                    if (n < 0) break
                    out.write(buf, 0, n)
                }
                out.toByteArray()
            }
        } catch (_: Throwable) {
            null
        } ?: return null
        val text = if (info.reason == ApplicationExitInfo.REASON_CRASH_NATIVE) {
            val runs = StringBuilder()
            val cur = StringBuilder()
            for (b in bytes) {
                val c = b.toInt() and 0xff
                if (c in 32..126) {
                    cur.append(c.toChar())
                } else {
                    if (cur.length >= 6) runs.append(cur).append('\n')
                    cur.setLength(0)
                }
                if (runs.length > MAX_TRACE) break
            }
            runs.toString()
        } else {
            val all = String(bytes)
            // 응답 없음: 화면 스레드("main") 스택이 핵심.
            val at = all.indexOf("\"main\"")
            if (at >= 0) all.substring(at) else all
        }
        return text.take(MAX_TRACE)
    }
}
