package com.metrology.app

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object PushWorkScheduler {
    private const val UNIQUE_PERIODIC_WORK = "metrology_push_periodic_sync"
    private const val UNIQUE_ONCE_WORK = "metrology_push_bootstrap_sync"
    private const val PUSH_STATE_PREFS = "metrology_push_state"

    fun ensureScheduled(context: Context) {
        val appContext = context.applicationContext
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val periodicRequest = PeriodicWorkRequestBuilder<PushSyncWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints)
            .build()
        WorkManager.getInstance(appContext).enqueueUniquePeriodicWork(
            UNIQUE_PERIODIC_WORK,
            ExistingPeriodicWorkPolicy.UPDATE,
            periodicRequest
        )

        val oneShotRequest = OneTimeWorkRequestBuilder<PushSyncWorker>()
            .setConstraints(constraints)
            .build()
        WorkManager.getInstance(appContext).enqueueUniqueWork(
            UNIQUE_ONCE_WORK,
            ExistingWorkPolicy.REPLACE,
            oneShotRequest
        )
    }

    fun cancel(context: Context) {
        val appContext = context.applicationContext
        WorkManager.getInstance(appContext).cancelUniqueWork(UNIQUE_PERIODIC_WORK)
        WorkManager.getInstance(appContext).cancelUniqueWork(UNIQUE_ONCE_WORK)
        appContext.getSharedPreferences(PUSH_STATE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }
}
