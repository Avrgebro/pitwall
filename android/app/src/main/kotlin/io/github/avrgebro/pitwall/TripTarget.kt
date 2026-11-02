package io.github.avrgebro.pitwall

import android.content.Intent

/**
 * Which vehicle a trip is for, as named by whatever started it. Matches
 * `TripTarget` in Dart, which it reaches as [toArguments].
 */
sealed class TripTarget {
    /** A car's head unit connected. */
    data class HeadUnit(val address: String) : TripTarget()

    /** The app asked for a trip for one vehicle. */
    data class Vehicle(val id: String) : TripTarget()

    /** The app asked for a trip for whichever vehicle's adapter answers. */
    data object AnyVehicle : TripTarget()

    /** The channel arguments Dart decodes. */
    fun toArguments(): Map<String, String> = when (this) {
        is HeadUnit -> mapOf(KEY_HEAD_UNIT to address)
        is Vehicle -> mapOf(KEY_VEHICLE_ID to id)
        AnyVehicle -> emptyMap()
    }

    /** Puts this target in a service start [intent]; see [from]. */
    fun putIn(intent: Intent): Intent = when (this) {
        is HeadUnit -> intent.putExtra(KEY_HEAD_UNIT, address)
        is Vehicle -> intent.putExtra(KEY_VEHICLE_ID, id)
        AnyVehicle -> intent
    }

    companion object {
        private const val KEY_HEAD_UNIT = "headUnit"
        private const val KEY_VEHICLE_ID = "vehicleId"

        /** The target [putIn] put in [intent]. */
        fun from(intent: Intent?): TripTarget =
            intent?.getStringExtra(KEY_HEAD_UNIT)?.let(::HeadUnit)
                ?: intent?.getStringExtra(KEY_VEHICLE_ID)?.let(::Vehicle)
                ?: AnyVehicle

        /** What the app can ask for: one vehicle, or any. */
        fun fromApp(vehicleId: String?): TripTarget = vehicleId?.let(::Vehicle) ?: AnyVehicle
    }
}
