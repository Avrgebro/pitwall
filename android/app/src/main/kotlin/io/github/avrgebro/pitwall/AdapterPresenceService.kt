package io.github.avrgebro.pitwall

import android.companion.AssociationInfo
import android.companion.CompanionDeviceService
import android.companion.DevicePresenceEvent
import android.os.Build
import androidx.annotation.RequiresApi

/**
 * Started by Android when a watched adapter appears, as it wakes with the
 * car: starts the trip for its vehicle, even with the app closed. Only
 * adapters the app asked to be watched for come here, and only those that
 * still start trips go on.
 */
class AdapterPresenceService : CompanionDeviceService() {
    // Android 16 and later; Android calls it only there.
    @RequiresApi(Build.VERSION_CODES.BAKLAVA)
    override fun onDevicePresenceEvent(event: DevicePresenceEvent) {
        if (event.event != DevicePresenceEvent.EVENT_BLE_APPEARED) return
        appeared(AdapterWatch.address(this, event.associationId))
    }

    // Android 13 to 15.
    @Deprecated("Android 16")
    override fun onDeviceAppeared(associationInfo: AssociationInfo) =
        appeared(associationInfo.deviceMacAddress?.toString())

    private fun appeared(address: String?) {
        if (address == null || !ServiceBridge.wakesTrip(this, address)) return
        TripService.start(this, AdapterMessage(address.uppercase()))
    }
}
