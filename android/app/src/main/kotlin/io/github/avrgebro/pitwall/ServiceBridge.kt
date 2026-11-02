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
 * Android → Dart: `tripStart`, naming the trip's target: the `headUnit`
 * that connected, or the `vehicleId` the app asked for, or neither for any
 * vehicle. `startService` passes the app's target the same way.
 *
 * A trip can be requested before Dart has finished starting, so requests
 * wait until Dart asks for them with `takeTripRequest`.
 */
object ServiceBridge {
    private const val PREFS = "pitwall_service"
    private const val KEY_HEAD_UNITS = "head_unit_addresses"

    // The single head unit of earlier versions; removed on the next
    // configure, which Dart sends at every start.
    private const val KEY_OLD_HEAD_UNIT = "head_unit_address"

    /** A trip asked for before Dart was listening. */
    private class PendingStart(val target: Map<String, String>)

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var dartReady = false
    private var pendingStart: PendingStart? = null

    fun attach(context: Context, messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "pitwall/service").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        val addresses = call.argument<List<String>>("headUnitAddresses").orEmpty()
                        prefs(context).edit()
                            .putStringSet(KEY_HEAD_UNITS, addresses.map { it.uppercase() }.toSet())
                            .remove(KEY_OLD_HEAD_UNIT)
                            .apply()
                        result.success(null)
                    }
                    "startService" -> {
                        TripService.start(
                            context,
                            vehicleId = call.argument<String>("vehicleId"),
                        )
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
                        result.success(pendingStart?.target)
                        pendingStart = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** Whether [address] is a head unit that starts a trip, as set in the app. */
    fun startsTrip(context: Context, address: String): Boolean {
        val prefs = prefs(context)
        val addresses = prefs.getStringSet(KEY_HEAD_UNITS, null)
            ?: setOfNotNull(prefs.getString(KEY_OLD_HEAD_UNIT, null)?.uppercase())
        return address.uppercase() in addresses
    }

    fun requestTripStart(headUnit: String?, vehicleId: String?) = main.post {
        val target = buildMap {
            headUnit?.let { put("headUnit", it) }
            vehicleId?.let { put("vehicleId", it) }
        }
        if (dartReady) {
            channel?.invokeMethod("tripStart", target)
        } else {
            pendingStart = PendingStart(target)
        }
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
