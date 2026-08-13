package com.example.termworld_example

import android.os.Bundle

/** Typed transaction understood by the Debug-only InputConnection driver. */
internal sealed interface AndroidInputDriverCommand {
    data object BeginBatchEdit : AndroidInputDriverCommand

    data object EndBatchEdit : AndroidInputDriverCommand

    data class SetComposingText(
        val text: String,
        val newCursorPosition: Int,
    ) : AndroidInputDriverCommand

    data class CommitText(
        val text: String,
        val newCursorPosition: Int,
    ) : AndroidInputDriverCommand

    data object FinishComposingText : AndroidInputDriverCommand

    data class DeleteSurroundingText(
        val beforeLength: Int,
        val afterLength: Int,
    ) : AndroidInputDriverCommand

    data class DeleteSurroundingTextInCodePoints(
        val beforeLength: Int,
        val afterLength: Int,
    ) : AndroidInputDriverCommand

    data class SendKeyEvent(
        val action: Int,
        val keyCode: Int,
        val unicodeChar: Int?,
    ) : AndroidInputDriverCommand

    data class DispatchKeyEvent(
        val action: Int,
        val keyCode: Int,
        val unicodeChar: Int?,
    ) : AndroidInputDriverCommand

    data class PerformEditorAction(val actionId: Int) : AndroidInputDriverCommand

    /** Executes one transaction repeatedly before the driver sends its Dart barrier. */
    data class Repeat(
        val count: Int,
        val command: AndroidInputDriverCommand,
    ) : AndroidInputDriverCommand

    data object CloseConnection : AndroidInputDriverCommand

    data object Reconnect : AndroidInputDriverCommand

    data object Show : AndroidInputDriverCommand

    data object Hide : AndroidInputDriverCommand

    companion object {
        fun from(arguments: Bundle): AndroidInputDriverCommand =
            from(arguments.toDriverMap())

        fun from(arguments: Map<*, *>): AndroidInputDriverCommand =
            when (val operation = arguments.string("op")) {
                "beginBatchEdit" -> BeginBatchEdit
                "endBatchEdit" -> EndBatchEdit
                "setComposingText" -> SetComposingText(
                    text = arguments.string("text"),
                    newCursorPosition = arguments.integer("newCursorPosition"),
                )
                "commitText" -> CommitText(
                    text = arguments.string("text"),
                    newCursorPosition = arguments.integer("newCursorPosition"),
                )
                "finishComposingText" -> FinishComposingText
                "deleteSurroundingText" -> DeleteSurroundingText(
                    beforeLength = arguments.integer("beforeLength"),
                    afterLength = arguments.integer("afterLength"),
                )
                "deleteSurroundingTextInCodePoints" -> DeleteSurroundingTextInCodePoints(
                    beforeLength = arguments.integer("beforeLength"),
                    afterLength = arguments.integer("afterLength"),
                )
                "sendKeyEvent" -> SendKeyEvent(
                    action = arguments.integer("action"),
                    keyCode = arguments.integer("keyCode"),
                    unicodeChar = arguments.optionalInteger("unicodeChar"),
                )
                "dispatchKeyEvent" -> DispatchKeyEvent(
                    action = arguments.integer("action"),
                    keyCode = arguments.integer("keyCode"),
                    unicodeChar = arguments.optionalInteger("unicodeChar"),
                )
                "performEditorAction" -> PerformEditorAction(
                    actionId = arguments.integer("actionId"),
                )
                "repeat" -> {
                    val count = arguments.integer("count")
                    require(count in 1..100) { "count must be between 1 and 100" }
                    Repeat(
                        count = count,
                        command = from(arguments.map("command")),
                    )
                }
                "closeConnection" -> CloseConnection
                "reconnect", "resetConnection" -> Reconnect
                "show" -> Show
                "hide" -> Hide
                else -> throw IllegalArgumentException("Unknown Android input operation: $operation")
            }
    }
}

