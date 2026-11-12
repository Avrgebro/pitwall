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
    /** The request whose dialog is open, if one is. */
    private var pending: Pending? = null

    private class Pending(val result: CompletableDeferred<Boolean> = CompletableDeferred()) {
        /** Whether the dialog was shown, so a failure after it is the user's answer. */
        @Volatile
        var asked = false
    }

    override suspend fun watch(address: String): Boolean {
        val manager = activity.getSystemService(CompanionDeviceManager::class.java)
            ?: throw FlutterError("unavailable", "This phone can't watch for devices")
        AdapterWatch.association(activity, address)?.let {
            // Confirmed before: watching it is all that's left.
            AdapterWatch.start(manager, it)
            return true
        }
        // One dialog at a time: a second would take over the first's answer.
        if (pending?.result?.isActive == true) {
            throw FlutterError("busy", "Already asking Android to watch for an adapter")
        }
        val request = AssociationRequest.Builder()
            .addDeviceFilter(
                BluetoothLeDeviceFilter.Builder()
                    .setScanFilter(ScanFilter.Builder().setDeviceAddress(address.uppercase()).build())
                    .build(),
            )
            .setSingleDevice(true)
            .build()
        val asking = Pending()
        pending = asking
        val callback = object : CompanionDeviceManager.Callback() {
            override fun onAssociationPending(intentSender: IntentSender) {
                asking.asked = true
                ask(intentSender)
            }

            override fun onAssociationCreated(association: AssociationInfo) {
                AdapterWatch.start(manager, association)
                asking.result.complete(true)
            }

            // Android 15 and later say why.
            override fun onFailure(errorCode: Int, error: CharSequence?) = when (errorCode) {
                CompanionDeviceManager.RESULT_USER_REJECTED,
                CompanionDeviceManager.RESULT_CANCELED,
                -> declined(asking)
                else -> failed(asking, error)
            }

            // Before Android 15, only whether the dialog was shown tells: a
            // failure after it is the user's answer, one before it Android's,
            // as when it didn't find the adapter.
            @Deprecated("Android 15 says why")
            override fun onFailure(error: CharSequence?) {
                if (asking.asked) declined(asking) else failed(asking, error)
            }
        }
        manager.associate(request, activity.mainExecutor, callback)
        return asking.result.await()
    }

    private fun declined(asking: Pending) {
        asking.result.complete(false)
    }

    private fun failed(asking: Pending, error: CharSequence?) {
        asking.result.completeExceptionally(FlutterError("watch_failed", error?.toString()))
    }

    private fun ask(intentSender: IntentSender) =
        activity.startIntentSenderForResult(intentSender, REQUEST_WATCH, null, 0, 0, 0)

    /** The dialog closed: declined, or confirmed, which the callback reports. */
    fun onResult(requestCode: Int, resultCode: Int) {
        if (requestCode != REQUEST_WATCH) return
        if (resultCode != Activity.RESULT_OK) pending?.let(::declined)
    }

    companion object {
        const val REQUEST_WATCH = 0x5157
    }
}
