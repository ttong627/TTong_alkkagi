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
                    if (url == null) {
                        result.error("bad", "url 없음", null)
                    } else {
                        result.success(null)
                        thread(name = "tanji-updater") { install(ctx, url) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun send(method: String, arg: Any?) {
        main.post { channel?.invokeMethod(method, arg) }
    }

    fun failed(message: String) = send("failed", message)

    private fun install(ctx: Context, url: String) {
        var sessionId = -1
        try {
            val installer = ctx.packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            params.setAppPackageName(ctx.packageName)
            if (Build.VERSION.SDK_INT >= 31) {
                params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
            sessionId = installer.createSession(params)
            installer.openSession(sessionId).use { session ->
                val conn = URL(url).openConnection() as HttpURLConnection
                conn.instanceFollowRedirects = true
                conn.connectTimeout = 15000
                conn.readTimeout = 30000
                conn.connect()
                if (conn.responseCode !in 200..299) throw IllegalStateException("HTTP ${conn.responseCode}")
                val total = conn.contentLengthLong
                conn.inputStream.use { input ->
                    session.openWrite("base.apk", 0, total).use { out ->
                        val buf = ByteArray(64 * 1024)
                        var done = 0L
                        var lastPct = -1
                        while (true) {
                            val n = input.read(buf)
                            if (n < 0) break
                            out.write(buf, 0, n)
                            done += n
                            if (total > 0) {
                                val pct = (done * 100 / total).toInt()
                                if (pct != lastPct) {
                                    lastPct = pct
                                    send("progress", pct)
                                }
                            }
                        }
                        session.fsync(out)
                    }
                }
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
        } catch (e: Exception) {
            if (sessionId >= 0) {
                try {
                    ctx.packageManager.packageInstaller.abandonSession(sessionId)
                } catch (_: Exception) {
                }
            }
            failed(e.message ?: e.javaClass.simpleName)
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
                    context.startActivity(confirm)
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
