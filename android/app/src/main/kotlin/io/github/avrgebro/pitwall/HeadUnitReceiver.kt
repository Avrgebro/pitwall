package io.github.avrgebro.pitwall

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Starts a trip when the phone connects to one of the cars' head units.
 * Which head unit it was goes along, so the trip knows the car.
 *
 * The head unit only starts trips. Disconnecting from it doesn't end one:
 * the stereo may be handed to someone else's phone mid-drive. The trip ends
 * when the car or the adapter goes quiet.
 *
 * Android 12+ lets an app start a foreground service from a Bluetooth
 * broadcast that needs BLUETOOTH_CONNECT, which these do, so this works
 * with Pitwall in the background or not running at all.
 */
class HeadUnitReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
            ?: return
        if (!ServiceBridge.startsTrip(context, device.address)) return
        if (intent.action == BluetoothDevice.ACTION_ACL_CONNECTED) {
            TripService.start(context, TripTarget.HeadUnit(device.address))
        }
    }
}
