package com.metrology.app

import android.content.Context

class SessionManager(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var token: String?
        get() = prefs.getString(KEY_TOKEN, null)
        private set(value) = prefs.edit().putString(KEY_TOKEN, value).apply()

    var username: String?
        get() = prefs.getString(KEY_USERNAME, null)
        private set(value) = prefs.edit().putString(KEY_USERNAME, value).apply()

    var role: String?
        get() = prefs.getString(KEY_ROLE, null)
        private set(value) = prefs.edit().putString(KEY_ROLE, value).apply()

    fun isLoggedIn(): Boolean = !token.isNullOrBlank()

    fun saveLogin(loginResponse: LoginResponse) {
        token = loginResponse.token
        username = loginResponse.username
        role = loginResponse.role
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val PREFS_NAME = "metrology_session"
        private const val KEY_TOKEN = "token"
        private const val KEY_USERNAME = "username"
        private const val KEY_ROLE = "role"
    }
}
