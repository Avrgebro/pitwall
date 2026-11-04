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

/**
 * Serial (RFCOMM) connections to a classic Bluetooth OBD adapter, for Dart's
 * [ClassicBluetoothApi]. One connection at a time, each with its own number,
 * so writing to or closing an old one never touches a newer one. Its bytes,
 * and whether it dropped, go out as `adapterEvents`.
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

    private var lastId = 0L

    @Volatile
    private var current: Connection? = null
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

    override suspend fun connect(address: String): Long = withContext(io) {
        current?.close()
        val connection = Connection(++lastId)
        current = connection
        val adapter = adapter ?: throw FlutterError("unavailable", "No Bluetooth on this device")
        if (!BluetoothAdapter.checkBluetoothAddress(address)) {
            throw FlutterError("connect_failed", "Not a Bluetooth address")
        }
        try {
            val device = adapter.getRemoteDevice(address)
            val socket = try {
                open(connection) { device.createRfcommSocketToServiceRecord(SERIAL_PORT) }
            } catch (e: IOException) {
                // Some ELM327 clones only accept unauthenticated connections.
                if (connection.closed) throw e
                open(connection) { device.createInsecureRfcommSocketToServiceRecord(SERIAL_PORT) }
            }
            startReading(connection, socket)
            connection.id
        } catch (e: IOException) {
            throw FlutterError("connect_failed", e.message)
        } catch (e: SecurityException) {
            throw FlutterError("permission", e.message)
        }
    }

    /**
     * Connects a socket made by [create], kept on [connection] meanwhile so
     * a disconnect can close it. A socket that doesn't connect is closed.
     */
    private fun open(connection: Connection, create: () -> BluetoothSocket): BluetoothSocket {
        val socket = create()
        connection.socket = socket
        try {
            if (connection.closed) throw IOException("Disconnected while connecting")
            socket.connect()
            if (connection.closed) throw IOException("Disconnected while connecting")
            return socket
        } catch (e: IOException) {
            try {
                socket.close()
            } catch (_: IOException) {
            }
            throw e
        }
    }

    override suspend fun write(connection: Long, bytes: ByteArray): Unit = withContext(io) {
        try {
            val socket = current?.takeIf { it.id == connection }?.socket
                ?: throw IOException("Not connected")
            val out = socket.outputStream
            out.write(bytes)
            out.flush()
        } catch (e: IOException) {
            throw FlutterError("write_failed", e.message)
        }
    }

    override fun disconnect(connection: Long) {
        val closing = current?.takeIf { it.id == connection } ?: return
        current = null
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
        // Only report links that dropped, not ones closed on purpose.
        if (!connection.closed) {
            if (current === connection) current = null
            connection.close()
            main.post { events?.success(AdapterDropped(connection.id)) }
        }
    }.apply { isDaemon = true }.start()

    companion object {
        // Standard Serial Port Profile UUID, used by ELM327 adapters.
        private val SERIAL_PORT: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }
}
