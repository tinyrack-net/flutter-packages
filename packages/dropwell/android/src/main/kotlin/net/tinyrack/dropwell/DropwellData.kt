package net.tinyrack.dropwell

/**
 * Pure data handling for the Android implementation.
 *
 * Nothing here touches the Android framework, so the JVM unit-test target
 * reaches all of it without an emulator. Android's own answer for a clipboard
 * item's media type is often null — a `file://` URI has no provider to ask —
 * and this is the fallback that keeps a pasted screenshot from arriving as an
 * untyped blob.
 */
internal object DropwellData {
    /** Returns the final path component of a URI or path. */
    fun fileNameOf(value: String): String {
        val withoutQuery = value.substringBefore('?')
        val name = withoutQuery.trimEnd('/').substringAfterLast('/')
        return if (name.isEmpty()) withoutQuery else name
    }

    /** Media type for a file name, or null when unknown. */
    fun mimeFromFileName(fileName: String): String? {
        val dot = fileName.lastIndexOf('.')
        if (dot < 0 || dot == fileName.length - 1) return null
        return when (fileName.substring(dot + 1).lowercase()) {
            "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            "bmp" -> "image/bmp"
            "pdf" -> "application/pdf"
            "json" -> "application/json"
            "csv" -> "text/csv"
            "txt", "md", "log" -> "text/plain"
            else -> null
        }
    }

    /**
     * Picks the media type to report for a clipboard item.
     *
     * A content provider's answer wins when it gives one, because it knows the
     * file and the extension may be missing or wrong. `application/octet-stream`
     * is treated as no answer: providers hand it out when they have not looked.
     */
    fun resolveMime(providerMime: String?, fileName: String): String? {
        if (providerMime != null && providerMime != "application/octet-stream") {
            return providerMime
        }
        return mimeFromFileName(fileName)
    }
}
