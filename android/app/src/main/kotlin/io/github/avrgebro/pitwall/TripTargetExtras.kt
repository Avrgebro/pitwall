package io.github.avrgebro.pitwall

import android.content.Intent

/**
 * How a [TripTargetMessage] travels in the intent that starts
 * [TripService]: one extra, its [Kind] and what it names. Writing goes
 * through a `when` over every message, reading through a `when` over every
 * [Kind], so a new kind doesn't compile until both handle it.
 */
object TripTargetExtras {
    private const val KEY_TARGET = "tripTarget"

    /** Each kind of target, by the name it travels under. */
    enum class Kind { HEAD_UNIT, ADAPTER, VEHICLE, ANY_VEHICLE }

    /** Puts [target] in [intent]; see [from]. */
    fun putIn(intent: Intent, target: TripTargetMessage): Intent =
        intent.putExtra(KEY_TARGET, encode(target))

    /**
     * The target [putIn] put in [intent], or null for an intent without
     * one, as when Android restarts the service, or with one it can't read.
     */
    fun from(intent: Intent?): TripTargetMessage? =
        intent?.getStringExtra(KEY_TARGET)?.let(::decode)

    fun encode(target: TripTargetMessage): String {
        val (kind, value) = when (target) {
            is HeadUnitMessage -> Kind.HEAD_UNIT to target.address
            is AdapterMessage -> Kind.ADAPTER to target.address
            is AppRequestMessage -> when (val request = target.target) {
                is VehicleMessage -> Kind.VEHICLE to request.id
                is AnyVehicleMessage -> Kind.ANY_VEHICLE to ""
            }
        }
        return "${kind.name}:$value"
    }

    /**
     * What [encode] wrote, or null if it isn't: no kind this version knows,
     * or a kind without the value it needs.
     */
    fun decode(text: String): TripTargetMessage? {
        if (!text.contains(':')) return null
        val kind = Kind.entries.find { it.name == text.substringBefore(':') } ?: return null
        val value = text.substringAfter(':')
        return when (kind) {
            Kind.HEAD_UNIT -> value.takeIf { it.isNotEmpty() }?.let(::HeadUnitMessage)
            Kind.ADAPTER -> value.takeIf { it.isNotEmpty() }?.let(::AdapterMessage)
            Kind.VEHICLE ->
                value.takeIf { it.isNotEmpty() }?.let { AppRequestMessage(VehicleMessage(it)) }
            Kind.ANY_VEHICLE -> AppRequestMessage(AnyVehicleMessage())
        }
    }
}
