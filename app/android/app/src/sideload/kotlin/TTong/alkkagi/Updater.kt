package TTong.alkkagi

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlin.concurrent.thread

/**
 * 시험판 스스로 업데이트.
 *
 * 내려받은 APK 를 PackageInstaller 세션에 바로 써서 설치한다. 안드로이드 12(API 31) 이상에서
 * 자기 자신을 업데이트하고 UPDATE_PACKAGES_WITHOUT_USER_ACTION 을 선언했으면 「설치」를 누르지
 * 않아도 된다(공식 문서 PackageInstaller.SessionParams#setRequireUserAction). 그 아래 판이나
 * 시스템이 확인을 요구하면 확인 창을 띄운다(STATUS_PENDING_USER_ACTION).
 */
object Updater {
    private const val CHANNEL = "tanji/updater"
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null

    fun register(activity: Activity, engine: FlutterEngine) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        val ctx = activity.applicationContext
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(true)
                // 「출처를 알 수 없는 앱 설치」를 이 앱에 허용했는가(처음 한 번 형이 켠다).
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < 26 || ctx.packageManager.canRequestPackageInstalls()
                )
                "openPermission" -> {
                    val i = Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:${ctx.packageName}"),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(i)
                    result.success(null)
                }
                "install" -> {
                    val url = call.argument<String>("url")
                    val sha = call.argument<String>("sha256")
                    val size = (call.argument<Number>("size") ?: 0).toLong()
                    if (url == null || !ours(url) || sha == null || sha.length != 64 || size <= 0) {
                        result.error("bad", "url·지문·크기 없음", null)
                    } else {
                        result.success(null)
                        thread(name = "tanji-updater") { install(ctx, url, sha, size) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** 우리 저장소 깃허브 릴리스(https)만 받는다 — 다트 쪽 검사를 한 번 더(2026-10-14 점검). */
    private fun ours(url: String): Boolean {
        val u = try {
            java.net.URI(url)
        } catch (_: Throwable) {
            return false
        }
        return u.scheme == "https" && u.host == "github.com" &&
            (u.path ?: "").lowercase().startsWith("/ttong627/ttong_alkkagi/releases/download/")
    }

    private fun send(method: String, arg: Any?) {
        main.post { channel?.invokeMethod(method, arg) }
    }

    fun failed(message: String) = send("failed", message)

    /**
     * 받으면서 SHA-256 을 세고, 크기가 version.json 과 다르거나 지문이 다르면 설치하지 않는다
     * (세션을 버린다 · 2026-10-11 점검: 예전엔 https 면 무엇이든 그대로 설치 세션에 썼다).
     */
    private fun install(ctx: Context, url: String, sha256: String, size: Long) {
        var sessionId = -1
        var conn: HttpURLConnection? = null
        try {
            val installer = ctx.packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            params.setAppPackageName(ctx.packageName)
            if (Build.VERSION.SDK_INT >= 31) {
                params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
            sessionId = installer.createSession(params)
            installer.openSession(sessionId).use { session ->
                val http = (URL(url).openConnection() as HttpURLConnection).also { conn = it }
                http.instanceFollowRedirects = true
                http.connectTimeout = 15000
                http.readTimeout = 30000
                http.connect()
                if (http.responseCode !in 200..299) throw IllegalStateException("HTTP ${http.responseCode}")
                val total = size
                val digest = MessageDigest.getInstance("SHA-256")
                http.inputStream.use { input ->
                    session.openWrite("base.apk", 0, total).use { out ->
                        val buf = ByteArray(64 * 1024)
                        var done = 0L
                        var lastPct = -1
                        while (true) {
                            val n = input.read(buf)
                            if (n < 0) break
                            done += n
                            if (done > total) throw IllegalStateException("파일이 예상보다 큽니다")
                            digest.update(buf, 0, n)
                            out.write(buf, 0, n)
                            if (total > 0) {
                                val pct = (done * 100 / total).toInt()
                                if (pct != lastPct) {
                                    lastPct = pct
                                    send("progress", pct)
                                }
                            }
                        }
                        session.fsync(out)
                        if (done != total) throw IllegalStateException("파일 크기가 다릅니다($done/$total)")
                    }
                }
                val got = digest.digest().joinToString("") { "%02x".format(it) }
                if (!got.equals(sha256, ignoreCase = true)) throw IllegalStateException("파일 지문이 다릅니다")
                send("installing", null)
                var flags = PendingIntent.FLAG_UPDATE_CURRENT
                // 시스템이 결과를 넣어 보내므로 바뀔 수 있는 PendingIntent 여야 한다.
                if (Build.VERSION.SDK_INT >= 31) flags = flags or PendingIntent.FLAG_MUTABLE
                val pi = PendingIntent.getBroadcast(
                    ctx,
                    sessionId,
                    Intent(ctx, InstallResultReceiver::class.java),
                    flags,
                )
                session.commit(pi.intentSender)
            }
        } catch (e: Throwable) {
            // 메모리 부족 같은 Error 도 잡는다 — 받는 스레드에서 못 잡으면 앱이 꺼진다(2026-10-14 점검).
            if (sessionId >= 0) {
                try {
                    ctx.packageManager.packageInstaller.abandonSession(sessionId)
                } catch (_: Throwable) {
                }
            }
            failed(e.message ?: e.javaClass.simpleName)
        } finally {
            conn?.disconnect()
        }
    }
}

/** 설치 결과. 확인이 필요하면 확인 창을 띄우고, 실패하면 화면에 알린다. 성공하면 앱이 새 판으로 바뀐다. */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                if (confirm != null) {
                    confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        context.startActivity(confirm)
                    } catch (e: Throwable) {
                        Updater.failed(e.message ?: "설치 확인 창을 열지 못했습니다")
                    }
                }
            }
            PackageInstaller.STATUS_SUCCESS -> Unit
            else -> {
                val msg = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                Updater.failed("설치 실패($status) ${msg ?: ""}".trim())
            }
        }
    }
}
