package io.github.avrgebro.pitwall

import java.io.Closeable
import java.io.IOException
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

/**
 * A connection being made, or made: its number, and what it holds once
 * that exists, such as a socket, closed with it.
 */
internal class Connection<R : Closeable>(val id: Long) {
    @Volatile
    var resource: R? = null

    @Volatile
    var closed = false
        private set

    fun close() {
        closed = true
        try {
            resource?.close()
        } catch (_: IOException) {
        }
    }
}

/**
 * Which connection is current, for every thread that asks: changed only
 * atomically, by compare-and-set where it might race.
 *
 * Dart numbers connections, and its numbers only go up, even across a
 * restart of Dart (they start from the time). So closing one number closes
 * every earlier one too, and a connect that becomes current after Dart
 * closed its number, as one started while another was still connecting
 * can, closes itself.
 */
internal class Connections<R : Closeable> {
    private val current = AtomicReference<Connection<R>?>(null)
    private val closedThrough = AtomicLong(Long.MIN_VALUE)

    /** Closes whatever is current: connecting replaces it. */
    fun replace() {
        current.getAndSet(null)?.close()
    }

    /**
     * Makes [connection] current, closing any other. Closed at once if Dart
     * already closed its number: either this sees Dart's close, or the
     * close sees this connection.
     */
    fun begin(connection: Connection<R>) {
        current.getAndSet(connection)?.close()
        if (connection.id <= closedThrough.get()) connection.close()
    }

    /** The current connection, if it's numbered [id] and still open. */
    fun live(id: Long): Connection<R>? = current.get()?.takeIf { it.id == id && !it.closed }

    /** Dart closed connection [id], and with it every earlier one. */
    fun closedByDart(id: Long) {
        closedThrough.accumulateAndGet(id) { a, b -> maxOf(a, b) }
        val closing = current.get()?.takeIf { it.id <= id } ?: return
        current.compareAndSet(closing, null)
        closing.close()
    }

    /** [connection] dropped, or failed to open: it's current no longer. */
    fun ended(connection: Connection<R>) {
        current.compareAndSet(connection, null)
    }
}
