package io.github.avrgebro.pitwall

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    // Shares the engine with the trip service instead of creating its own.
    override fun provideFlutterEngine(context: Context): FlutterEngine = EngineHolder.get(context)

    // A trip may still be running when the screen closes.
    override fun shouldDestroyEngineWithHost(): Boolean = false
}
