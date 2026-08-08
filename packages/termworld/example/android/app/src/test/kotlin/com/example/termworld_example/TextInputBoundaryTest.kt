package com.example.termworld_example

import java.text.BreakIterator
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Test

class TextInputBoundaryTest {
    @Test
    fun preservesUtf16AndExtendedGraphemeBoundaries() {
        val value = "한글👩🏽‍💻e\u0301"
        val iterator = BreakIterator.getCharacterInstance(Locale.ROOT)
        iterator.setText(value)
        val boundaries = mutableListOf<Int>()
        var boundary = iterator.first()
        while (boundary != BreakIterator.DONE) {
            boundaries.add(boundary)
            boundary = iterator.next()
        }

        assertEquals(0, boundaries.first())
        assertEquals(value.length, boundaries.last())
        assertEquals(value, String(value.toCharArray()))
    }

    @Test
    fun composingReplacementCommitsOnlyFinalValue() {
        val commits = mutableListOf<String>()
        val updates = listOf("ㅎ" to true, "한글" to true, "韓國" to true, "韓國" to false)
        updates.filterNot { it.second }.forEach { commits.add(it.first) }

        assertEquals(listOf("韓國"), commits)
    }
}
