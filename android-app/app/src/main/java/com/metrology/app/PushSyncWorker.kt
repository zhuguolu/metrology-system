package com.metrology.app

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class PushSyncWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    private val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override suspend fun doWork(): Result {
        if (!AppGraph.repository.isLoggedIn()) return Result.success()

        val dashboard = runCatching { AppGraph.repository.dashboard() }.getOrElse { return Result.retry() }
        val isAdmin = AppGraph.repository.isAdmin()

        val pendingAuditCount = if (isAdmin) {
            runCatching { AppGraph.repository.pendingAudit().size.toLong() }.getOrDefault(0L)
        } else {
            0L
        }

        val myAuditList = runCatching { AppGraph.repository.myAudit() }.getOrDefault(emptyList())
        val myPendingCount = myAuditList.count { it.status.fixMojibake().equals("PENDING", true) }.toLong()
        val myApprovedCount = myAuditList.count { it.status.fixMojibake().equals("APPROVED", true) }.toLong()
        val myRejectedCount = myAuditList.count { it.status.fixMojibake().equals("REJECTED", true) }.toLong()

        val current = PushSnapshot(
            warning = dashboard.warning ?: 0L,
            expired = dashboard.expired ?: 0L,
            dueThisMonth = dashboard.dueThisMonth ?: 0L,
            pendingAudit = pendingAuditCount,
            myPending = myPendingCount,
            myApproved = myApprovedCount,
            myRejected = myRejectedCount
        )

        val last = readLastSnapshot()
        if (last == null) {
            saveSnapshot(current)
            return Result.success()
        }

        val messages = mutableListOf<String>()

        val warningDelta = (current.warning - last.warning).coerceAtLeast(0L)
        if (warningDelta > 0L) {
            messages += "即将过期新增 ${warningDelta} 台"
        }
        val expiredDelta = (current.expired - last.expired).coerceAtLeast(0L)
        if (expiredDelta > 0L) {
            messages += "失效新增 ${expiredDelta} 台"
        }
        val dueDelta = (current.dueThisMonth - last.dueThisMonth).coerceAtLeast(0L)
        if (dueDelta > 0L) {
            messages += "本月待校准新增 ${dueDelta} 台"
        }

        if (isAdmin) {
            val pendingDelta = (current.pendingAudit - last.pendingAudit).coerceAtLeast(0L)
            if (pendingDelta > 0L) {
                messages += "数据审核待处理新增 ${pendingDelta} 条"
            }
        } else {
            val approvedDelta = (current.myApproved - last.myApproved).coerceAtLeast(0L)
            if (approvedDelta > 0L) {
                messages += "你的审核记录已通过新增 ${approvedDelta} 条"
            }
            val rejectedDelta = (current.myRejected - last.myRejected).coerceAtLeast(0L)
            if (rejectedDelta > 0L) {
                messages += "你的审核记录已驳回新增 ${rejectedDelta} 条"
            }
        }

        if (messages.isNotEmpty()) {
            val title = if (messages.any { it.contains("审核") }) "系统审核提醒" else "系统设备提醒"
            AppNotificationCenter.showSystemSummary(
                context = applicationContext,
                title = title,
                content = messages.joinToString("；")
            )
        }

        saveSnapshot(current)
        return Result.success()
    }

    private fun readLastSnapshot(): PushSnapshot? {
        if (!prefs.contains(KEY_WARNING)) return null
        return PushSnapshot(
            warning = prefs.getLong(KEY_WARNING, 0L),
            expired = prefs.getLong(KEY_EXPIRED, 0L),
            dueThisMonth = prefs.getLong(KEY_DUE_THIS_MONTH, 0L),
            pendingAudit = prefs.getLong(KEY_PENDING_AUDIT, 0L),
            myPending = prefs.getLong(KEY_MY_PENDING, 0L),
            myApproved = prefs.getLong(KEY_MY_APPROVED, 0L),
            myRejected = prefs.getLong(KEY_MY_REJECTED, 0L)
        )
    }

    private fun saveSnapshot(snapshot: PushSnapshot) {
        prefs.edit()
            .putLong(KEY_WARNING, snapshot.warning)
            .putLong(KEY_EXPIRED, snapshot.expired)
            .putLong(KEY_DUE_THIS_MONTH, snapshot.dueThisMonth)
            .putLong(KEY_PENDING_AUDIT, snapshot.pendingAudit)
            .putLong(KEY_MY_PENDING, snapshot.myPending)
            .putLong(KEY_MY_APPROVED, snapshot.myApproved)
            .putLong(KEY_MY_REJECTED, snapshot.myRejected)
            .apply()
    }

    private data class PushSnapshot(
        val warning: Long,
        val expired: Long,
        val dueThisMonth: Long,
        val pendingAudit: Long,
        val myPending: Long,
        val myApproved: Long,
        val myRejected: Long
    )

    companion object {
        private const val PREFS_NAME = "metrology_push_state"
        private const val KEY_WARNING = "warning"
        private const val KEY_EXPIRED = "expired"
        private const val KEY_DUE_THIS_MONTH = "due_this_month"
        private const val KEY_PENDING_AUDIT = "pending_audit"
        private const val KEY_MY_PENDING = "my_pending"
        private const val KEY_MY_APPROVED = "my_approved"
        private const val KEY_MY_REJECTED = "my_rejected"
    }
}

