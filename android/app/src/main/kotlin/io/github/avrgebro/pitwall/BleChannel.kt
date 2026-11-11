package io.github.avrgebro.pitwall

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.io.Closeable
import java.io.IOException
import java.util.UUID

/**
 * Bluetooth LE connections to an OBD adapter, for Dart's [BleApi]. The
 * counterpart of [ClassicBluetoothChannel], with the same rules: one
 * connection at a time, numbered by Dart, closable at any stage, and its
 * bytes and drops reported through [AdapterEvents].
 *
 * Adapters differ in their GATT layout, so the characteristics are found by
 * what they do, not by UUID: one that notifies carries replies, and one
 * that takes writes carries commands, preferably in the same service.
 */
class BleChannel(private val context: Context, messenger: BinaryMessenger) : BleApi {
    private val adapter: BluetoothAdapter? =
        context.getSystemService(BluetoothManager::class.java)?.adapter

    // A GATT link does one operation at a time, so connects and writes
    // queue here. Closing doesn't: it ends whatever is waiting.
    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    private val io = Dispatchers.IO.limitedParallelism(1)

    private val connections = Connections<GattLink>()

    init {
        BleApi.setUp(messenger, this)
    }

    override suspend fun connect(connection: Long, address: String): Unit = withContext(io) {
        // Connecting replaces any other connection, even when it fails at once.
        connections.replace()
        val adapter = adapter ?: throw FlutterError("unavailable", "No Bluetooth on this device")
        if (!adapter.isEnabled) throw FlutterError("disabled", "Bluetooth is off")
        if (!BluetoothAdapter.checkBluetoothAddress(address)) {
            throw FlutterError("connect_failed", "Not a Bluetooth address")
        }
        val opening = Connection<GattLink>(connection)
        val link = GattLink(opening)
        opening.resource = link
        connections.begin(opening)
        try {
            withTimeout(CONNECT_TIMEOUT_MS) { link.open(adapter.getRemoteDevice(address)) }
        } catch (e: Exception) {
            // However it failed, it's no longer current, and nothing of it stays open.
            connections.ended(opening)
            opening.close()
            if (e is CancellationException && e !is TimeoutCancellationException) throw e
            throw when (e) {
                is SecurityException -> FlutterError("permission", e.message)
                is TimeoutCancellationException ->
                    FlutterError("connect_failed", "The adapter didn't answer in time")
                else -> FlutterError("connect_failed", e.message)
            }
        }
    }

    override suspend fun write(connection: Long, bytes: ByteArray): Unit = withContext(io) {
        try {
            val link = connections.live(connection)?.resource ?: throw IOException("Not connected")
            link.write(bytes)
        } catch (e: IOException) {
            throw FlutterError("write_failed", e.message)
        } catch (e: SecurityException) {
            throw FlutterError("write_failed", e.message)
        } catch (e: TimeoutCancellationException) {
            throw FlutterError("write_failed", "The adapter didn't take the write")
        }
    }

    override fun disconnect(connection: Long) = connections.closedByDart(connection)

