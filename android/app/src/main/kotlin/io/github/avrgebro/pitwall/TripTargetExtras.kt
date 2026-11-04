package io.github.avrgebro.pitwall

import android.content.Intent

/**
 * How a [TripTargetMessage] travels in the intent that starts
 * [TripService]. The message is the target itself, the same sealed type
 * Dart gets, so nothing on this side reads one strictly or loosely.
 */
object TripTargetExtras {
    private const val KEY_HEAD_UNIT = "headUnit"
    private const val KEY_VEHICLE = "vehicle"
    private const val KEY_ANY_VEHICLE = "anyVehicle"

    /** Puts [target] in [intent]; see [from]. */
    fun putIn(intent: Intent, target: TripTargetMessage): Intent = when (target) {
        is HeadUnitMessage -> intent.putExtra(KEY_HEAD_UNIT, target.address)
        is AppRequestMessage -> when (val request = target.target) {
            is VehicleMessage -> intent.putExtra(KEY_VEHICLE, request.id)
            is AnyVehicleMessage -> intent.putExtra(KEY_ANY_VEHICLE, true)
        }
    }

    /**
     * The target [putIn] put in [intent], or null for an intent without
     * one, as when Android restarts the service.
     */
    fun from(intent: Intent?): TripTargetMessage? {
        if (intent == null) return null
        intent.getStringExtra(KEY_HEAD_UNIT)?.let { return HeadUnitMessage(it) }
        intent.getStringExtra(KEY_VEHICLE)?.let { return AppRequestMessage(VehicleMessage(it)) }
        if (intent.getBooleanExtra(KEY_ANY_VEHICLE, false)) {
            return AppRequestMessage(AnyVehicleMessage())
        }
        return null
    }
}
