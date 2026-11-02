package io.github.avrgebro.pitwall

import android.content.Intent

/**
 * Which vehicle a trip is for, as named by whatever started it. Matches
 * `TripTarget` in Dart. Both sides write a target as its `kind` and what
 * that kind names, and read it strictly: anything else is a mistake, not a
 * trip for any vehicle.
 */
sealed class TripTarget {
    /** A car's head unit connected. */
    data class HeadUnit(val address: String) : TripTarget()

    /** The app asked for a trip for one vehicle. */
    data class Vehicle(val id: String) : TripTarget()

    /** The app asked for a trip for whichever vehicle's adapter answers. */
    data object AnyVehicle : TripTarget()

    /** The channel arguments Dart reads with `TripTarget.fromArguments`. */
    fun toArguments(): Map<String, String> = when (this) {
        is HeadUnit -> mapOf(KEY_KIND to KIND_HEAD_UNIT, KEY_ADDRESS to address)
        is Vehicle -> mapOf(KEY_KIND to KIND_VEHICLE, KEY_ID to id)
        AnyVehicle -> mapOf(KEY_KIND to KIND_ANY)
    }

    /** Puts this target in a service start [intent]; see [from]. */
    fun putIn(intent: Intent): Intent {
        toArguments().forEach { (key, value) -> intent.putExtra(key, value) }
        return intent
    }

    companion object {
        private const val KEY_KIND = "kind"
        private const val KEY_ADDRESS = "address"
        private const val KEY_ID = "id"
        private const val KIND_HEAD_UNIT = "headUnit"
        private const val KIND_VEHICLE = "vehicle"
        private const val KIND_ANY = "any"

        /** The target [putIn] put in [intent], or null if there isn't one. */
        fun from(intent: Intent?): TripTarget? {
            val extras = intent?.extras ?: return null
            return fromArguments(extras.keySet().associateWith { extras.getString(it) })
        }

        /** The target in channel [arguments] from Dart, or null if they aren't one. */
        fun fromArguments(arguments: Map<*, *>?): TripTarget? {
            if (arguments == null) return null
            val address = arguments[KEY_ADDRESS] as? String
            val id = arguments[KEY_ID] as? String
            return when (arguments[KEY_KIND]) {
                KIND_HEAD_UNIT -> address?.takeIf { arguments.size == 2 }?.let(::HeadUnit)
                KIND_VEHICLE -> id?.takeIf { arguments.size == 2 }?.let(::Vehicle)
                KIND_ANY -> AnyVehicle.takeIf { arguments.size == 1 }
                else -> null
            }
        }
    }
}
