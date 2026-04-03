package com.metrology.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AuditUiState(
    val loading: Boolean = false,
    val items: List<AuditRecordDto> = emptyList(),
    val error: String? = null
)

class AuditViewModel(
    private val repository: MetrologyRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(AuditUiState(loading = true))
    val uiState = _uiState.asStateFlow()

    fun load() {
        viewModelScope.launch {
            _uiState.value = AuditUiState(loading = true)
            runCatching { repository.pendingAudit() }
                .onSuccess { list ->
                    _uiState.value = AuditUiState(loading = false, items = list)
                }
                .onFailure { throwable ->
                    if (throwable.isCancellationLike()) {
                        _uiState.value = _uiState.value.copy(loading = false)
                        return@onFailure
                    }
                    _uiState.value = AuditUiState(
                        loading = false,
                        error = throwable.message ?: "\u52a0\u8f7d\u5931\u8d25"
                    )
                }
        }
    }

    fun approve(id: Long) {
        viewModelScope.launch {
            runCatching { repository.approveAudit(id) }
                .onSuccess { load() }
                .onFailure { throwable ->
                    if (throwable.isCancellationLike()) return@onFailure
                    _uiState.value = _uiState.value.copy(error = throwable.message ?: "\u5ba1\u6279\u5931\u8d25")
                }
        }
    }

    fun reject(id: Long, reason: String?) {
        viewModelScope.launch {
            runCatching { repository.rejectAudit(id, reason) }
                .onSuccess { load() }
                .onFailure { throwable ->
                    if (throwable.isCancellationLike()) return@onFailure
                    _uiState.value = _uiState.value.copy(error = throwable.message ?: "\u9a73\u56de\u5931\u8d25")
                }
        }
    }
}
