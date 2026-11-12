package io.github.avrgebro.pitwall

import android.companion.AssociationInfo
import android.companion.CompanionDeviceService
import android.companion.DevicePresenceEvent

/**
 * Started by Android when a watched adapter appears, as it wakes with the
 * car: starts the trip for its vehicle, even with the app closed. Only
 * adapters the app asked to be watched for come here, and only those that
 * still start trips go on.
 */
class AdapterPresenceService : CompanionDeviceService() {
    // Android 16 and later.
    override fun onDevicePresenceEvent(event: DevicePresenceEvent) {
        if (event.event != DevicePresenceEvent.EVENT_BLE_APPEARED) return
        appeared(AdapterWatch.address(this, event.associationId))
    }

    // Android 13 to 15.
    @Deprecated("Android 16")
    override fun onDeviceAppeared(associationInfo: AssociationInfo) =
        appeared(associationInfo.deviceMacAddress?.toString())

    // Android 12.
    @Deprecated("Android 13")
    override fun onDeviceAppeared(address: String) = appeared(address)

    private fun appeared(address: String?) {
        if (address == null || !ServiceBridge.wakesTrip(this, address)) return
        TripService.start(this, AdapterMessage(address.uppercase()))
    }
}
