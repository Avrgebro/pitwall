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
import kotlinx.coroutines.CancellationException

/**
 * Serial (RFCOMM) connections to a classic Bluetooth OBD adapter, for Dart's
 * [ClassicBluetoothApi]. One connection at a time, each with the number Dart
 * gave it, so writing to or closing an old one never touches a newer one,
 * and Dart can close one while it's still connecting. Its bytes, and
 * whether it dropped, go out as `adapterEvents`.
 *
 * Which connection is current is decided in one place, [Connections]:
 * connects and writes run on [io], disconnects on the main thread, and the
 * reader on its own.
 */
class ClassicBluetoothChannel(context: Context, messenger: BinaryMessenger) :
    ClassicBluetoothApi, AdapterEventsStreamHandler() {

    private val adapter: BluetoothAdapter? =
        context.getSystemService(BluetoothManager::class.java)?.adapter
    private val main = Handler(Looper.getMainLooper())

    // Connects and writes run one at a time, off the main thread. Closing
    // doesn't queue: closing a socket interrupts what's blocked on it.
    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    private val io = Dispatchers.IO.limitedParallelism(1)

    private val connections = Connections()

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
        // Connecting replaces any other connection, even when it fails at once.
        connections.replace()
        val adapter = adapter ?: throw FlutterError("unavailable", "No Bluetooth on this device")
        if (!BluetoothAdapter.checkBluetoothAddress(address)) {
            throw FlutterError("connect_failed", "Not a Bluetooth address")
        }
        val opening = Connection(connection)
        connections.begin(opening)
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
        } catch (e: Exception) {
            // However it failed, it's no longer current, and nothing of it stays open.
            connections.ended(opening)
            opening.close()
            if (e is CancellationException) throw e
            throw when (e) {
                is SecurityException -> FlutterError("permission", e.message)
                else -> FlutterError("connect_failed", e.message)
            }
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
            val socket = connections.live(connection)?.socket
                ?: throw IOException("Not connected")
            val out = socket.outputStream
            out.write(bytes)
            out.flush()
        } catch (e: IOException) {
            throw FlutterError("write_failed", e.message)
        }
    }

    override fun disconnect(connection: Long) = connections.closedByDart(connection)

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
            connections.ended(connection)
            connection.close()
            main.post { events?.success(AdapterDropped(connection.id)) }
        }
    }.apply { isDaemon = true }.start()

    companion object {
        // Standard Serial Port Profile UUID, used by ELM327 adapters.
        private val SERIAL_PORT: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    }
}
