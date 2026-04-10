package com.metrology.app

import com.google.gson.JsonParser
import kotlinx.coroutines.CancellationException
import retrofit2.HttpException

fun Throwable.toUserMessage(defaultMessage: String): String {
    if (isCancellationLike()) {
        return "操作已取消"
    }
    val parsedError = (this as? HttpException)?.response()?.errorBody()?.string()
        ?.let(::extractApiError)
    val resolvedMessage = parsedError?.message ?: message
    val resolvedCode = parsedError?.code
    if (!resolvedMessage.isNullOrBlank()) {
        return resolvedMessage.fixMojibake().ifBlank { defaultMessage }
    }
    if (!resolvedCode.isNullOrBlank()) {
        return "请求失败：$resolvedCode"
    }
    return defaultMessage
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

private data class ParsedApiError(
    val code: String?,
    val message: String?
)

private fun extractApiError(rawBody: String): ParsedApiError? {
    return runCatching {
        val jsonObject = JsonParser.parseString(rawBody).asJsonObject
        ParsedApiError(
            code = jsonObject.get("code")?.takeIf { !it.isJsonNull }?.asString?.trim(),
            message = jsonObject.get("message")?.takeIf { !it.isJsonNull }?.asString?.trim()
        )
    }.getOrNull()
}
