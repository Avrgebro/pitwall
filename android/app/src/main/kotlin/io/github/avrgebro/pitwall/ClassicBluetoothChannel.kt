package io.github.avrgebro.pitwall

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException
import java.util.UUID
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

/**
 * Serial (RFCOMM) connections to a classic Bluetooth OBD adapter, for Dart's
 * [ClassicBluetoothApi]. One connection at a time, each with the number Dart
 * gave it, so writing to or closing an old one never touches a newer one,
 * and Dart can close one while it's still connecting. Its bytes, and
 * whether it dropped, go out as `adapterEvents`.
 *
 * Which connection is current is decided in one place, [current], changed
 * only atomically: connects and writes run on [io], disconnects on the
 * main thread, and the reader on its own.
 */
class ClassicBluetoothChannel(context: Context, messenger: BinaryMessenger) :
    ClassicBluetoothApi, AdapterEventsStreamHandler() {

    /** A connection being made, or made: its number, and its socket once one exists. */
    private class Connection(val id: Long) {
        @Volatile
        var socket: BluetoothSocket? = null

        @Volatile
        var closed = false

        fun close() {
            closed = true
            try {
                socket?.close()
            } catch (_: IOException) {
            }
        }
    }

    private val adapter: BluetoothAdapter? =
        context.getSystemService(BluetoothManager::class.java)?.adapter
    private val main = Handler(Looper.getMainLooper())

    // Connects and writes run one at a time, off the main thread. Closing
    // doesn't queue: closing a socket interrupts what's blocked on it.
    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    private val io = Dispatchers.IO.limitedParallelism(1)

    private val current = AtomicReference<Connection?>(null)

    /**
     * The last connection Dart closed. A connect queued behind another
     * isn't current yet when Dart closes it, so it checks this as it
     * becomes current; see [connect] and [disconnect].
     */
    private val closedByDart = AtomicLong(NONE)

    private var events: PigeonEventSink<AdapterEvent>? = null

    init {
        ClassicBluetoothApi.setUp(messenger, this)
        register(messenger, this)
    }

    override fun onListen(p0: Any?, sink: PigeonEventSink<AdapterEvent>) {
        events = sink
    }

    override fun onCancel(p0: Any?) {
        events = null
    }

    override fun bondedDevices(): List<BondedDeviceMessage> {
        val adapter = adapter ?: throw FlutterError("unavailable", "No Bluetooth on this device")
        if (!adapter.isEnabled) throw FlutterError("disabled", "Bluetooth is off")
        try {
            return adapter.bondedDevices.map {
                BondedDeviceMessage(
                    name = it.name ?: it.address,
                    address = it.address,
                    // Major and minor class; uncategorized when not given.
                    deviceClass = (it.bluetoothClass?.deviceClass ?: 0x1F00).toLong(),
                )
            }
        } catch (e: SecurityException) {
            throw FlutterError("permission", e.message)
        }
    }

    override suspend fun connect(connection: Long, address: String): Unit = withContext(io) {
        val adapter = adapter ?: throw FlutterError("unavailable", "No Bluetooth on this device")
        if (!BluetoothAdapter.checkBluetoothAddress(address)) {
            throw FlutterError("connect_failed", "Not a Bluetooth address")
        }
        val opening = Connection(connection)
        current.getAndSet(opening)?.close()
        // After becoming current: either this sees Dart's disconnect, or
        // the disconnect sees this connection and closes it.
        if (closedByDart.get() == connection) opening.close()
        try {
            val device = adapter.getRemoteDevice(address)
            val socket = try {
                open(opening) { device.createRfcommSocketToServiceRecord(SERIAL_PORT) }
            } catch (e: IOException) {
                // Some ELM327 clones only accept unauthenticated connections.
                if (opening.closed) throw e
                open(opening) { device.createInsecureRfcommSocketToServiceRecord(SERIAL_PORT) }
            }
            startReading(opening, socket)
        } catch (e: IOException) {
            current.compareAndSet(opening, null)
            throw FlutterError("connect_failed", e.message)
        } catch (e: SecurityException) {
            current.compareAndSet(opening, null)
            throw FlutterError("permission", e.message)
        }
    }

    /**
     * Connects a socket made by [create], kept on [connection] meanwhile so
     * a disconnect can close it. A socket that doesn't connect, for any
     * reason, is closed.
     */
    private fun open(connection: Connection, create: () -> BluetoothSocket): BluetoothSocket {
        val socket = create()
        connection.socket = socket
        try {
            if (connection.closed) throw IOException("Disconnected while connecting")
            socket.connect()
            if (connection.closed) throw IOException("Disconnected while connecting")
            return socket
        } catch (e: Exception) {
            try {
                socket.close()
            } catch (_: IOException) {
            }
            throw e
        }
    }

    override suspend fun write(connection: Long, bytes: ByteArray): Unit = withContext(io) {
        try {
            val socket = current.get()?.takeIf { it.id == connection && !it.closed }?.socket
                ?: throw IOException("Not connected")
            val out = socket.outputStream
            out.write(bytes)
            out.flush()
        } catch (e: IOException) {
            throw FlutterError("write_failed", e.message)
        }
    }

    override fun disconnect(connection: Long) {
        closedByDart.set(connection)
        val closing = current.get()?.takeIf { it.id == connection } ?: return
        current.compareAndSet(closing, null)
        closing.close()
    }

    private fun startReading(connection: Connection, socket: BluetoothSocket) = Thread {
        val buffer = ByteArray(1024)
        try {
            val input = socket.inputStream
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                val chunk = buffer.copyOf(count)
                main.post { events?.success(AdapterBytes(connection.id, chunk)) }
            }
        } catch (_: IOException) {
            // Reading fails when the link drops or the connection is closed.
        }
        // Only report links that dropped, not ones closed on purpose, by Dart
        // or by a newer connect.
        if (!connection.closed) {
            current.compareAndSet(connection, null)
            connection.close()
            main.post { events?.success(AdapterDropped(connection.id)) }
        }
    }.apply { isDaemon = true }.start()

    companion object {
        // Standard Serial Port Profile UUID, used by ELM327 adapters.
        private val SERIAL_PORT: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        private const val NONE = Long.MIN_VALUE
    }
}
