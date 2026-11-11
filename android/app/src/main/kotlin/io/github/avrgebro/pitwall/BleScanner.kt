package io.github.avrgebro.pitwall

import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger

/**
 * Finds Bluetooth LE devices nearby while Dart listens, for picking an
 * adapter: those need no pairing, so they don't appear among the paired
 * devices. Scanning stops as soon as Dart stops listening.
 */
class BleScanner(private val context: Context, messenger: BinaryMessenger) :
    NearbyDevicesStreamHandler() {
    private val main = Handler(Looper.getMainLooper())
    private var sink: PigeonEventSink<FoundDeviceMessage>? = null

    private val callback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            // The advertised name; devices that give none aren't offered.
            val name = result.scanRecord?.deviceName?.takeIf { it.isNotBlank() } ?: return
            val address = result.device.address
            main.post { sink?.success(FoundDeviceMessage(name, address)) }
        }

        override fun onScanFailed(errorCode: Int) {
            main.post { sink?.error("scan_failed", "Scanning failed ($errorCode)", null) }
        }
    }

    init {
        register(messenger, this)
    }

    override fun onListen(p0: Any?, sink: PigeonEventSink<FoundDeviceMessage>) {
        this.sink = sink
        val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter
        if (adapter == null || !adapter.isEnabled) {
            sink.error("disabled", "Bluetooth is off", null)
            return
        }
        val scanner = adapter.bluetoothLeScanner ?: run {
            sink.error("disabled", "Bluetooth is off", null)
            return
        }
        try {
            scanner.startScan(
                null,
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),
                callback,
            )
        } catch (e: SecurityException) {
            sink.error("permission", e.message, null)
        }
    }

    override fun onCancel(p0: Any?) {
        sink = null
        val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter ?: return
        try {
            adapter.bluetoothLeScanner?.stopScan(callback)
        } catch (_: SecurityException) {
        } catch (_: IllegalStateException) {
            // Bluetooth went off, which stopped the scan already.
        }
    }
}
