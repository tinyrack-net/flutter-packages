package com.example.termworld_ime_harness

import android.os.Bundle
import android.view.KeyEvent
import android.view.inputmethod.InputConnection

internal sealed interface HarnessInputCommand {
    data object BeginBatchEdit : HarnessInputCommand
    data object EndBatchEdit : HarnessInputCommand
    data class SetComposingText(val text: String, val cursor: Int) : HarnessInputCommand
    data class CommitText(val text: String, val cursor: Int) : HarnessInputCommand
    data object FinishComposingText : HarnessInputCommand
    data class DeleteSurroundingText(val before: Int, val after: Int) : HarnessInputCommand
    data class DeleteSurroundingTextInCodePoints(val before: Int, val after: Int) :
        HarnessInputCommand
    data class SendKeyEvent(val action: Int, val keyCode: Int, val unicodeChar: Int?) :
        HarnessInputCommand
    data class PerformEditorAction(val actionId: Int) : HarnessInputCommand
    data class Repeat(val count: Int, val command: HarnessInputCommand) : HarnessInputCommand
    data object CloseConnection : HarnessInputCommand
    data object Reconnect : HarnessInputCommand

    companion object {
        fun from(bundle: Bundle): HarnessInputCommand = from(bundle.toHarnessMap())

        fun from(arguments: Map<*, *>): HarnessInputCommand = when (
            val operation = arguments.string("op")
        ) {
            "beginBatchEdit" -> BeginBatchEdit
            "endBatchEdit" -> EndBatchEdit
            "setComposingText" -> SetComposingText(
                arguments.string("text"),
                arguments.integer("newCursorPosition"),
            )
            "commitText" -> CommitText(
                arguments.string("text"),
                arguments.integer("newCursorPosition"),
            )
            "finishComposingText" -> FinishComposingText
            "deleteSurroundingText" -> DeleteSurroundingText(
                arguments.integer("beforeLength"),
                arguments.integer("afterLength"),
            )
            "deleteSurroundingTextInCodePoints" -> DeleteSurroundingTextInCodePoints(
                arguments.integer("beforeLength"),
                arguments.integer("afterLength"),
            )
            "sendKeyEvent" -> SendKeyEvent(
                arguments.integer("action"),
                arguments.integer("keyCode"),
                arguments.optionalInteger("unicodeChar"),
            )
            "performEditorAction" -> PerformEditorAction(arguments.integer("actionId"))
            "repeat" -> {
                val count = arguments.integer("count")
                require(count in 1..100) { "count must be between 1 and 100" }
                Repeat(count, from(arguments.map("command")))
            }
            "closeConnection" -> CloseConnection
            "reconnect", "resetConnection" -> Reconnect
            else -> throw IllegalArgumentException("Unknown Android input operation: $operation")
        }
    }
}

internal class HarnessInputCommandExecutor(
    private val boundary: HarnessInputConnectionBoundary,
) {
    fun execute(command: HarnessInputCommand): Boolean {
        when (command) {
            HarnessInputCommand.BeginBatchEdit -> boundary.beginBatchEdit()
            HarnessInputCommand.EndBatchEdit -> boundary.endBatchEdit()
            is HarnessInputCommand.SetComposingText ->
                boundary.setComposingText(command.text, command.cursor)
            is HarnessInputCommand.CommitText ->
                boundary.commitText(command.text, command.cursor)
            HarnessInputCommand.FinishComposingText -> boundary.finishComposingText()
            is HarnessInputCommand.DeleteSurroundingText ->
                boundary.deleteSurroundingText(command.before, command.after)
            is HarnessInputCommand.DeleteSurroundingTextInCodePoints ->
                boundary.deleteSurroundingTextInCodePoints(command.before, command.after)
            is HarnessInputCommand.SendKeyEvent ->
                boundary.sendKeyEvent(command.action, command.keyCode, command.unicodeChar)
            is HarnessInputCommand.PerformEditorAction ->
                boundary.performEditorAction(command.actionId)
            is HarnessInputCommand.Repeat -> repeat(command.count) {
                execute(command.command)
            }
            HarnessInputCommand.CloseConnection -> boundary.closeConnection()
            HarnessInputCommand.Reconnect -> boundary.reconnect()
        }
        return true
    }
}

internal interface HarnessInputConnectionBoundary {
    fun beginBatchEdit(): Boolean

    fun endBatchEdit(): Boolean

    fun setComposingText(text: String, cursor: Int): Boolean

    fun commitText(text: String, cursor: Int): Boolean

    fun finishComposingText(): Boolean

    fun deleteSurroundingText(before: Int, after: Int): Boolean

    fun deleteSurroundingTextInCodePoints(before: Int, after: Int): Boolean

    fun sendKeyEvent(action: Int, keyCode: Int, unicodeChar: Int?): Boolean

    fun performEditorAction(actionId: Int): Boolean

    fun closeConnection(): Boolean

    fun reconnect(): Boolean
}

internal class AndroidHarnessInputConnectionBoundary(
    private val connection: () -> InputConnection,
) : HarnessInputConnectionBoundary {
    override fun beginBatchEdit(): Boolean = connection().beginBatchEdit()

    override fun endBatchEdit(): Boolean = connection().endBatchEdit()

    override fun setComposingText(text: String, cursor: Int): Boolean =
        connection().setComposingText(text, cursor)

    override fun commitText(text: String, cursor: Int): Boolean =
        connection().commitText(text, cursor)

    override fun finishComposingText(): Boolean = connection().finishComposingText()

    override fun deleteSurroundingText(before: Int, after: Int): Boolean =
        connection().deleteSurroundingText(before, after)

    override fun deleteSurroundingTextInCodePoints(before: Int, after: Int): Boolean =
        connection().deleteSurroundingTextInCodePoints(before, after)

    override fun sendKeyEvent(action: Int, keyCode: Int, unicodeChar: Int?): Boolean =
        connection().sendKeyEvent(keyEvent(action, keyCode, unicodeChar))

    override fun performEditorAction(actionId: Int): Boolean =
        connection().performEditorAction(actionId)

    override fun closeConnection(): Boolean {
        connection().closeConnection()
        return true
    }

    override fun reconnect(): Boolean {
        connection()
        return true
    }

    private fun keyEvent(action: Int, keyCode: Int, unicodeChar: Int?): KeyEvent {
        val event = KeyEvent(action, keyCode)
        require(unicodeChar == null || event.unicodeChar == unicodeChar) {
            "unicodeChar $unicodeChar does not match keyCode $keyCode"
        }
        return event
    }
}

@Suppress("DEPRECATION")
private fun Bundle.toHarnessMap(): Map<String, Any?> = keySet().associateWith { key ->
    when (val value = get(key)) {
        is Bundle -> value.toHarnessMap()
        else -> value
    }
}

private fun Map<*, *>.string(key: String): String =
    this[key] as? String ?: throw IllegalArgumentException("$key must be a String")

private fun Map<*, *>.integer(key: String): Int =
    (this[key] as? Number)?.toInt()
        ?: throw IllegalArgumentException("$key must be an integer")

private fun Map<*, *>.optionalInteger(key: String): Int? =
    this[key]?.let { value ->
        (value as? Number)?.toInt()
            ?: throw IllegalArgumentException("$key must be an integer")
    }

private fun Map<*, *>.map(key: String): Map<*, *> =
    this[key] as? Map<*, *> ?: throw IllegalArgumentException("$key must be a Map")
