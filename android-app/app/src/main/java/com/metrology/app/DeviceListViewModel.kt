package com.metrology.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class DeviceListUiState(
    val loading: Boolean = false,
    val items: List<DeviceDto> = emptyList(),
    val total: Long = 0L,
    val totalPages: Int = 1,
    val page: Int = 1,
    val summaryCounts: Map<String, Long> = emptyMap(),
    val useStatusSummary: Map<String, Long> = emptyMap(),
    val error: String? = null
)

class DeviceListViewModel(
    private val repository: MetrologyRepository,
    private val mode: DeviceMode
) : ViewModel() {
    private val _uiState = MutableStateFlow(DeviceListUiState(loading = true))
    val uiState = _uiState.asStateFlow()

    private var currentSearch: String = ""
    private var currentDept: String = ""
    private var currentValidity: String = ""
    private var currentUseStatus: String = ""
    private var currentNextDateFrom: String = ""
    private var currentNextDateTo: String = ""
    private val pageSize = 20

    fun load(
        search: String = currentSearch,
        dept: String = currentDept,
        validity: String = currentValidity,
        useStatus: String = currentUseStatus,
        nextDateFrom: String = currentNextDateFrom,
        nextDateTo: String = currentNextDateTo,
        page: Int = 1
    ) {
        val resolvedUseStatus = if (mode == DeviceMode.CALIBRATION) "\u6b63\u5e38" else useStatus
        currentSearch = search
        currentDept = dept
        currentValidity = validity
        currentUseStatus = resolvedUseStatus
        currentNextDateFrom = nextDateFrom
        currentNextDateTo = nextDateTo

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true, error = null)
            runCatching {
                repository.devicesPaged(
                    mode = mode,
                    search = search,
                    dept = dept,
                    validity = validity,
                    useStatus = resolvedUseStatus,
                    nextDateFrom = nextDateFrom,
                    nextDateTo = nextDateTo,
                    page = page,
                    size = pageSize
                )
            }.onSuccess { res ->
                _uiState.value = DeviceListUiState(
                    loading = false,
                    items = res.content.orEmpty(),
                    total = res.totalElements ?: 0L,
                    totalPages = (res.totalPages ?: 1).coerceAtLeast(1),
                    page = (res.page ?: 1).coerceAtLeast(1),
                    summaryCounts = res.summaryCounts.orEmpty().mapKeys { it.key.fixMojibake() },
                    useStatusSummary = res.useStatusSummary.orEmpty().mapKeys { it.key.fixMojibake() }
                )
            }.onFailure { throwable ->
                if (throwable.isCancellationLike()) {
                    _uiState.value = _uiState.value.copy(loading = false)
                    return@onFailure
                }
                _uiState.value = _uiState.value.copy(
                    loading = false,
                    error = throwable.message.fixMojibake().ifBlank { "\u52a0\u8f7d\u5931\u8d25" }
                )
            }
        }
    }

    fun nextPage() {
        val state = _uiState.value
        if (state.page >= state.totalPages) return
        load(page = state.page + 1)
    }

    fun prevPage() {
        val state = _uiState.value
        if (state.page <= 1) return
        load(page = state.page - 1)
    }
}
