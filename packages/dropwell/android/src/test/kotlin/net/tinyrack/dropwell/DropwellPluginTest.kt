package net.tinyrack.dropwell

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/*
 * The plugin's data handling is framework-free on purpose, so this JVM target
 * reaches all of it without an emulator. Run it with `./gradlew
 * :dropwell:testDebugUnitTest` from `example/android/`.
 */
internal class DropwellDataTest {
    @Test
    fun fileNameOf_takesTheLastComponent() {
        assertEquals("file.txt", DropwellData.fileNameOf("content://media/1/file.txt"))
        assertEquals("file.txt", DropwellData.fileNameOf("/data/user/0/file.txt"))
        assertEquals("file.txt", DropwellData.fileNameOf("file.txt"))
    }

    @Test
    fun fileNameOf_dropsAQueryString() {
        assertEquals("file.txt", DropwellData.fileNameOf("content://p/file.txt?id=3"))
    }

    @Test
    fun fileNameOf_survivesATrailingSlash() {
        assertEquals("dir", DropwellData.fileNameOf("content://p/dir/"))
    }

    @Test
    fun mimeFromFileName_mapsKnownExtensionsCaseInsensitively() {
        assertEquals("image/png", DropwellData.mimeFromFileName("a.PNG"))
        assertEquals("image/jpeg", DropwellData.mimeFromFileName("a.jpeg"))
        assertEquals("text/plain", DropwellData.mimeFromFileName("a.md"))
    }

    @Test
    fun mimeFromFileName_returnsNothingRatherThanGuessing() {
        assertNull(DropwellData.mimeFromFileName("archive.xyz"))
        assertNull(DropwellData.mimeFromFileName("noextension"))
        assertNull(DropwellData.mimeFromFileName("trailing."))
    }

    @Test
    fun resolveMime_prefersTheProvidersAnswer() {
        assertEquals("image/webp", DropwellData.resolveMime("image/webp", "a.png"))
    }

    @Test
    fun resolveMime_treatsOctetStreamAsNoAnswer() {
        assertEquals(
            "image/png",
            DropwellData.resolveMime("application/octet-stream", "a.png")
        )
    }

    @Test
    fun resolveMime_fallsBackToTheExtension() {
        assertEquals("text/plain", DropwellData.resolveMime(null, "notes.txt"))
        assertNull(DropwellData.resolveMime(null, "mystery"))
    }
}
