package io.github.avrgebro.pitwall

import android.app.Activity
import android.bluetooth.le.ScanFilter
import android.companion.AssociationInfo
import android.companion.AssociationRequest
import android.companion.BluetoothLeDeviceFilter
import android.companion.CompanionDeviceManager
import android.content.IntentSender
import kotlinx.coroutines.CompletableDeferred

/**
 * Asks Android to watch for an adapter, for Dart's [CompanionApi]. That
 * takes a system dialog the user confirms, so it lives with the screen:
 * [MainActivity] sets it up while it shows, and passes the dialog's result.
 */
class CompanionChannel(private val activity: Activity) : CompanionApi {
    private var pending: CompletableDeferred<Boolean>? = null

    override suspend fun watch(address: String): Boolean {
        val manager = activity.getSystemService(CompanionDeviceManager::class.java)
            ?: throw FlutterError("unavailable", "This phone can't watch for devices")
        AdapterWatch.association(activity, address)?.let {
            // Confirmed before: watching it is all that's left.
            AdapterWatch.start(manager, it)
            return true
        }
        val request = AssociationRequest.Builder()
            .addDeviceFilter(
                BluetoothLeDeviceFilter.Builder()
                    .setScanFilter(ScanFilter.Builder().setDeviceAddress(address.uppercase()).build())
                    .build(),
            )
            .setSingleDevice(true)
            .build()
        val result = CompletableDeferred<Boolean>()
        pending = result
        val callback = object : CompanionDeviceManager.Callback() {
            override fun onAssociationPending(intentSender: IntentSender) = ask(intentSender)

            override fun onAssociationCreated(association: AssociationInfo) {
                AdapterWatch.start(manager, association)
                result.complete(true)
            }

            override fun onFailure(error: CharSequence?) {
                result.complete(false)
            }
        }
        manager.associate(request, activity.mainExecutor, callback)
        return result.await()
    }

    private fun ask(intentSender: IntentSender) =
        activity.startIntentSenderForResult(intentSender, REQUEST_WATCH, null, 0, 0, 0)

    /** The dialog closed: declined, or confirmed, which the callback reports. */
    fun onResult(requestCode: Int, resultCode: Int) {
        if (requestCode != REQUEST_WATCH) return
        if (resultCode != Activity.RESULT_OK) pending?.complete(false)
    }

    companion object {
        const val REQUEST_WATCH = 0x5157
    }
}