    /**
     * One GATT link: its operations, each awaited before the next, and the
     * characteristics it talks through. Closing it disconnects and ends
     * whatever is waiting.
     */
    private inner class GattLink(private val connection: Connection<GattLink>) :
        BluetoothGattCallback(), Closeable {
        @Volatile
        private var gatt: BluetoothGatt? = null

        /** The operation under way, completed by its callback. */
        @Volatile
        private var pending: CompletableDeferred<Unit>? = null

        @Volatile
        private var ready = false

        private var replies: BluetoothGattCharacteristic? = null
        private var commands: BluetoothGattCharacteristic? = null
        private var writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT

        /** The most one write carries: the MTU less the ATT header. */
        private var payload = DEFAULT_MTU - ATT_HEADER

        /** Connects, finds the characteristics, and switches replies on. */
        suspend fun open(device: BluetoothDevice) {
            step { gatt = device.connectGatt(context, false, this, BluetoothDevice.TRANSPORT_LE); true }
            val gatt = gatt ?: throw IOException("Disconnected while connecting")
            step { gatt.discoverServices() }
            val replies = choose(gatt)
            // Larger writes where the adapter takes them; it may refuse.
            try {
                step { gatt.requestMtu(WANTED_MTU) }
            } catch (_: IOException) {
            }
            if (!gatt.setCharacteristicNotification(replies, true)) {
                throw IOException("The adapter wouldn't send replies")
            }
            val config = replies.getDescriptor(CLIENT_CONFIG)
                ?: throw IOException("The adapter's replies can't be switched on")
            val enable = if (replies.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) {
                BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            } else {
                BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
            }
            step { writeDescriptor(gatt, config, enable) }
            ready = true
            Log.i(
                TAG,
                "Connected: replies ${replies.uuid}, commands ${commands?.uuid}, " +
                    "writes of $payload bytes",
            )
        }

        /** Sends [bytes] in writes the adapter takes, one after another. */
        suspend fun write(bytes: ByteArray) {
            val gatt = gatt ?: throw IOException("Not connected")
            val commands = commands ?: throw IOException("Not connected")
            var start = 0
            while (start < bytes.size) {
                val end = minOf(start + payload, bytes.size)
                val chunk = bytes.copyOfRange(start, end)
                step { writeCharacteristic(gatt, commands, chunk) }
                start = end
            }
        }

        override fun close() {
            pending?.completeExceptionally(IOException("Disconnected"))
            gatt?.let {
                it.disconnect()
                it.close()
            }
            gatt = null
        }

        /**
         * Starts an operation with [start] and waits for its callback. One
         * that can't start, as when the link is busy or gone, fails at once.
         */
        private suspend fun step(start: () -> Boolean) {
            if (connection.closed) throw IOException("Disconnected")
            val done = CompletableDeferred<Unit>()
            pending = done
            if (!start()) throw IOException("The adapter didn't take the request")
            withTimeout(STEP_TIMEOUT_MS) { done.await() }
        }

        private fun finish(ok: Boolean, what: String) {
            val done = pending ?: return
            if (ok) done.complete(Unit) else done.completeExceptionally(IOException(what))
        }

        /**
         * Picks the characteristics: in the first service that has both, one
         * that notifies or indicates, and one that takes writes. The standard
         * services every device has are passed over. Returns the one that
         * carries replies.
         */
        private fun choose(gatt: BluetoothGatt): BluetoothGattCharacteristic {
            for (service in gatt.services) {
                if (service.uuid in STANDARD_SERVICES) continue
                val notify = service.characteristics.firstOrNull {
                    it.properties and (NOTIFY or INDICATE) != 0
                } ?: continue
                val write = service.characteristics.firstOrNull {
                    it.properties and (WRITE or WRITE_NO_RESPONSE) != 0
                } ?: continue
                replies = notify
                commands = write
                writeType = if (write.properties and WRITE != 0) {
                    BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                } else {
                    BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                }
                return notify
            }
            throw IOException("Not an OBD adapter: no service to talk through")
        }

        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> finish(status == BluetoothGatt.GATT_SUCCESS, "Couldn't connect")
                BluetoothProfile.STATE_DISCONNECTED -> {
                    finish(false, "The adapter disconnected")
                    // Only report links that dropped once ready, not ones
                    // closed on purpose, or that never got that far.
                    if (ready && !connection.closed) {
                        connections.ended(connection)
                        connection.close()
                        AdapterEvents.dropped(connection.id)
                    }
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) =
            finish(status == BluetoothGatt.GATT_SUCCESS, "Couldn't read the adapter's services")

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) payload = mtu - ATT_HEADER
            finish(status == BluetoothGatt.GATT_SUCCESS, "The adapter kept its smaller writes")
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int,
        ) = finish(status == BluetoothGatt.GATT_SUCCESS, "Couldn't switch the adapter's replies on")

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) = finish(status == BluetoothGatt.GATT_SUCCESS, "The adapter didn't take the write")

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            if (characteristic.uuid == replies?.uuid) AdapterEvents.bytes(connection.id, value)
        }

        // Before Android 13, the value comes on the characteristic.
        @Deprecated("Android 12")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
        ) {
            @Suppress("DEPRECATION")
            val value = characteristic.value ?: return
            onCharacteristicChanged(gatt, characteristic, value.copyOf())
        }

        private fun writeDescriptor(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            value: ByteArray,
        ): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt.writeDescriptor(descriptor, value) == BluetoothStatusCodes.SUCCESS
        } else {
            @Suppress("DEPRECATION")
            descriptor.value = value
            @Suppress("DEPRECATION")
            gatt.writeDescriptor(descriptor)
        }

        private fun writeCharacteristic(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt.writeCharacteristic(characteristic, value, writeType) ==
                BluetoothStatusCodes.SUCCESS
        } else {
            characteristic.writeType = writeType
            @Suppress("DEPRECATION")
            characteristic.value = value
            @Suppress("DEPRECATION")
            gatt.writeCharacteristic(characteristic)
        }
    }

    companion object {
        private const val TAG = "PitwallBle"
        private const val CONNECT_TIMEOUT_MS = 20_000L
        private const val STEP_TIMEOUT_MS = 10_000L
        private const val DEFAULT_MTU = 23
        private const val WANTED_MTU = 247
        private const val ATT_HEADER = 3

        private const val NOTIFY = BluetoothGattCharacteristic.PROPERTY_NOTIFY
        private const val INDICATE = BluetoothGattCharacteristic.PROPERTY_INDICATE
        private const val WRITE = BluetoothGattCharacteristic.PROPERTY_WRITE
        private const val WRITE_NO_RESPONSE =
            BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE

        /** The descriptor that switches notifications and indications on. */
        private val CLIENT_CONFIG: UUID = uuid16(0x2902)

        /** Generic access, generic attribute, device information, battery. */
        private val STANDARD_SERVICES = setOf(0x1800, 0x1801, 0x180A, 0x180F).map(::uuid16).toSet()

        private fun uuid16(short: Int): UUID =
            UUID.fromString(String.format("%08x-0000-1000-8000-00805f9b34fb", short))
    }
}
