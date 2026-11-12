package io.github.avrgebro.pitwall

import android.bluetooth.BluetoothAdapter
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import java.io.Closeable

/**
 * Connection [id] to the adapter at [address], the one way both kinds of
 * Bluetooth connect: it replaces whatever is current, even when it fails
 * at once, becomes current itself, and [open] connects it. However that
 * fails, it's no longer current, nothing of it stays open, and the failure
 * reaches Dart as `unavailable`, `disabled`, `permission` or
 * `connect_failed`. Dart cancelling the call cancels it.
 *
 * [open] keeps what it opens on the connection as soon as it exists, so a
 * disconnect meanwhile closes it.
 */
internal suspend fun <R : Closeable> Connections<R>.connect(
    id: Long,
    address: String,
    adapter: BluetoothAdapter?,
    open: suspend (connection: Connection<R>, adapter: BluetoothAdapter) -> Unit,
) {
    replace()
    if (adapter == null) throw FlutterError("unavailable", "No Bluetooth on this device")
    if (!adapter.isEnabled) throw FlutterError("disabled", "Bluetooth is off")
    if (!BluetoothAdapter.checkBluetoothAddress(address)) {
        throw FlutterError("connect_failed", "Not a Bluetooth address")
    }
    val opening = Connection<R>(id)
    begin(opening)
    fun abandon() {
        ended(opening)
        opening.close()
    }
    try {
        open(opening, adapter)
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
