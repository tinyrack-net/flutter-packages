package com.example.termworld_example

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Messenger
import android.util.Log
import android.view.KeyEvent
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.JSONMethodCodec

/** Debug host that relays commands to the separate test IME's system-owned InputConnection. */
class DebugMainActivity : FlutterActivity() {
    private lateinit var driverChannel: MethodChannel
    private lateinit var frameworkTextInputChannel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())
    private var connectionGeneration = 0
    private var connected = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        driverChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TESTING_CHANNEL)
        frameworkTextInputChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FRAMEWORK_TEXT_INPUT_CHANNEL,
            JSONMethodCodec.INSTANCE,
        )
        driverChannel.setMethodCallHandler(::handleDriverCall)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        driverChannel.setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handleDriverCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                RESET_METHOD -> requestImeCommand(null, result, awaitInputQueue = true)
                EXECUTE_METHOD -> {
                    val arguments = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("transaction must be a map")
                    val command = AndroidInputDriverCommand.from(arguments)
                    when (command) {
                        is AndroidInputDriverCommand.DispatchKeyEvent -> {
                            flutterView().dispatchKeyEvent(
                                keyEvent(command.action, command.keyCode, command.unicodeChar),
                            )
                            result.success(status())
                        }
                        AndroidInputDriverCommand.Show -> {
                            inputMethodManager().showSoftInput(
                                flutterView(),
                                InputMethodManager.SHOW_IMPLICIT,
                            )
                            completeAfterInputQueue(result, status())
                        }
                        AndroidInputDriverCommand.Hide -> {
                            val view = flutterView()
                            inputMethodManager().hideSoftInputFromWindow(view.windowToken, 0)
                            completeAfterInputQueue(result, status())
                        }
                        else -> requestImeCommand(
                            command,
                            result,
                            awaitInputQueue = command == AndroidInputDriverCommand.CloseConnection,
                        )
                    }
                }
                STATUS_METHOD -> requestImeCommand(null, result, awaitInputQueue = true)
                else -> result.notImplemented()
            }
        } catch (error: RuntimeException) {
            result.error("android-input-driver", error.message, status())
        }
    }

    private fun requestImeCommand(
        command: AndroidInputDriverCommand?,
        result: MethodChannel.Result,
        awaitInputQueue: Boolean,
    ) {
        val view = flutterView()
        val inputMethodManager = inputMethodManager()
        var completed = false
        val timeout = Runnable {
            if (completed) return@Runnable
            completed = true
            result.error(
                "android-input-driver-timeout",
                "The active Debug IME did not answer the InputConnection command",
                status(),
            )
        }
        val replyMessenger = Messenger(
            Handler(mainHandler.looper) { message ->
                if (!completed) {
                    completed = true
                    mainHandler.removeCallbacks(timeout)
                    val resultData = message.data
                    connectionGeneration = resultData.getInt(
                        GENERATION_KEY,
                    )
                    connected = resultData.getBoolean(CONNECTED_KEY)
                    if (message.what != IME_RESULT_OK) {
                        result.error(
                            "android-input-ime",
                            resultData.getString(ERROR_KEY),
                            status(accepted = false),
                        )
                    } else {
                        val accepted = resultData.getBoolean(ACCEPTED_KEY)
                        if (command == AndroidInputDriverCommand.CloseConnection) {
                            // Debug Flutter accepts -1 as a wildcard client ID. This
                            // mirrors the framework callback for a dead connection.
                            frameworkTextInputChannel.invokeMethod(
                                "TextInputClient.onConnectionClosed",
                                listOf(-1),
                            )
                        }
                        if (awaitInputQueue) {
                            completeAfterInputQueue(result, status(accepted))
                        } else {
                            result.success(status(accepted))
                        }
                    }
                }
                true
            },
        )
        val data = Bundle().apply {
            putParcelable(REPLY_MESSENGER_KEY, replyMessenger)
            command?.let {
                putBundle(COMMAND_KEY, it.toBundle())
            }
        }
        mainHandler.postDelayed(timeout, DRIVER_TIMEOUT_MILLIS)
        if (command == AndroidInputDriverCommand.Reconnect &&
            !inputMethodManager.isActive(view)
        ) {
            view.requestFocus()
            inputMethodManager.restartInput(view)
            inputMethodManager.showSoftInput(
                view,
                InputMethodManager.SHOW_IMPLICIT,
            )
        }
        fun sendWhenActive() {
            if (completed) return
            if (!inputMethodManager.isActive(view)) {
                mainHandler.postDelayed(::sendWhenActive, ACTIVE_POLL_MILLIS)
                return
            }
            Log.d(DRIVER_MARKER, "send command=${command?.javaClass?.simpleName ?: "status"}")
            inputMethodManager.sendAppPrivateCommand(
                view,
                IME_DRIVER_ACTION,
                data,
            )
            if (command == null || command == AndroidInputDriverCommand.Reconnect) {
                mainHandler.postDelayed(::sendWhenActive, COMMAND_RETRY_MILLIS)
            }
        }
        mainHandler.post(::sendWhenActive)
    }

    /**
     * Completes the command only after Dart handles a request queued on the
     * same `flutter/textinput` channel as the editing callbacks. The impossible
     * client id makes `onFocusReceived` return false before invoking any client
     * or mutating editing state in pinned Flutter, while preserving FIFO order.
     */
    private fun completeAfterInputQueue(result: MethodChannel.Result, value: Map<String, Any>) {
        frameworkTextInputChannel.invokeMethod(
            FIFO_BARRIER_METHOD,
            listOf(FIFO_BARRIER_CLIENT_ID),
            object : MethodChannel.Result {
                override fun success(barrierResult: Any?) {
                    if (barrierResult == false) {
                        result.success(value)
                    } else {
                        result.error(
                            "android-input-barrier",
                            "Flutter text-input FIFO sentinel was unexpectedly accepted",
                            status(),
                        )
                    }
                }

                override fun error(code: String, message: String?, details: Any?) {
                    result.error(code, message, details)
                }

                override fun notImplemented() {
                    result.error(
                        "android-input-barrier",
                        "Flutter text-input completion barrier is not installed",
                        status(),
                    )
                }
            },
        )
    }

    private fun status(accepted: Boolean = true): Map<String, Any> {
        return mapOf(
            "accepted" to accepted,
            "connectionCount" to connectionGeneration,
            "connected" to connected,
            "driverMarker" to DRIVER_MARKER,
        )
    }

    private fun flutterView(): FlutterView =
        findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID)
            ?: throw IllegalStateException("FlutterView is not attached")

    private fun inputMethodManager(): InputMethodManager =
        getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager

    private fun keyEvent(action: Int, keyCode: Int, unicodeChar: Int?): KeyEvent {
        val event = KeyEvent(action, keyCode)
        require(unicodeChar == null || event.unicodeChar == unicodeChar) {
            "unicodeChar $unicodeChar does not match keyCode $keyCode"
        }
        return event
    }

    private companion object {
        const val TESTING_CHANNEL = "termworld/testing"
        const val FRAMEWORK_TEXT_INPUT_CHANNEL = "flutter/textinput"
        const val RESET_METHOD = "androidInputConnection.reset"
        const val EXECUTE_METHOD = "androidInputConnection.execute"
        const val STATUS_METHOD = "androidInputConnection.status"
        const val FIFO_BARRIER_METHOD = "TextInputClient.onFocusReceived"
        const val FIFO_BARRIER_CLIENT_ID = -2
        const val DRIVER_MARKER = "termworld-android-input-connection-driver"
        const val DRIVER_TIMEOUT_MILLIS = 5_000L
        const val ACTIVE_POLL_MILLIS = 25L
        const val COMMAND_RETRY_MILLIS = 100L
        const val IME_DRIVER_ACTION = "termworld.testing.INPUT_CONNECTION"
        const val COMMAND_KEY = "command"
        const val REPLY_MESSENGER_KEY = "replyMessenger"
        const val ACCEPTED_KEY = "accepted"
        const val CONNECTED_KEY = "connected"
        const val GENERATION_KEY = "generation"
        const val ERROR_KEY = "error"
        const val IME_RESULT_OK = 1
    }
}
