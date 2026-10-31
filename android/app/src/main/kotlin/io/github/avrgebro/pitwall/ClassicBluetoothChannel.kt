package io.github.avrgebro.pitwall

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Serial (RFCOMM) connection to a classic Bluetooth OBD adapter.
 *
 * Methods on `pitwall/classic_bluetooth`: `bondedDevices`, `connect`, `write`,
 * `disconnect`. Bytes from the adapter arrive on `pitwall/classic_bluetooth/input`,
 * which ends with a `disconnected` error if the link drops.
 */
class ClassicBluetoothChannel(context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val adapter: BluetoothAdapter? =
        context.getSystemService(BluetoothManager::class.java)?.adapter
    private val main = Handler(Looper.getMainLooper())

    // Connects and writes run one at a time, off the main thread.
    private val io = Executors.newSingleThreadExecutor()

    @Volatile
    private var socket: BluetoothSocket? = null
    private var events: EventChannel.EventSink? = null

    init {
        MethodChannel(messenger, "pitwall/classic_bluetooth").setMethodCallHandler(this)
        EventChannel(messenger, "pitwall/classic_bluetooth/input").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "bondedDevices" -> bondedDevices(result)
            "connect" -> connect(call.argument<String>("address")!!, result)
            "write" -> write(call.arguments as ByteArray, result)
            "disconnect" -> io.execute {
                close()
                main.post { result.success(null) }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    private fun bondedDevices(result: MethodChannel.Result) {
        val adapter = adapter
        if (adapter == null) return result.error("unavailable", "No Bluetooth on this device", null)
        if (!adapter.isEnabled) return result.error("disabled", "Bluetooth is off", null)
        try {
            result.success(adapter.bondedDevices.map {
                mapOf("name" to (it.name ?: it.address), "address" to it.address)
            })
        } catch (e: SecurityException) {
            result.error("permission", e.message, null)
        }
    }

    private fun connect(address: String, result: MethodChannel.Result) = io.execute {
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
            main.post { result.success(null) }
        } catch (e: IOException) {
            main.post { result.error("connect_failed", e.message, null) }
        } catch (e: SecurityException) {
            main.post { result.error("permission", e.message, null) }
        }
    }

    private fun write(bytes: ByteArray, result: MethodChannel.Result) = io.execute {
        try {
            val out = socket?.outputStream ?: throw IOException("Not connected")
            out.write(bytes)
            out.flush()
            main.post { result.success(null) }
        } catch (e: IOException) {
            main.post { result.error("write_failed", e.message, null) }
        }
    }

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
