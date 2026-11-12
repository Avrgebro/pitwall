package io.github.avrgebro.pitwall

import android.companion.AssociationInfo
import android.companion.CompanionDeviceManager
import android.companion.ObservingDevicePresenceRequest
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * Which adapters Android watches for, through the companion devices the
 * user confirmed (see [CompanionChannel]): a watched adapter appearing, as
 * it wakes with the car, starts [AdapterPresenceService].
 */
object AdapterWatch {
    private const val TAG = "PitwallWatch"

    /** The confirmed association for the device at [address], if any. */
    fun association(context: Context, address: String): AssociationInfo? =
        manager(context)?.myAssociations?.firstOrNull {
            it.deviceMacAddress?.toString().equals(address, ignoreCase = true)
        }

    /** The address of the association numbered [id], if it's ours. */
    fun address(context: Context, id: Int): String? =
        manager(context)?.myAssociations?.firstOrNull { it.id == id }
            ?.deviceMacAddress?.toString()

    /**
     * Watches for the adapters at [addresses], and stops watching any other
     * confirmed one. One that isn't confirmed yet is left until it is.
     */
    fun observe(context: Context, addresses: Set<String>) {
        val manager = manager(context) ?: return
        for (association in manager.myAssociations) {
            val address = association.deviceMacAddress?.toString()?.uppercase() ?: continue
            try {
                if (address in addresses) start(manager, association) else stop(manager, association)
            } catch (e: Exception) {
                // Watching one adapter mustn't stop the others being set.
                Log.w(TAG, "Couldn't change watching $address: ${e.message}")
            }
        }
    }

    fun start(manager: CompanionDeviceManager, association: AssociationInfo) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            manager.startObservingDevicePresence(request(association))
        } else {
            @Suppress("DEPRECATION")
            manager.startObservingDevicePresence(association.deviceMacAddress.toString())
        }
    }

    private fun stop(manager: CompanionDeviceManager, association: AssociationInfo) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            manager.stopObservingDevicePresence(request(association))
        } else {
            @Suppress("DEPRECATION")
            manager.stopObservingDevicePresence(association.deviceMacAddress.toString())
        }
    }

    @RequiresApi(Build.VERSION_CODES.BAKLAVA)
    private fun request(association: AssociationInfo) =
        ObservingDevicePresenceRequest.Builder().setAssociationId(association.id).build()

    private fun manager(context: Context): CompanionDeviceManager? =
        context.getSystemService(CompanionDeviceManager::class.java)
}
