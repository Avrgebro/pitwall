package io.github.avrgebro.pitwall

import android.content.Intent

/**
 * Which vehicle a trip is for, as named by whatever started it. Matches
 * `TripTarget` in Dart, which it reaches as a [TripTargetMessage]: read
 * strictly on both sides, so anything else is a mistake, not a trip for any
 * vehicle.
 */
sealed class TripTarget {
    /** A car's head unit connected. */
    data class HeadUnit(val address: String) : TripTarget()

    /** The app asked for a trip for one vehicle. */
    data class Vehicle(val id: String) : TripTarget()

    /** The app asked for a trip for whichever vehicle's adapter answers. */
    data object AnyVehicle : TripTarget()

    fun toMessage(): TripTargetMessage = when (this) {
        is HeadUnit -> TripTargetMessage(kind = TripTargetKind.HEAD_UNIT, address = address)
        is Vehicle -> TripTargetMessage(kind = TripTargetKind.VEHICLE, vehicleId = id)
        AnyVehicle -> TripTargetMessage(kind = TripTargetKind.ANY_VEHICLE)
    }

    /** Puts this target in a service start [intent]; see [from]. */
    fun putIn(intent: Intent): Intent {
        val message = toMessage()
        return intent
            .putExtra(KEY_KIND, message.kind.name)
            .putExtra(KEY_ADDRESS, message.address)
            .putExtra(KEY_VEHICLE_ID, message.vehicleId)
    }

    companion object {
        private const val KEY_KIND = "kind"
        private const val KEY_ADDRESS = "address"
        private const val KEY_VEHICLE_ID = "vehicleId"

        /** The target [putIn] put in [intent], or null if there isn't one. */
        fun from(intent: Intent?): TripTarget? {
            if (intent == null) return null
            val kind = intent.getStringExtra(KEY_KIND)
                ?.let { name -> TripTargetKind.entries.find { it.name == name } }
                ?: return null
            return fromMessage(
                TripTargetMessage(
                    kind = kind,
                    address = intent.getStringExtra(KEY_ADDRESS),
                    vehicleId = intent.getStringExtra(KEY_VEHICLE_ID),
                ),
            )
        }

        /**
         * What the app asks for: one vehicle or any, or null otherwise. Only
         * a head unit names itself, so the app never asks for one.
         */
        fun fromApp(message: TripTargetMessage): TripTarget? =
            when (val target = fromMessage(message)) {
                is Vehicle, AnyVehicle -> target
                is HeadUnit, null -> null
            }

        /** The target [message] names, or null if it names one wrongly. */
        private fun fromMessage(message: TripTargetMessage): TripTarget? =
            when (message.kind) {
                TripTargetKind.HEAD_UNIT ->
                    message.address?.takeIf { message.vehicleId == null }?.let(::HeadUnit)
                TripTargetKind.VEHICLE ->
                    message.vehicleId?.takeIf { message.address == null }?.let(::Vehicle)
                TripTargetKind.ANY_VEHICLE ->
                    AnyVehicle.takeIf { message.address == null && message.vehicleId == null }
            }
    }
}
