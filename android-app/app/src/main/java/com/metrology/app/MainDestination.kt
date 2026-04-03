package com.metrology.app

enum class MainDestination(
    val titleRes: Int
) {
    LEDGER(R.string.title_equipment),
    CALIBRATION(R.string.title_calibration),
    TODO(R.string.title_todo),
    AUDIT(R.string.title_audit),
    MORE(R.string.tab_more),
    DASHBOARD(R.string.title_dashboard),
    SETTINGS(R.string.title_settings),
    FILES(R.string.menu_files),
    WEBDAV(R.string.menu_webdav),
    CHANGES(R.string.menu_changes),
    STATUS(R.string.menu_status),
    DEPARTMENTS(R.string.menu_departments),
    USERS(R.string.menu_users)
}
