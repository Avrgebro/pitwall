package io.github.avrgebro.pitwall

import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.IOException

class GattStepsTest {
    private val steps = GattSteps(timeoutMs = 100)

    @Test
    fun aCallbackForAnotherOperationLeavesTheStepWaiting() = runBlocking {
        val discover = async(start = CoroutineStart.UNDISPATCHED) {
            steps.run(GattOp.DISCOVER) { true }
        }

        // Android changing the MTU on its own, mid-discovery.
        steps.finish(GattOp.MTU, ok = true, failure = "")
        yield()
        assertFalse(discover.isCompleted)

        steps.finish(GattOp.DISCOVER, ok = true, failure = "")
        discover.await()
    }

    @Test
    fun stepsRunOneAtATime() = runBlocking {
        val started = mutableListOf<String>()
        val first = async(start = CoroutineStart.UNDISPATCHED) {
            steps.run(GattOp.WRITE) { started.add("first"); true }
        }
        val second = async(start = CoroutineStart.UNDISPATCHED) {
            steps.run(GattOp.WRITE) { started.add("second"); true }
        }
        yield()
        assertEquals(listOf("first"), started)

        steps.finish(GattOp.WRITE, ok = true, failure = "")
        first.await()
        yield()
        assertEquals(listOf("first", "second"), started)
        steps.finish(GattOp.WRITE, ok = true, failure = "")
        second.await()
    }

    @Test
    fun aStepTheStackDoesNotTakeFailsAtOnce() = runBlocking {
        assertFails { steps.run(GattOp.CONNECT) { false } }
    }

    @Test
    fun aFailedCallbackFailsTheStep() = runBlocking {
        val write = async(start = CoroutineStart.UNDISPATCHED) {
            runCatching { steps.run(GattOp.WRITE) { true } }
        }
        steps.finish(GattOp.WRITE, ok = false, failure = "refused")

        assertEquals("refused", write.await().exceptionOrNull()?.message)
    }

    @Test
    fun aStepWithNoCallbackTimesOutAsAnIOException() = runBlocking {
        // An adapter that never answers the MTU request: the caller can
        // treat that as a refusal, not a cancelled connect.
        assertFails { steps.run(GattOp.MTU) { true } }
    }

    @Test
    fun aLateCallbackFinishesItsOwnStepNotTheNext() = runBlocking {
        assertFails { steps.run(GattOp.WRITE) { true } }
        var started = false
        val next = async(start = CoroutineStart.UNDISPATCHED) {
            steps.run(GattOp.WRITE) { started = true; true }
        }
        assertFalse(started)

        // The callback for the write that timed out.
        steps.finish(GattOp.WRITE, ok = true, failure = "")
        yield()
        assertTrue(started)
        assertFalse(next.isCompleted)

        steps.finish(GattOp.WRITE, ok = true, failure = "")
        next.await()
    }

    @Test
    fun aCallbackStillOwedKeepsTheNextStepUnstarted() = runBlocking {
        assertFails { steps.run(GattOp.WRITE) { true } }
        var started = false

        assertFails { steps.run(GattOp.WRITE) { started = true; true } }

        assertFalse(started)
    }

    @Test
    fun closingFailsTheStepUnderWayAndLaterOnes() = runBlocking {
        val write = async(start = CoroutineStart.UNDISPATCHED) {
            runCatching { steps.run(GattOp.WRITE) { true } }
        }

        steps.close()

        assertTrue(write.await().exceptionOrNull() is IOException)
        var started = false
        assertFails { steps.run(GattOp.WRITE) { started = true; true } }
        assertFalse(started)
    }

    @Test
    fun aDropBetweenStepsFailsTheNextUnstarted() = runBlocking {
        val discover = async(start = CoroutineStart.UNDISPATCHED) {
            steps.run(GattOp.DISCOVER) { true }
        }
        steps.finish(GattOp.DISCOVER, ok = true, failure = "")
        discover.await()

        steps.close("The adapter disconnected")

        var started = false
        assertFails { steps.run(GattOp.MTU) { started = true; true } }
        assertFalse(started)
    }

    private suspend fun assertFails(block: suspend () -> Unit) {
        try {
            block()
        } catch (_: IOException) {
            return
        }
        fail("Expected an IOException")
    }
}
