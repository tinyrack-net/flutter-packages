package com.example.termworld_ime_harness

import android.inputmethodservice.InputMethodService
import android.os.Bundle
import android.os.Message
import android.os.Messenger
import android.util.Log
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection

class TermworldTestInputMethodService : InputMethodService() {
    private var generation = 0

    override fun onStartInput(attribute: EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        if (attribute?.packageName == TARGET_PACKAGE && attribute.inputType != 0) {
            generation += 1
        }
    }

    override fun onCreateInputView(): View? = null

    override fun onEvaluateInputViewShown(): Boolean = false

    override fun onFinishInputView(finishingInput: Boolean) {}

    override fun onFinishCandidatesView(finishingInput: Boolean) {}

    override fun onFinishInput() {}

    override fun onAppPrivateCommand(action: String?, data: Bundle?) {
        if (action != DRIVER_ACTION || data == null) {
            super.onAppPrivateCommand(action, data)
            return
        }
        val replyMessenger = data.replyMessenger() ?: return
        try {
            val command = data.getBundle(COMMAND_KEY)?.let(HarnessInputCommand::from)
            Log.d(DRIVER_MARKER, "receive command=${command?.javaClass?.simpleName ?: "status"}")
            val accepted = command?.let {
                HarnessInputCommandExecutor(
                    AndroidHarnessInputConnectionBoundary(::connection),
                ).execute(it)
            } ?: true
            replyMessenger.sendResult(RESULT_OK, resultData(accepted))
        } catch (error: RuntimeException) {
            replyMessenger.sendResult(
                RESULT_ERROR,
                resultData(false).apply {
                    putString(ERROR_KEY, error.message ?: error::class.java.simpleName)
                },
            )
        }
    }

    private fun connection(): InputConnection = currentInputConnection
        ?: throw IllegalStateException("The test IME has no FlutterView InputConnection")

    private fun resultData(accepted: Boolean): Bundle = Bundle().apply {
        putBoolean(ACCEPTED_KEY, accepted)
        putBoolean(CONNECTED_KEY, currentInputConnection != null)
        putInt(GENERATION_KEY, generation)
    }

    companion object {
        const val DRIVER_MARKER = "termworld-android-input-connection-ime-harness"
        const val DRIVER_ACTION = "termworld.testing.INPUT_CONNECTION"
        const val COMMAND_KEY = "command"
        const val REPLY_MESSENGER_KEY = "replyMessenger"
        const val ACCEPTED_KEY = "accepted"
        const val CONNECTED_KEY = "connected"
        const val GENERATION_KEY = "generation"
        const val ERROR_KEY = "error"
        const val RESULT_OK = 1
        const val RESULT_ERROR = 2
        const val TARGET_PACKAGE = "com.example.termworld_example"
    }
}

@Suppress("DEPRECATION")
private fun Bundle.replyMessenger(): Messenger? =
    getParcelable(TermworldTestInputMethodService.REPLY_MESSENGER_KEY)

private fun Messenger.sendResult(resultCode: Int, data: Bundle) {
    send(Message.obtain(null, resultCode).apply { this.data = data })
}
