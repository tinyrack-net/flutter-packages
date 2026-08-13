package com.example.termworld_ime_harness

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class HarnessInputCommandTest {
    @Test
    fun decodesEverySupportedInputConnectionTransaction() {
        val transactions = listOf(
            mapOf("op" to "beginBatchEdit") to HarnessInputCommand.BeginBatchEdit,
            mapOf("op" to "endBatchEdit") to HarnessInputCommand.EndBatchEdit,
            mapOf(
                "op" to "setComposingText",
                "text" to "한",
                "newCursorPosition" to 1,
            ) to HarnessInputCommand.SetComposingText("한", 1),
            mapOf(
                "op" to "commitText",
                "text" to "한글",
                "newCursorPosition" to -1,
            ) to HarnessInputCommand.CommitText("한글", -1),
            mapOf("op" to "finishComposingText") to
                HarnessInputCommand.FinishComposingText,
            mapOf(
                "op" to "deleteSurroundingText",
                "beforeLength" to 2,
                "afterLength" to 0,
            ) to HarnessInputCommand.DeleteSurroundingText(2, 0),
            mapOf(
                "op" to "deleteSurroundingTextInCodePoints",
                "beforeLength" to 1,
                "afterLength" to 0,
            ) to HarnessInputCommand.DeleteSurroundingTextInCodePoints(1, 0),
            mapOf(
                "op" to "sendKeyEvent",
                "action" to 0,
                "keyCode" to 66,
                "unicodeChar" to 10,
            ) to HarnessInputCommand.SendKeyEvent(0, 66, 10),
            mapOf(
                "op" to "performEditorAction",
                "actionId" to 6,
            ) to HarnessInputCommand.PerformEditorAction(6),
            mapOf("op" to "closeConnection") to HarnessInputCommand.CloseConnection,
            mapOf("op" to "reconnect") to HarnessInputCommand.Reconnect,
            mapOf("op" to "resetConnection") to HarnessInputCommand.Reconnect,
        )

        transactions.forEach { (payload, expected) ->
            assertEquals(expected, HarnessInputCommand.from(payload))
        }
    }

    @Test
    fun decodesBoundedNestedRepeat() {
        val transaction = mapOf(
            "op" to "repeat",
            "count" to 3,
            "command" to mapOf(
                "op" to "deleteSurroundingText",
                "beforeLength" to 1,
                "afterLength" to 0,
            ),
        )

        assertEquals(
            HarnessInputCommand.Repeat(
                3,
                HarnessInputCommand.DeleteSurroundingText(1, 0),
            ),
            HarnessInputCommand.from(transaction),
        )
    }

    @Test
    fun rejectsMalformedAndUnboundedTransactions() {
        assertThrows(IllegalArgumentException::class.java) {
            HarnessInputCommand.from(mapOf("op" to "vendorSpecificMagic"))
        }
        assertThrows(IllegalArgumentException::class.java) {
            HarnessInputCommand.from(
                mapOf(
                    "op" to "commitText",
                    "text" to "missing cursor",
                ),
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            HarnessInputCommand.from(
                mapOf(
                    "op" to "repeat",
                    "count" to 0,
                    "command" to mapOf("op" to "finishComposingText"),
                ),
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            HarnessInputCommand.from(
                mapOf(
                    "op" to "repeat",
                    "count" to 101,
                    "command" to mapOf("op" to "finishComposingText"),
                ),
            )
        }
    }

    @Test
    fun executesInputConnectionCallsAndRepeatedDeletes() {
        val boundary = RecordingBoundary()
        val executor = HarnessInputCommandExecutor(boundary)

        val commands = listOf(
            HarnessInputCommand.BeginBatchEdit,
            HarnessInputCommand.EndBatchEdit,
            HarnessInputCommand.SetComposingText("한", 1),
            HarnessInputCommand.CommitText("한글", 1),
            HarnessInputCommand.FinishComposingText,
            HarnessInputCommand.DeleteSurroundingText(2, 0),
            HarnessInputCommand.DeleteSurroundingTextInCodePoints(1, 0),
            HarnessInputCommand.SendKeyEvent(0, 66, 10),
            HarnessInputCommand.PerformEditorAction(6),
            HarnessInputCommand.Repeat(
                3,
                HarnessInputCommand.DeleteSurroundingText(1, 0),
            ),
            HarnessInputCommand.CloseConnection,
            HarnessInputCommand.Reconnect,
        )

        commands.forEach { command -> assertTrue(executor.execute(command)) }

        assertEquals(
            listOf(
                "begin",
                "end",
                "compose:한:1",
                "commit:한글:1",
                "finish",
                "delete:2:0",
                "deleteCodePoints:1:0",
                "key:0:66:10",
                "action:6",
                "delete:1:0",
                "delete:1:0",
                "delete:1:0",
                "close",
                "reconnect",
            ),
            boundary.calls,
        )
    }
}

private class RecordingBoundary : HarnessInputConnectionBoundary {
    val calls = mutableListOf<String>()

    override fun beginBatchEdit(): Boolean = recorded("begin")

    override fun endBatchEdit(): Boolean = recorded("end")

    override fun setComposingText(text: String, cursor: Int): Boolean =
        recorded("compose:$text:$cursor")

    override fun commitText(text: String, cursor: Int): Boolean =
        recorded("commit:$text:$cursor")

    override fun finishComposingText(): Boolean = recorded("finish")

    override fun deleteSurroundingText(before: Int, after: Int): Boolean =
        recorded("delete:$before:$after")

    override fun deleteSurroundingTextInCodePoints(before: Int, after: Int): Boolean =
        recorded("deleteCodePoints:$before:$after")

    override fun sendKeyEvent(action: Int, keyCode: Int, unicodeChar: Int?): Boolean =
        recorded("key:$action:$keyCode:$unicodeChar")

    override fun performEditorAction(actionId: Int): Boolean = recorded("action:$actionId")

    override fun closeConnection(): Boolean = recorded("close")

    override fun reconnect(): Boolean = recorded("reconnect")

    private fun recorded(call: String): Boolean {
        calls.add(call)
        return true
    }
}
