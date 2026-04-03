package com.metrology.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class LoginUiState(
    val loading: Boolean = false,
    val error: String? = null
)

class LoginViewModel(
    private val repository: MetrologyRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(LoginUiState())
    val uiState = _uiState.asStateFlow()

    private val _loginSuccess = MutableSharedFlow<Unit>()
    val loginSuccess = _loginSuccess.asSharedFlow()

    fun login(username: String, password: String) {
        if (username.isBlank() || password.isBlank()) {
            _uiState.value = LoginUiState(error = "请输入用户名和密码")
            return
        }
        viewModelScope.launch {
            _uiState.value = LoginUiState(loading = true)
            runCatching {
                repository.login(username.trim(), password)
            }.onSuccess {
                _uiState.value = LoginUiState(loading = false)
                _loginSuccess.emit(Unit)
            }.onFailure {
                _uiState.value = LoginUiState(
                    loading = false,
                    error = it.message ?: "登录失败"
                )
            }
        }
    }
}