internal fun AndroidInputDriverCommand.toBundle(): Bundle = Bundle().apply {
    when (this@toBundle) {
        AndroidInputDriverCommand.BeginBatchEdit -> putString("op", "beginBatchEdit")
        AndroidInputDriverCommand.EndBatchEdit -> putString("op", "endBatchEdit")
        is AndroidInputDriverCommand.SetComposingText -> {
            putString("op", "setComposingText")
            putString("text", this@toBundle.text)
            putInt("newCursorPosition", this@toBundle.newCursorPosition)
        }
        is AndroidInputDriverCommand.CommitText -> {
            putString("op", "commitText")
            putString("text", this@toBundle.text)
            putInt("newCursorPosition", this@toBundle.newCursorPosition)
        }
        AndroidInputDriverCommand.FinishComposingText ->
            putString("op", "finishComposingText")
        is AndroidInputDriverCommand.DeleteSurroundingText -> {
            putString("op", "deleteSurroundingText")
            putInt("beforeLength", this@toBundle.beforeLength)
            putInt("afterLength", this@toBundle.afterLength)
        }
        is AndroidInputDriverCommand.DeleteSurroundingTextInCodePoints -> {
            putString("op", "deleteSurroundingTextInCodePoints")
            putInt("beforeLength", this@toBundle.beforeLength)
            putInt("afterLength", this@toBundle.afterLength)
        }
        is AndroidInputDriverCommand.SendKeyEvent -> {
            putString("op", "sendKeyEvent")
            putInt("action", this@toBundle.action)
            putInt("keyCode", this@toBundle.keyCode)
            this@toBundle.unicodeChar?.let { putInt("unicodeChar", it) }
        }
        is AndroidInputDriverCommand.DispatchKeyEvent -> {
            putString("op", "dispatchKeyEvent")
            putInt("action", this@toBundle.action)
            putInt("keyCode", this@toBundle.keyCode)
            this@toBundle.unicodeChar?.let { putInt("unicodeChar", it) }
        }
        is AndroidInputDriverCommand.PerformEditorAction -> {
            putString("op", "performEditorAction")
            putInt("actionId", this@toBundle.actionId)
        }
        is AndroidInputDriverCommand.Repeat -> {
            putString("op", "repeat")
            putInt("count", this@toBundle.count)
            putBundle("command", this@toBundle.command.toBundle())
        }
        AndroidInputDriverCommand.CloseConnection -> putString("op", "closeConnection")
        AndroidInputDriverCommand.Reconnect -> putString("op", "reconnect")
        AndroidInputDriverCommand.Show -> putString("op", "show")
        AndroidInputDriverCommand.Hide -> putString("op", "hide")
    }
}

private fun Bundle.toDriverMap(): Map<String, Any?> = keySet().associateWith { key ->
    when (val value = get(key)) {
        is Bundle -> value.toDriverMap()
        else -> value
    }
}

/** Narrow port that keeps transaction decoding independently unit-testable. */
internal interface AndroidInputConnectionBoundary {
    fun beginBatchEdit(): Boolean

    fun endBatchEdit(): Boolean

    fun setComposingText(text: String, newCursorPosition: Int): Boolean

    fun commitText(text: String, newCursorPosition: Int): Boolean

    fun finishComposingText(): Boolean

    fun deleteSurroundingText(beforeLength: Int, afterLength: Int): Boolean

    fun deleteSurroundingTextInCodePoints(beforeLength: Int, afterLength: Int): Boolean

    fun sendKeyEvent(action: Int, keyCode: Int, unicodeChar: Int?): Boolean

    fun dispatchKeyEvent(action: Int, keyCode: Int, unicodeChar: Int?): Boolean

    fun performEditorAction(actionId: Int): Boolean

    fun closeConnection(): Boolean

    fun reconnect(): Boolean

    fun show(): Boolean

    fun hide(): Boolean
}

/** Executes a decoded transaction against one real or fake input boundary. */
internal class AndroidInputDriverCommandExecutor(
    private val boundary: AndroidInputConnectionBoundary,
) {
    fun execute(command: AndroidInputDriverCommand): Boolean {
        when (command) {
            AndroidInputDriverCommand.BeginBatchEdit -> boundary.beginBatchEdit()
            AndroidInputDriverCommand.EndBatchEdit -> boundary.endBatchEdit()
            is AndroidInputDriverCommand.SetComposingText ->
                boundary.setComposingText(command.text, command.newCursorPosition)
            is AndroidInputDriverCommand.CommitText ->
                boundary.commitText(command.text, command.newCursorPosition)
            AndroidInputDriverCommand.FinishComposingText -> boundary.finishComposingText()
            is AndroidInputDriverCommand.DeleteSurroundingText ->
                boundary.deleteSurroundingText(command.beforeLength, command.afterLength)
            is AndroidInputDriverCommand.DeleteSurroundingTextInCodePoints ->
                boundary.deleteSurroundingTextInCodePoints(
                    command.beforeLength,
                    command.afterLength,
                )
            is AndroidInputDriverCommand.SendKeyEvent ->
                boundary.sendKeyEvent(command.action, command.keyCode, command.unicodeChar)
            is AndroidInputDriverCommand.DispatchKeyEvent ->
                boundary.dispatchKeyEvent(command.action, command.keyCode, command.unicodeChar)
            is AndroidInputDriverCommand.PerformEditorAction ->
                boundary.performEditorAction(command.actionId)
            is AndroidInputDriverCommand.Repeat -> repeat(command.count) {
                execute(command.command)
            }
            AndroidInputDriverCommand.CloseConnection -> boundary.closeConnection()
            AndroidInputDriverCommand.Reconnect -> boundary.reconnect()
            AndroidInputDriverCommand.Show -> boundary.show()
            AndroidInputDriverCommand.Hide -> boundary.hide()
        }
        // InputConnection's boolean is an IME-facing advisory value. A false
        // return (notably from beginBatchEdit) does not mean the call was not
        // executed. Reaching this point without an exception is acceptance.
        return true
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
