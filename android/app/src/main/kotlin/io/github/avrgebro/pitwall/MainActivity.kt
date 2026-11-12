package io.github.avrgebro.pitwall

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /** Asks Android to watch for adapters, which needs this screen. */
    private var companion: CompanionChannel? = null

    // Shares the engine with the trip service instead of creating its own.
    override fun provideFlutterEngine(context: Context): FlutterEngine = EngineHolder.get(context)

    // A trip may still be running when the screen closes.
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        companion = CompanionChannel(this).also {
            CompanionApi.setUp(flutterEngine.dartExecutor.binaryMessenger, it)
        }
        ShareApi.setUp(flutterEngine.dartExecutor.binaryMessenger, ShareChannel(this))
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CompanionApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        ShareApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        companion = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    @Deprecated("Activity results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        companion?.onResult(requestCode, resultCode)
    }
}
