package io.github.avrgebro.pitwall

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ClassicBluetoothChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}
