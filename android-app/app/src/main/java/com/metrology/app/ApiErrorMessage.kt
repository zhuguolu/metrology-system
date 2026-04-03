package com.metrology.app

import com.google.gson.JsonParser
import kotlinx.coroutines.CancellationException
import retrofit2.HttpException

fun Throwable.toUserMessage(defaultMessage: String): String {
    if (isCancellationLike()) {
        return "操作已取消"
    }
    val bodyMessage = (this as? HttpException)?.response()?.errorBody()?.string()
        ?.let(::extractApiMessage)
    val message = bodyMessage ?: message
    return message.fixMojibake().ifBlank { defaultMessage }
}

fun Throwable.isCancellationLike(): Boolean {
    if (this is CancellationException) return true
    val raw = message?.lowercase().orEmpty()
    if (raw.isBlank()) return false
    return raw.contains("job was cancelled") ||
        raw.contains("job was canceled") ||
        raw.contains("cancelled") ||
        raw.contains("canceled") ||
        raw.contains("stream closed") ||
        raw.contains("socket closed") ||
        raw.contains("stream was reset: cancel")
}

private fun extractApiMessage(rawBody: String): String? {
    return runCatching {
        val jsonObject = JsonParser.parseString(rawBody).asJsonObject
        jsonObject.get("message")?.asString
    }.getOrNull()?.trim()
}
