package io.github.avrgebro.pitwall

import android.Manifest
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
import android.util.Log
import androidx.annotation.RequiresPermission
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.io.Closeable
import java.io.IOException
import java.util.UUID
import java.util.concurrent.atomic.AtomicReference

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

    private val connections = Connections<GattLink>()

    init {
        BleApi.setUp(messenger, this)
    }

    override suspend fun connect(connection: Long, address: String): Unit = withContext(Dispatchers.IO) {
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
        // However it fails, it's no longer current, and nothing of it stays open.
        fun abandon() {
            connections.ended(opening)
            opening.close()
        }
        try {
            withTimeout(CONNECT_TIMEOUT_MS) { link.open(adapter.getRemoteDevice(address)) }
        } catch (e: SecurityException) {
            abandon()
            throw FlutterError("permission", e.message)
        } catch (e: TimeoutCancellationException) {
            abandon()
            throw FlutterError("connect_failed", "The adapter didn't answer in time")
        } catch (e: CancellationException) {
            abandon()
            throw e
        } catch (e: Exception) {
            abandon()
            throw FlutterError("connect_failed", e.message)
        }
    }

    override suspend fun write(connection: Long, bytes: ByteArray): Unit = withContext(Dispatchers.IO) {
        try {
            val link = connections.live(connection)?.resource ?: throw IOException("Not connected")
            link.write(bytes)
        } catch (e: IOException) {
            throw FlutterError("write_failed", e.message)
        } catch (e: SecurityException) {
            throw FlutterError("write_failed", e.message)
        }
    }

    override fun disconnect(connection: Long) = connections.closedByDart(connection)

    /**
     * One GATT link: its operations, one at a time through [steps], and the
     * characteristics it talks through. Closing it disconnects and ends
     * whatever is waiting. Callbacks come on binder threads, so what they
     * read is volatile.
     */
    private inner class GattLink(private val connection: Connection<GattLink>) :
        BluetoothGattCallback(), Closeable {
        @Volatile
        private var gatt: BluetoothGatt? = null

        private val steps = GattSteps(STEP_TIMEOUT_MS)

        /** Opening until ready; dropped from either, once. */
        private val state = AtomicReference(LinkState.OPENING)

        @Volatile
        private var replies: BluetoothGattCharacteristic? = null

        @Volatile
        private var commands: BluetoothGattCharacteristic? = null

        @Volatile
        private var writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT

        /** The most one write carries: the MTU less the ATT header. */
        @Volatile
        private var payload = DEFAULT_MTU - ATT_HEADER

        /** Connects, finds the characteristics, and switches replies on. */
        @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
        suspend fun open(device: BluetoothDevice) {
            // Null when Bluetooth is off: not taken, so it fails at once.
            steps.run(GattOp.CONNECT) {
                gatt = device.connectGatt(context, false, this, BluetoothDevice.TRANSPORT_LE)
                gatt != null
            }
            val gatt = gatt ?: throw IOException("Disconnected while connecting")
            steps.run(GattOp.DISCOVER) { gatt.discoverServices() }
            val replies = choose(gatt)
            // Larger writes where the adapter takes them; it may refuse, or
            // not answer, and writes stay small.
            try {
                steps.run(GattOp.MTU) { gatt.requestMtu(WANTED_MTU) }
            } catch (e: IOException) {
                Log.i(TAG, "Kept writes of $payload bytes: ${e.message}")
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
            steps.run(GattOp.DESCRIPTOR) {
                gatt.writeDescriptor(config, enable) == BluetoothStatusCodes.SUCCESS
            }
            // A drop since the last step already failed it, or comes now.
            if (!state.compareAndSet(LinkState.OPENING, LinkState.READY)) {
                throw IOException("The adapter disconnected")
            }
            Log.i(
                TAG,
                "Connected: replies ${replies.uuid}, commands ${commands?.uuid}, " +
                    "writes of $payload bytes",
            )
        }

        /** Sends [bytes] in writes the adapter takes, one after another. */
        @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
        suspend fun write(bytes: ByteArray) {
            val gatt = gatt ?: throw IOException("Not connected")
            val commands = commands ?: throw IOException("Not connected")
            var start = 0
            while (start < bytes.size) {
                val end = minOf(start + payload, bytes.size)
                val chunk = bytes.copyOfRange(start, end)
                steps.run(GattOp.WRITE) {
                    gatt.writeCharacteristic(commands, chunk, writeType) == BluetoothStatusCodes.SUCCESS
                }
                start = end
            }
        }

        override fun close() {
            steps.close()
            val gatt = gatt ?: return
            this.gatt = null
            try {
                gatt.disconnect()
                gatt.close()
            } catch (_: SecurityException) {
                // Revoking the permission ends the app's links along with it.
            }
        }

        /**
         * Picks the characteristics: in the first service that has both, one
         * that notifies or indicates, and one that takes writes, trying
         * known OBD services first ([inTryOrder]). Returns the one that
         * carries replies.
         */
        private fun choose(gatt: BluetoothGatt): BluetoothGattCharacteristic {
            Log.i(TAG, "Services: ${gatt.services.joinToString { it.uuid.toString() }}")
            for (service in inTryOrder(gatt.services) { it.uuid }) {
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
                BluetoothProfile.STATE_CONNECTED ->
                    steps.finish(GattOp.CONNECT, status == BluetoothGatt.GATT_SUCCESS, "Couldn't connect")
                BluetoothProfile.STATE_DISCONNECTED -> {
                    val was = state.getAndSet(LinkState.DROPPED)
                    steps.close("The adapter disconnected")
                    // Only report links that dropped once ready, not ones
                    // closed on purpose, or still opening: that fails open.
                    if (was == LinkState.READY && !connection.closed) {
                        connections.ended(connection)
                        connection.close()
                        AdapterEvents.dropped(connection.id)
                    }
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) =
            steps.finish(GattOp.DISCOVER, status == BluetoothGatt.GATT_SUCCESS, "Couldn't read the adapter's services")

        // Android may change the MTU on its own, unasked: the size still
        // counts, and only a step that asked for it is finished.
        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) payload = mtu - ATT_HEADER
            steps.finish(GattOp.MTU, status == BluetoothGatt.GATT_SUCCESS, "The adapter kept its smaller writes")
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int,
        ) = steps.finish(GattOp.DESCRIPTOR, status == BluetoothGatt.GATT_SUCCESS, "Couldn't switch the adapter's replies on")

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) = steps.finish(GattOp.WRITE, status == BluetoothGatt.GATT_SUCCESS, "The adapter didn't take the write")

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            if (characteristic.uuid == replies?.uuid) AdapterEvents.bytes(connection.id, value)
        }
    }

    /** Where a link is: opening until ready, and dropped from either, once. */
    private enum class LinkState { OPENING, READY, DROPPED }

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
    }
}
