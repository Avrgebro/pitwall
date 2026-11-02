package io.github.avrgebro.pitwall

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * The one Flutter engine, shared by the app's screen and the trip service.
 *
 * Whichever starts first creates it; the other attaches to it. That way the
 * trip runs in the same Dart code and state the screen shows, with a single
 * delivery queue.
 */
object EngineHolder {
    private const val ENGINE_ID = "pitwall"

    @Synchronized
    fun get(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }
        val appContext = context.applicationContext
        // Plugins register themselves when the engine is created.
        val engine = FlutterEngine(appContext)
        val messenger = engine.dartExecutor.binaryMessenger
        ClassicBluetoothChannel(appContext, messenger)
        BluetoothStateChannel(appContext, messenger)
        ServiceBridge.attach(appContext, messenger)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }
}
