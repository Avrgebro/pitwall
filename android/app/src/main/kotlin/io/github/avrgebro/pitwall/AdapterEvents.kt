package io.github.avrgebro.pitwall

import android.os.Handler
import android.os.Looper

/**
 * Where every adapter connection reports to Dart, classic and Bluetooth LE
 * alike: its bytes, and whether it dropped. One stream, as connection
 * numbers are Dart's and never shared between the two.
 */
object AdapterEvents : AdapterEventsStreamHandler() {
    private val main = Handler(Looper.getMainLooper())
    private var sink: PigeonEventSink<AdapterEvent>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<AdapterEvent>) {
        this.sink = sink
    }

    override fun onCancel(p0: Any?) {
        sink = null
    }

    fun bytes(connection: Long, bytes: ByteArray) = main.post {
        sink?.success(AdapterBytes(connection, bytes))
    }

    /** Only for a link that dropped, never one closed on purpose. */
    fun dropped(connection: Long) = main.post {
        sink?.success(AdapterDropped(connection))
    }
}
