package io.github.avrgebro.pitwall

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Talks to the trip controller in Dart over `pitwall/service`.
 *
 * Dart → Android: `configure`, `startService`, `stopService`,
 * `updateNotification`, `takeTripRequest`.
 * Android → Dart: `tripStart`, `tripStop`.
 *
 * A trip can be requested before Dart has finished starting, so requests
 * wait until Dart asks for them with `takeTripRequest`.
 */
object ServiceBridge {
    private const val PREFS = "pitwall_service"
    private const val KEY_HEAD_UNIT = "head_unit_address"

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var dartReady = false
    private var pendingStart = false

    fun attach(context: Context, messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "pitwall/service").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        prefs(context).edit()
                            .putString(KEY_HEAD_UNIT, call.argument<String>("headUnitAddress"))
                            .apply()
                        result.success(null)
                    }
                    "startService" -> {
                        TripService.start(context)
                        result.success(null)
                    }
                    "stopService" -> {
                        TripService.stop(context)
                        result.success(null)
                    }
                    "updateNotification" -> {
                        TripService.updateNotification(context, call.argument<String>("text") ?: "")
                        result.success(null)
                    }
                    "takeTripRequest" -> {
                        dartReady = true
                        result.success(pendingStart)
                        pendingStart = false
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** The head unit whose connection starts a trip, as set in the app. */
    fun headUnitAddress(context: Context): String? =
        prefs(context).getString(KEY_HEAD_UNIT, null)

    fun requestTripStart() = main.post {
        if (dartReady) channel?.invokeMethod("tripStart", null) else pendingStart = true
    }

    fun requestTripStop() = main.post {
        pendingStart = false
        if (dartReady) channel?.invokeMethod("tripStop", null)
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
