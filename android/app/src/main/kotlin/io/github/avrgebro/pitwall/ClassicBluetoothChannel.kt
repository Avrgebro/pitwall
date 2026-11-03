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
 * Serial (RFCOMM) connection to a classic Bluetooth OBD adapter, for Dart's
 * [ClassicBluetoothApi]. Bytes from the adapter go out as `adapterInput`,
 * which ends with a `disconnected` error if the link drops.
 */
class ClassicBluetoothChannel(context: Context, messenger: BinaryMessenger) :
    ClassicBluetoothApi, AdapterInputStreamHandler() {

    private val adapter: BluetoothAdapter? =
        context.getSystemService(BluetoothManager::class.java)?.adapter
    private val main = Handler(Looper.getMainLooper())

    // Connects and writes run one at a time, off the main thread.
    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    private val io = Dispatchers.IO.limitedParallelism(1)

    @Volatile
    private var socket: BluetoothSocket? = null
    private var events: PigeonEventSink<ByteArray>? = null

    init {
        ClassicBluetoothApi.setUp(messenger, this)
        register(messenger, this)
    }

    override fun onListen(p0: Any?, sink: PigeonEventSink<ByteArray>) {
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

    override suspend fun connect(address: String) = withContext(io) {
        close()
        try {
            val device = adapter!!.getRemoteDevice(address)
            val connected = try {
                device.createRfcommSocketToServiceRecord(SERIAL_PORT).apply { connect() }
            } catch (e: IOException) {
                // Some ELM327 clones only accept unauthenticated connections.
                device.createInsecureRfcommSocketToServiceRecord(SERIAL_PORT).apply { connect() }
            }
            socket = connected
            startReading(connected)
        } catch (e: IOException) {
            throw FlutterError("connect_failed", e.message)
        } catch (e: SecurityException) {
            throw FlutterError("permission", e.message)
        }
    }

    override suspend fun write(bytes: ByteArray) = withContext(io) {
        try {
            val out = socket?.outputStream ?: throw IOException("Not connected")
            out.write(bytes)
            out.flush()
        } catch (e: IOException) {
            throw FlutterError("write_failed", e.message)
        }
    }

    override suspend fun disconnect() = withContext(io) { close() }

    private fun startReading(connected: BluetoothSocket) = Thread {
        val buffer = ByteArray(1024)
        try {
            val input = connected.inputStream
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                val chunk = buffer.copyOf(count)
                main.post { events?.success(chunk) }
            }
        } catch (_: IOException) {
            // Reading fails when the link drops or close() is called.
        }
        // Only report links that dropped, not ones closed on purpose.
        if (socket === connected) {
            socket = null
            main.post { events?.error("disconnected", "Adapter disconnected", null) }
        }
    }.apply { isDaemon = true }.start()

    private fun close() {
        val current = socket ?: return
        socket = null
        try {
            current.close()
        } catch (_: IOException) {
        }
    }

    companion object {
        // Standard Serial Port Profile UUID, used by ELM327 adapters.
        private val SERIAL_PORT: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }
}
