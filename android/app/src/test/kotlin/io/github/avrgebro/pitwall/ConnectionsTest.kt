package io.github.avrgebro.pitwall

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class ConnectionsTest {
    @Test
    fun aConnectionDartClosedBeforeItBeganClosesItself() {
        val connections = Connections()
        connections.closedByDart(5)

        val late = Connection(5).also(connections::begin)

        assertTrue(late.closed)
        assertNull(connections.live(5))
    }

    @Test
    fun aLateCloseOfAnOlderConnectionDoesNotUndoANewerOne() {
        val connections = Connections()
        // Dart closed 5, then an older close for 4 lands late.
        connections.closedByDart(5)
        connections.closedByDart(4)

        val queued = Connection(5).also(connections::begin)

        assertTrue(queued.closed)
    }

    @Test
    fun closingAnOlderConnectionLeavesTheCurrentOneAlone() {
        val connections = Connections()
        val current = Connection(7).also(connections::begin)

        connections.closedByDart(6)

        assertFalse(current.closed)
        assertSame(current, connections.live(7))
    }

    @Test
    fun beginningOneClosesTheOneBefore() {
        val connections = Connections()
        val old = Connection(1).also(connections::begin)

        val next = Connection(2).also(connections::begin)

        assertTrue(old.closed)
        assertNull(connections.live(1))
        assertSame(next, connections.live(2))
    }

    @Test
    fun aConnectionThatEndedIsNoLongerCurrent() {
        val connections = Connections()
        val dropped = Connection(3).also(connections::begin)

        connections.ended(dropped)

        assertNull(connections.live(3))
    }

    @Test
    fun replacingClosesWhateverIsCurrent() {
        val connections = Connections()
        val current = Connection(8).also(connections::begin)

        connections.replace()

        assertTrue(current.closed)
        assertNull(connections.live(8))
    }
}
