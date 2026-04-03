package com.metrology.app

import android.content.Context

object AppGraph {
    private lateinit var appContext: Context
    lateinit var sessionManager: SessionManager
        private set
    lateinit var repository: MetrologyRepository
        private set

    fun init(context: Context) {
        appContext = context.applicationContext
        sessionManager = SessionManager(appContext)
        repository = MetrologyRepository(
            apiServiceFactory = { ApiClient.create(sessionManager) },
            fileApiServiceFactory = { ApiClient.createFileTransfer(sessionManager) },
            sessionManager = sessionManager
        )
    }
}
