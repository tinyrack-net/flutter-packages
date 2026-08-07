package net.tinyrack.dropwell

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

/**
 * Android implementation of the dropwell platform boundary.
 *
 * Android has no notion of dropping a file onto an app from outside it, so
 * this half implements the clipboard only and Dart reports `supportsDrop` as
 * false. A clipboard item is a URI rather than a path, so every file comes
 * back as bytes.
 */
class DropwellPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var testing: MethodChannel? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dropwell")
        channel.setMethodCallHandler(this)
        registerTestingChannel(flutterPluginBinding)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "readClipboardFiles" -> result.success(readClipboardFiles())
            // Android never delivers a drop, so a published region list is
            // accepted and ignored rather than treated as a caller error.
            "publishDropRegions" -> result.success(null)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        testing?.setMethodCallHandler(null)
    }

    private fun readClipboardFiles(): List<Map<String, Any?>> {
        val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        val clip: ClipData = manager?.primaryClip ?: return emptyList()
        val files = mutableListOf<Map<String, Any?>>()
        for (index in 0 until clip.itemCount) {
            val uri = clip.getItemAt(index).uri ?: continue
            readUri(uri)?.let(files::add)
        }
        return files
    }

    private fun readUri(uri: Uri): Map<String, Any?>? {
        val bytes =
            try {
                context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            } catch (error: Exception) {
                // A clipboard can outlive the app that owned it, so an item
                // that no longer resolves is expected rather than exceptional.
                null
            } ?: return null
        val fileName = displayNameOf(uri)
        return mapOf(
            "fileName" to fileName,
            "mimeType" to DropwellData.resolveMime(context.contentResolver.getType(uri), fileName),
            "bytes" to bytes
        )
    }

    private fun displayNameOf(uri: Uri): String {
        if (uri.scheme == "file") return DropwellData.fileNameOf(uri.path ?: uri.toString())
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
        context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (column >= 0 && cursor.moveToFirst()) {
                cursor.getString(column)?.let { return it }
            }
        }
        return DropwellData.fileNameOf(uri.toString())
    }

    private fun registerTestingChannel(binding: FlutterPlugin.FlutterPluginBinding) {
        if (!BuildConfig.DEBUG) return
        val channel = MethodChannel(binding.binaryMessenger, "dropwell/testing")
        channel.setMethodCallHandler { call, result -> handleTestingCall(call, result) }
        testing = channel
    }

    private fun handleTestingCall(
        call: MethodCall,
        result: Result
    ) {
        val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        if (manager == null) {
            result.error("clipboard", "no clipboard service", null)
            return
        }
        when (call.method) {
            "clearSystemClipboard" -> {
                manager.setPrimaryClip(ClipData.newPlainText("", ""))
                result.success(null)
            }

            // `asBitmap` is deliberately not honoured: an Android clipboard
            // carries an image as a URI with an image type, which is the same
            // shape as any other file. There is no second path to exercise.
            "setSystemClipboard" -> {
                @Suppress("UNCHECKED_CAST")
                val files = call.argument<List<Map<String, Any?>>>("files") ?: emptyList()
                val uris = files.mapNotNull(::materialize)
                if (uris.isEmpty()) {
                    manager.setPrimaryClip(ClipData.newPlainText("", ""))
                } else {
                    val clip = ClipData.newRawUri("dropwell", uris.first())
                    uris.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
                    manager.setPrimaryClip(clip)
                }
                result.success(null)
            }

            "readFile" -> {
                val path = call.arguments as? String
                if (path == null) {
                    result.error("bad-arguments", "readFile needs a path", null)
                    return
                }
                result.success(File(path).readBytes())
            }

            // Android declares no drop support, so a synthesized drag has
            // nothing to reach and must not silently look like it worked.
            else -> result.notImplemented()
        }
    }

    /**
     * Writes a payload into the cache directory under its own name.
     *
     * The clipboard hands over *files*, so a suite that only ever passed bytes
     * would never exercise the path real users take.
     */
    private fun materialize(file: Map<String, Any?>): Uri? {
        val name = file["fileName"] as? String ?: return null
        val bytes = file["bytes"] as? ByteArray ?: ByteArray(0)
        val directory = File(context.cacheDir, "dropwell").apply { mkdirs() }
        val target = File(directory, name)
        target.writeBytes(bytes)
        return Uri.fromFile(target)
    }
}
