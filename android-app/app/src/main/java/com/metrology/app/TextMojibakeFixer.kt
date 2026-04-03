package com.metrology.app

import java.nio.charset.Charset

private val gbkCharset: Charset = Charset.forName("GBK")
private val latin1Charset: Charset = Charsets.ISO_8859_1
private val suspiciousLatinPattern = Regex("[\\u00C3\\u00C2\\u00E2\\u00A4\\u20AC\\u2122\\uFFFD]")

fun String?.fixMojibake(): String {
    val raw = this?.trim().orEmpty()
    if (raw.isEmpty()) return raw

    val candidates = linkedSetOf(raw)
    addCandidate(raw, latin1Charset, Charsets.UTF_8, candidates)
    addCandidate(raw, latin1Charset, gbkCharset, candidates)
    addCandidate(raw, gbkCharset, Charsets.UTF_8, candidates)

    val rawScore = readabilityScore(raw)
    val best = candidates.maxByOrNull(::readabilityScore) ?: raw
    val bestScore = readabilityScore(best)
    return if (bestScore >= rawScore + 2) best else raw
}

private fun addCandidate(
    raw: String,
    from: Charset,
    to: Charset,
    candidates: MutableSet<String>
) {
    val converted = runCatching { String(raw.toByteArray(from), to).trim() }.getOrNull()
    if (!converted.isNullOrBlank()) {
        candidates.add(converted)
    }
}

private fun readabilityScore(text: String): Int {
    val trimmed = text.trim()
    if (trimmed.isEmpty()) return Int.MIN_VALUE

    val cjkCount = trimmed.count { it in '\u4e00'..'\u9fff' }
    val asciiCount = trimmed.count { it.code in 32..126 }
    val replacementCount = trimmed.count { it == '\uFFFD' }
    val controlCount = trimmed.count { it.isISOControl() && !it.isWhitespace() }
    val suspiciousCount = suspiciousLatinPattern.findAll(trimmed).count()

    return cjkCount * 4 +
        asciiCount -
        replacementCount * 20 -
        controlCount * 10 -
        suspiciousCount * 6
}

fun String?.fixMojibakeOrDash(): String = fixMojibake().ifBlank { "-" }
