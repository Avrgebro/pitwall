package io.github.avrgebro.pitwall

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.Closeable

class ConnectionsTest {
    @Test
    fun aConnectionDartClosedBeforeItBeganClosesItself() {
        val connections = Connections<Closeable>()
        connections.closedByDart(5)

        val late = Connection<Closeable>(5).also(connections::begin)

        assertTrue(late.closed)
        assertNull(connections.live(5))
    }

    @Test
    fun aLateCloseOfAnOlderConnectionDoesNotUndoANewerOne() {
        val connections = Connections<Closeable>()
        // Dart closed 5, then an older close for 4 lands late.
        connections.closedByDart(5)
        connections.closedByDart(4)

        val queued = Connection<Closeable>(5).also(connections::begin)

        assertTrue(queued.closed)
    }

    @Test
    fun closingAnOlderConnectionLeavesTheCurrentOneAlone() {
        val connections = Connections<Closeable>()
        val current = Connection<Closeable>(7).also(connections::begin)

        connections.closedByDart(6)

        assertFalse(current.closed)
        assertSame(current, connections.live(7))
    }

    @Test
    fun beginningOneClosesTheOneBefore() {
        val connections = Connections<Closeable>()
        val old = Connection<Closeable>(1).also(connections::begin)

        val next = Connection<Closeable>(2).also(connections::begin)

        assertTrue(old.closed)
        assertNull(connections.live(1))
        assertSame(next, connections.live(2))
    }

    @Test
    fun aConnectionThatEndedIsNoLongerCurrent() {
        val connections = Connections<Closeable>()
        val dropped = Connection<Closeable>(3).also(connections::begin)

        connections.ended(dropped)

        assertNull(connections.live(3))
    }

    @Test
    fun replacingClosesWhateverIsCurrent() {
        val connections = Connections<Closeable>()
        val current = Connection<Closeable>(8).also(connections::begin)

        connections.replace()

        assertTrue(current.closed)
        assertNull(connections.live(8))
    }
}
