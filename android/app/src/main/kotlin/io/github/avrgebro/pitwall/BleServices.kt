package io.github.avrgebro.pitwall

import java.util.UUID

/** A 16-bit Bluetooth SIG UUID, in full. */
internal fun uuid16(short: Int): UUID =
    UUID.fromString(String.format("%08x-0000-1000-8000-00805f9b34fb", short))

/**
 * The services OBD adapters are known to talk through, in the order tried:
 * the FFF0 and FFE0 serial layouts most clones use, 18F0, and the one
 * Vgate and OBDLink adapters use.
 */
internal val KNOWN_OBD_SERVICES: List<UUID> = listOf(
    uuid16(0xFFF0),
    uuid16(0xFFE0),
    uuid16(0x18F0),
    UUID.fromString("e7810a71-73ae-499d-8c15-faa9aef0c3f2"),
)

/** Generic access, generic attribute, device information, battery. */
internal val STANDARD_SERVICES: Set<UUID> = setOf(0x1800, 0x1801, 0x180A, 0x180F).map(::uuid16).toSet()

/**
 * The order to look for a service to talk through: known OBD services
 * first, as clones often also carry others (firmware updates, vendor
 * links) that can come earlier, then the rest as the adapter lists them.
 * The standard services every device has are left out.
 */
internal fun <S> inTryOrder(services: List<S>, uuidOf: (S) -> UUID): List<S> =
    services
        .filter { uuidOf(it) !in STANDARD_SERVICES }
        .sortedBy { service ->
            KNOWN_OBD_SERVICES.indexOf(uuidOf(service)).let { if (it == -1) KNOWN_OBD_SERVICES.size else it }
        }
