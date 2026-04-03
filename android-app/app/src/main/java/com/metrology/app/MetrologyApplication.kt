package com.metrology.app

import android.app.Application

class MetrologyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AppGraph.init(this)
        AppNotificationCenter.ensureChannels(this)
        if (AppGraph.repository.isLoggedIn()) {
            PushWorkScheduler.ensureScheduled(this)
        } else {
            PushWorkScheduler.cancel(this)
        }
    }
}
