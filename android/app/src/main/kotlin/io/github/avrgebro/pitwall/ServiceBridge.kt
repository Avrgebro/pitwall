package io.github.avrgebro.pitwall

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Connects the trip controller in Dart and the trip service: Dart calls
 * [TripServiceApi], and trips Android starts go to Dart through
 * [TripStartApi].
 *
 * A trip can be requested before Dart has finished starting, so requests
 * wait until Dart asks for them with `takeTripRequest`.
 */
object ServiceBridge {
    private const val PREFS = "pitwall_service"
    private const val KEY_HEAD_UNITS = "head_unit_addresses"

    private val main = Handler(Looper.getMainLooper())
    private var dart: TripStartApi? = null
    private var dartReady = false

    /** A trip asked for before Dart was listening. */
    private var pendingStart: TripTarget? = null

    fun attach(context: Context, messenger: BinaryMessenger) {
        dart = TripStartApi(messenger)
        TripServiceApi.setUp(messenger, Api(context.applicationContext))
    }

    /** Whether [address] is a head unit that starts a trip, as set in the app. */
    fun startsTrip(context: Context, address: String): Boolean =
        address.uppercase() in prefs(context).getStringSet(KEY_HEAD_UNITS, emptySet()).orEmpty()

    fun requestTripStart(target: TripTarget) = main.post {
        val dart = dart
        if (dartReady && dart != null) {
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    dart.tripStart(target.toMessage())
                } catch (e: FlutterError) {
                    Log.w("Pitwall", "Dart didn't take the trip start: ${e.code}")
                }
            }
        } else {
            pendingStart = target
        }
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private class Api(private val context: Context) : TripServiceApi {
        override fun configure(headUnitAddresses: List<String>) {
            prefs(context).edit()
                .putStringSet(KEY_HEAD_UNITS, headUnitAddresses.map { it.uppercase() }.toSet())
                .apply()
        }

        override fun startService(target: TripTargetMessage) {
            val trip = TripTarget.fromApp(target)
                ?: throw FlutterError("bad_target", "Not a trip the app can ask for")
            TripService.start(context, trip)
        }

        override fun stopService() = TripService.stop(context)

        override fun updateNotification(text: String) =
            TripService.updateNotification(context, text)

        override fun takeTripRequest(): TripTargetMessage? {
            dartReady = true
            val pending = pendingStart
            pendingStart = null
            return pending?.toMessage()
        }
    }
}
