package io.github.avrgebro.pitwall

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.UUID

class BleServicesTest {
    @Test
    fun knownObdServicesComeFirstAndStandardOnesAreLeftOut() {
        val firmware = UUID.fromString("f000ffc0-0451-4000-b000-000000000000")
        val listed = listOf(uuid16(0x1800), uuid16(0xFEE7), firmware, uuid16(0xFFE0), uuid16(0x180A), uuid16(0xFFF0))

        assertEquals(
            listOf(uuid16(0xFFF0), uuid16(0xFFE0), uuid16(0xFEE7), firmware),
            inTryOrder(listed) { it },
        )
    }
}
