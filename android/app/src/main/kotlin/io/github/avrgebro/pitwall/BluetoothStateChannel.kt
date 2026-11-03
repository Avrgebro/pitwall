package io.github.avrgebro.pitwall

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger

/**
 * Whether Bluetooth is on, as Dart's `bluetoothEnabled` stream: the current
 * state when Dart starts listening, then each change.
 */
class BluetoothStateChannel(private val context: Context, messenger: BinaryMessenger) :
    BluetoothEnabledStreamHandler() {

    private val adapter: BluetoothAdapter? =
        context.getSystemService(BluetoothManager::class.java)?.adapter
    private var receiver: BroadcastReceiver? = null

    init {
        register(messenger, this)
    }

    override fun onListen(p0: Any?, sink: PigeonEventSink<Boolean>) {
        sink.success(adapter?.isEnabled == true)
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)) {
                    BluetoothAdapter.STATE_ON -> sink.success(true)
                    BluetoothAdapter.STATE_OFF -> sink.success(false)
                }
            }
        }
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        // A system broadcast, so the receiver needn't be reachable by other
        // apps.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        this.receiver = receiver
    }

    override fun onCancel(p0: Any?) {
        receiver?.let(context::unregisterReceiver)
        receiver = null
    }
}
