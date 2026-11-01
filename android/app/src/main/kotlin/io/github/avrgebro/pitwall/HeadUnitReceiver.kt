package io.github.avrgebro.pitwall

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Starts a trip when the phone connects to the car's head unit, and ends
 * it when it disconnects.
 *
 * Android 12+ lets an app start a foreground service from a Bluetooth
 * broadcast that needs BLUETOOTH_CONNECT, which these do, so this works
 * with Pitwall in the background or not running at all.
 */
class HeadUnitReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
            ?: return
        val headUnit = ServiceBridge.headUnitAddress(context) ?: return
        if (!device.address.equals(headUnit, ignoreCase = true)) return
        when (intent.action) {
            BluetoothDevice.ACTION_ACL_CONNECTED -> TripService.start(context)
            BluetoothDevice.ACTION_ACL_DISCONNECTED -> TripService.requestStop(context)
        }
    }
}
