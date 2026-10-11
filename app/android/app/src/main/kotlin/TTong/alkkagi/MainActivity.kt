package TTong.alkkagi

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 시험판(sideload)은 스스로 업데이트하고, 스토어 판(play)은 아무것도 하지 않는다.
        Updater.register(this, flutterEngine)
    }
}
