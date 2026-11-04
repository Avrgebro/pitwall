package io.github.avrgebro.pitwall

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TripTargetExtrasTest {
    @Test
    fun everyKindReadsBackAsItself() {
        val targets = listOf(
            HeadUnitMessage("AA:BB:CC:DD:EE:FF"),
            AppRequestMessage(VehicleMessage("tucson")),
            AppRequestMessage(AnyVehicleMessage()),
        )
        for (target in targets) {
            assertEquals(target, TripTargetExtras.decode(TripTargetExtras.encode(target)))
        }
        // One of each kind, so a kind added without a case here shows.
        assertEquals(
            TripTargetExtras.Kind.entries.toSet(),
            targets.map { TripTargetExtras.Kind.valueOf(TripTargetExtras.encode(it).substringBefore(':')) }.toSet(),
        )
    }

    @Test
    fun aKindItDoesNotKnowIsNoTarget() {
        assertNull(TripTargetExtras.decode("PARKED:tucson"))
        assertNull(TripTargetExtras.decode(""))
    }
}
