package com.metrology.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class SystemMaintenanceUiState(
    val loading: Boolean = false,
    val settings: SettingsDto? = null,
    val statusMessage: String? = null,
    val error: String? = null
)

class SystemMaintenanceViewModel(
    private val repository: MetrologyRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(SystemMaintenanceUiState(loading = true))
    val uiState = _uiState.asStateFlow()

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true, error = null)
            runCatching { repository.settings() }
                .onSuccess { settings ->
                    _uiState.value = SystemMaintenanceUiState(
                        loading = false,
                        settings = settings
                    )
                }
                .onFailure {
                    _uiState.value = _uiState.value.copy(
                        loading = false,
                        error = it.message ?: "加载失败"
                    )
                }
        }
    }

    fun save(updated: SettingsDto) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true)
            runCatching { repository.saveSettings(updated) }
                .onSuccess { settings ->
                    _uiState.value = SystemMaintenanceUiState(
                        loading = false,
                        settings = settings,
                        statusMessage = "系统维护设置已保存"
                    )
                }
                .onFailure {
                    _uiState.value = _uiState.value.copy(
                        loading = false,
                        error = it.message ?: "保存失败"
                    )
                }
        }
    }

    fun runNow() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(loading = true)
            runCatching { repository.runMaintenanceNow() }
                .onSuccess { result ->
                    _uiState.value = _uiState.value.copy(
                        loading = false,
                        statusMessage = "执行结果：${result.message.orEmpty().ifBlank { "成功" }}"
                    )
                }
                .onFailure {
                    _uiState.value = _uiState.value.copy(
                        loading = false,
                        error = it.message ?: "执行失败"
                    )
                }
        }
    }
}
