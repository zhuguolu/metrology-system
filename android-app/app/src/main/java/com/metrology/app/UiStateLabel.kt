package com.metrology.app

import android.widget.TextView

fun TextView.showLoadingState(message: String = "加载中...") {
    text = "· $message"
    setTextColor(context.getColor(R.color.textMuted))
}

fun TextView.showEmptyState(message: String = "暂无数据") {
    text = "○ $message"
    setTextColor(context.getColor(R.color.textSecondary))
}

fun TextView.showErrorState(message: String) {
    text = "⚠ ${message.fixMojibake()}"
    setTextColor(context.getColor(R.color.statusExpired))
}

fun TextView.showReadyState(message: String) {
    text = "✓ ${message.fixMojibake()}"
    setTextColor(context.getColor(R.color.textSecondary))
}
