package com.metrology.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlin.math.roundToLong

data class DashboardUiState(
    val loading: Boolean = false,
    val summary: DashboardSummaryUi? = null,
    val error: String? = null
)

data class DashboardSummaryUi(
    val total: Long = 0L,
    val dueThisMonth: Long = 0L,
    val valid: Long = 0L,
    val warning: Long = 0L,
    val expired: Long = 0L,
    val trend: List<TrendPointUi> = emptyList(),
    val deptStats: List<DepartmentStatUi> = emptyList()
)

data class TrendPointUi(
    val label: String,
    val value: Long
)

data class DepartmentStatUi(
    val name: String,
    val total: Long,
    val valid: Long,
    val warning: Long,
    val expired: Long
) {
    val validRate: Int
        get() = if (total <= 0L) 0 else ((valid.toDouble() / total.toDouble()) * 100.0).roundToLong().toInt()
}

class DashboardViewModel(
    private val repository: MetrologyRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(DashboardUiState(loading = true))
    val uiState = _uiState.asStateFlow()

    fun load() {
        viewModelScope.launch {
            _uiState.value = DashboardUiState(loading = true)
            runCatching { repository.dashboard() }
                .onSuccess { stats ->
                    _uiState.value = DashboardUiState(loading = false, summary = stats.toSummaryUi())
                }
                .onFailure { throwable ->
                    if (throwable.isCancellationLike()) {
                        _uiState.value = _uiState.value.copy(loading = false)
                        return@onFailure
                    }
                    _uiState.value = DashboardUiState(
                        loading = false,
                        error = throwable.message.fixMojibake().ifBlank { "\u52a0\u8f7d\u5931\u8d25" }
                    )
                }
        }
    }

    private fun DashboardStats.toSummaryUi(): DashboardSummaryUi {
        val validCount = (valid ?: 0L).coerceAtLeast(0L)
        val warningCount = (warning ?: 0L).coerceAtLeast(0L)
        val expiredCount = (expired ?: 0L).coerceAtLeast(0L)
        return DashboardSummaryUi(
            total = (total ?: 0L).coerceAtLeast(0L),
            dueThisMonth = (dueThisMonth ?: 0L).coerceAtLeast(0L),
            valid = validCount,
            warning = warningCount,
            expired = expiredCount,
            trend = parseTrend(monthlyTrend),
            deptStats = parseDepartmentStats(deptStats)
        )
    }

    private fun parseTrend(raw: List<Map<String, Any?>>?): List<TrendPointUi> {
        if (raw.isNullOrEmpty()) return emptyList()
        return raw.mapIndexedNotNull { index, row ->
            val value = row.pickLong("count", "total", "value", "num", "deviceCount")
                ?: return@mapIndexedNotNull null
            val rawLabel = row.pickString("month", "label", "period", "name", "x")
                ?: "M${index + 1}"
            TrendPointUi(
                label = normalizeMonthLabel(rawLabel.fixMojibake()),
                value = value.coerceAtLeast(0L)
            )
        }.takeLast(6)
    }

    private fun parseDepartmentStats(raw: List<Map<String, Any?>>?): List<DepartmentStatUi> {
        if (raw.isNullOrEmpty()) return emptyList()

        data class DeptCounter(
            var total: Long = 0L,
            var valid: Long = 0L,
            var warning: Long = 0L,
            var expired: Long = 0L
        )

        val merged = linkedMapOf<String, DeptCounter>()
        raw.forEachIndexed { index, row ->
            val name = row.pickString("dept", "deptName", "department", "name", "label")
                ?.fixMojibake()
                ?.trim()
                ?.takeIf { it.isNotBlank() }
                ?: "\u90e8\u95e8${index + 1}"

            val valid = row.pickLong("valid", "validCount", "normal")?.coerceAtLeast(0L) ?: 0L
            val warning = row.pickLong("warning", "warningCount", "aboutToExpire")?.coerceAtLeast(0L) ?: 0L
            val expired = row.pickLong("expired", "expiredCount", "invalid")?.coerceAtLeast(0L) ?: 0L
            val total = row.pickLong("total", "count", "deviceCount", "value", "num")
                ?.coerceAtLeast(0L)
                ?: (valid + warning + expired)

            val current = merged.getOrPut(name) { DeptCounter() }
            current.total += total
            current.valid += valid
            current.warning += warning
            current.expired += expired
        }

        return merged.entries
            .map { (name, counter) ->
                DepartmentStatUi(
                    name = name,
                    total = counter.total,
                    valid = counter.valid,
                    warning = counter.warning,
                    expired = counter.expired
                )
            }
            .sortedByDescending { it.total }
    }

    private fun normalizeMonthLabel(label: String): String {
        val text = label.trim()
        if (text.isEmpty()) return "-"

        val yyyyMm = Regex("(\\d{4})[-/.\\u5e74](\\d{1,2})").find(text)
        if (yyyyMm != null) {
            val mm = yyyyMm.groupValues[2].toIntOrNull() ?: return text
            return String.format("%02d%s", mm, "\u6708")
        }

        val onlyMm = Regex("^(\\d{1,2})(\\u6708)?$").find(text)
        if (onlyMm != null) {
            val mm = onlyMm.groupValues[1].toIntOrNull() ?: return text
            return String.format("%02d%s", mm, "\u6708")
        }

        return text
    }

    private fun Map<String, Any?>.pickString(vararg keys: String): String? {
        keys.forEach { key ->
            val value = this[key]
            when (value) {
                is String -> if (value.isNotBlank()) return value
                is Number -> return value.toLong().toString()
            }
        }
        return null
    }

    private fun Map<String, Any?>.pickLong(vararg keys: String): Long? {
        keys.forEach { key ->
            when (val value = this[key]) {
                is Number -> return value.toDouble().roundToLong()
                is String -> {
                    val parsed = value.trim().toDoubleOrNull()?.roundToLong()
                    if (parsed != null) return parsed
                }
            }
        }
        return null
    }
}
