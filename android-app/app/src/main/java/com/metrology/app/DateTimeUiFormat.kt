package com.metrology.app

import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private val minuteFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm", Locale.CHINA)

private val fallbackDateTimeFormatters: List<DateTimeFormatter> = listOf(
    DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss", Locale.CHINA),
    DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm", Locale.CHINA),
    DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss", Locale.CHINA),
    DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm", Locale.CHINA)
)

fun String?.formatToMinuteDateTime(): String {
    val value = this.fixMojibake().trim()
    if (value.isBlank() || value == "-" || value.equals("null", ignoreCase = true)) {
        return "-"
    }

    runCatching { LocalDateTime.parse(value).format(minuteFormatter) }
        .getOrNull()
        ?.let { return it }

    val isoLike = if (value.contains(' ') && !value.contains('T')) {
        value.replaceFirst(" ", "T")
    } else {
        value
    }

    runCatching { LocalDateTime.parse(isoLike).format(minuteFormatter) }
        .getOrNull()
        ?.let { return it }

    runCatching { OffsetDateTime.parse(value).format(minuteFormatter) }
        .getOrNull()
        ?.let { return it }

    runCatching { OffsetDateTime.parse(isoLike).format(minuteFormatter) }
        .getOrNull()
        ?.let { return it }

    runCatching {
        Instant.parse(value)
            .atZone(ZoneId.systemDefault())
            .toLocalDateTime()
            .format(minuteFormatter)
    }.getOrNull()?.let { return it }

    for (formatter in fallbackDateTimeFormatters) {
        runCatching { LocalDateTime.parse(value, formatter).format(minuteFormatter) }
            .getOrNull()
            ?.let { return it }
    }

    return value
}

