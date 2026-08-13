package com.example.termworld_example

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidInputDriverCommandTest {
    @Test
    fun decodesAndExecutesTextTransactionsWithoutPlatformObjects() {
        val boundary = RecordingBoundary()
        val executor = AndroidInputDriverCommandExecutor(boundary)

        val transactions = listOf(
            mapOf("op" to "setComposingText", "text" to "ㅎ", "newCursorPosition" to 1),
            mapOf("op" to "commitText", "text" to "한글", "newCursorPosition" to 1),
            mapOf("op" to "finishComposingText"),
            mapOf("op" to "deleteSurroundingText", "beforeLength" to 2, "afterLength" to 0),
            mapOf(
                "op" to "deleteSurroundingTextInCodePoints",
                "beforeLength" to 1,
                "afterLength" to 0,
            ),
            mapOf("op" to "sendKeyEvent", "action" to 0, "keyCode" to 66),
            mapOf("op" to "dispatchKeyEvent", "action" to 0, "keyCode" to 66),
            mapOf("op" to "performEditorAction", "actionId" to 6),
        )

        transactions.forEach { transaction ->
            assertTrue(executor.execute(AndroidInputDriverCommand.from(transaction)))
        }

        assertEquals(
            listOf(
                "compose:ㅎ:1",
                "commit:한글:1",
                "finish",
                "delete:2:0",
                "deleteCodePoints:1:0",
                "key:0:66:null",
                "dispatchKey:0:66:null",
                "action:6",
            ),
            boundary.calls,
        )
    }

    @Test
    fun decodesBatchAndConnectionLifecycleTransactions() {
        val boundary = RecordingBoundary()
        val executor = AndroidInputDriverCommandExecutor(boundary)

        listOf(
            "beginBatchEdit",
            "endBatchEdit",
            "closeConnection",
            "resetConnection",
            "show",
            "hide",
        ).forEach { operation ->
            executor.execute(AndroidInputDriverCommand.from(mapOf("op" to operation)))
        }

        assertEquals(
            listOf("begin", "end", "close", "reconnect", "show", "hide"),
            boundary.calls,
        )
    }

    @Test
    fun repeatsOneTransactionWithoutAnIntermediateDriverBarrier() {
        val boundary = RecordingBoundary()
        val executor = AndroidInputDriverCommandExecutor(boundary)

        val repeat = AndroidInputDriverCommand.from(
            mapOf(
                "op" to "repeat",
                "count" to 3,
                "command" to mapOf(
                    "op" to "deleteSurroundingText",
                    "beforeLength" to 1,
                    "afterLength" to 0,
                ),
            ),
        )

        assertTrue(executor.execute(repeat))
        assertEquals(
            listOf("delete:1:0", "delete:1:0", "delete:1:0"),
            boundary.calls,
        )
    }

    @Test
    fun rejectsUnknownAndIllTypedTransactions() {
        assertThrows(IllegalArgumentException::class.java) {
            AndroidInputDriverCommand.from(mapOf("op" to "vendorSpecificMagic"))
        }
        assertThrows(IllegalArgumentException::class.java) {
            AndroidInputDriverCommand.from(
                mapOf("op" to "commitText", "text" to 7, "newCursorPosition" to 1),
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            AndroidInputDriverCommand.from(
                mapOf(
                    "op" to "repeat",
                    "count" to 0,
                    "command" to mapOf("op" to "finishComposingText"),
                ),
            )
        }
    }
}

private class RecordingBoundary : AndroidInputConnectionBoundary {
    val calls = mutableListOf<String>()

    override fun beginBatchEdit(): Boolean = recorded("begin")

    override fun endBatchEdit(): Boolean = recorded("end")

    override fun setComposingText(text: String, newCursorPosition: Int): Boolean =
        recorded("compose:$text:$newCursorPosition")

    override fun commitText(text: String, newCursorPosition: Int): Boolean =
        recorded("commit:$text:$newCursorPosition")

    override fun finishComposingText(): Boolean = recorded("finish")

    override fun deleteSurroundingText(beforeLength: Int, afterLength: Int): Boolean =
        recorded("delete:$beforeLength:$afterLength")

    override fun deleteSurroundingTextInCodePoints(
        beforeLength: Int,
        afterLength: Int,
    ): Boolean = recorded("deleteCodePoints:$beforeLength:$afterLength")

    override fun sendKeyEvent(action: Int, keyCode: Int, unicodeChar: Int?): Boolean =
        recorded("key:$action:$keyCode:$unicodeChar")

    override fun dispatchKeyEvent(action: Int, keyCode: Int, unicodeChar: Int?): Boolean =
        recorded("dispatchKey:$action:$keyCode:$unicodeChar")

    override fun performEditorAction(actionId: Int): Boolean = recorded("action:$actionId")

    override fun closeConnection(): Boolean = recorded("close")

    override fun reconnect(): Boolean = recorded("reconnect")

    override fun show(): Boolean = recorded("show")

    override fun hide(): Boolean = recorded("hide")

    private fun recorded(call: String): Boolean {
        calls.add(call)
        return true
    }
}
