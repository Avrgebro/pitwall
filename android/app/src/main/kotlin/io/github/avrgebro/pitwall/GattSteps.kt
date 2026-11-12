package io.github.avrgebro.pitwall

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import java.io.IOException

/** The GATT operations a link waits on, each answered by its own callback. */
internal enum class GattOp { CONNECT, DISCOVER, MTU, DESCRIPTOR, WRITE }

/**
 * The rule Android's GATT client imposes: one operation at a time, each
 * finished by its own callback. A step waits for the step before it, and
 * only the callback for the operation under way finishes it; any other,
 * such as an MTU change Android made on its own, leaves it waiting.
 *
 * A step that times out is still under way in the stack: its callback is
 * owed, and the next step waits for it, within its own timeout, before it
 * starts. Still owed then, the next step fails unstarted, as the stack
 * would refuse it as busy anyway.
 */
internal class GattSteps(private val timeoutMs: Long) {
    private class Step(val op: GattOp, val done: CompletableDeferred<Unit> = CompletableDeferred())

    private val turn = Mutex()

    /** The step under way, or owed its callback after timing out. */
    @Volatile
    private var current: Step? = null

    @Volatile
    private var closed = false

    /**
     * Starts [op] with [start], which says whether the stack took it, and
     * waits for its callback. Fails with an [IOException] when it can't
     * start, when its callback reports a failure or doesn't come in time,
     * and when the link closes.
     */
    suspend fun run(op: GattOp, start: () -> Boolean) = turn.withLock {
        awaitOwed(op)
        if (closed) throw IOException("Disconnected")
        val step = Step(op)
        current = step
        if (!start()) {
            current = null
            throw IOException("The adapter didn't take the request")
        }
        withTimeoutOrNull(timeoutMs) { step.done.await() }
            ?: throw IOException("The adapter didn't answer in time")
        current = null
    }

    /** Finishes the step under way, if it's [op]; a callback for any other is ignored. */
    fun finish(op: GattOp, ok: Boolean, failure: String) {
        val step = current ?: return
        if (step.op != op) return
        if (ok) step.done.complete(Unit) else step.done.completeExceptionally(IOException(failure))
    }

    /**
     * The link is closed, or went down: the step under way fails with
     * [failure], and every one after it fails unstarted.
     */
    fun close(failure: String = "Disconnected") {
        closed = true
        current?.done?.completeExceptionally(IOException(failure))
    }

    private suspend fun awaitOwed(op: GattOp) {
        val owed = current ?: return
        val answered = withTimeoutOrNull(timeoutMs) {
            try {
                owed.done.await()
            } catch (_: IOException) {
                // How it went was told when it timed out; only its end matters.
            }
        }
        if (answered == null) {
            throw IOException(
                "Not sent: the adapter is still busy with an earlier " +
                    "${owed.op.name.lowercase()} (this was a ${op.name.lowercase()})",
            )
        }
        current = null
    }
}
