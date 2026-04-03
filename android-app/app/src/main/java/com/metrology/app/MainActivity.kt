package com.metrology.app

import android.Manifest
import android.app.AlertDialog
import android.content.Intent
import android.content.res.ColorStateList
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.enableEdgeToEdge
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.isVisible
import androidx.core.view.updatePadding
import androidx.core.view.WindowInsetsCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentManager
import com.metrology.app.databinding.ActivityMainBinding
import com.metrology.app.databinding.ItemMoreEntryBinding

class MainActivity : FontScaleActivity() {
    private lateinit var binding: ActivityMainBinding

    private var currentPrimary: MainDestination = MainDestination.LEDGER
    private var isMoreOpen: Boolean = false
    private var navSwitching: Boolean = false
    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { _ -> }

    private val moreEntryViews by lazy {
        listOf(
            binding.moreDashboard.root,
            binding.moreEquipment.root,
            binding.moreCalibration.root,
            binding.moreTodo.root,
            binding.moreAudit.root,
            binding.moreFiles.root,
            binding.moreWebdav.root,
            binding.moreChanges.root,
            binding.moreStatus.root,
            binding.moreDepartments.root,
            binding.moreUsers.root,
            binding.moreSettings.root
        )
    }

    private val moreSectionViews by lazy {
        listOf(binding.moreSectionCommon, binding.moreSectionData, binding.moreSectionAdmin)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!AppGraph.repository.isLoggedIn()) {
            startActivity(Intent(this, LoginActivity::class.java))
            finish()
            return
        }

        enableEdgeToEdge()
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        AppNotificationCenter.ensureChannels(this)
        PushWorkScheduler.ensureScheduled(this)
        applyInsets()
        requestNotificationPermissionIfNeeded()
        configureTopBar()
        configureTabs()
        configureBackNavigation()

        if (savedInstanceState == null) {
            switchPrimary(MainDestination.LEDGER)
        }
    }

    private fun applyInsets() {
        ViewCompat.setOnApplyWindowInsetsListener(binding.rootContainer) { _, insets ->
            val system = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            binding.mainShell.updatePadding(
                top = system.top + resources.getDimensionPixelSize(R.dimen.screen_top_padding),
                left = resources.getDimensionPixelSize(R.dimen.screen_horizontal_padding) + system.left,
                right = resources.getDimensionPixelSize(R.dimen.screen_horizontal_padding) + system.right
            )
            binding.bottomNav.updatePadding(bottom = resources.getDimensionPixelSize(R.dimen.bottom_nav_vertical_padding) + system.bottom)
            binding.morePanel.updatePadding(
                top = system.top,
                left = system.left,
                right = system.right,
                bottom = system.bottom
            )
            insets
        }
        ViewCompat.requestApplyInsets(binding.rootContainer)
    }

    private fun configureTopBar() {
        binding.topSubtitle.text = "当前用户：${AppGraph.repository.username()}"
        binding.actionGoHome.text = "回看板"
        binding.actionGoHome.setOnClickListener {
            openSinglePage(MainDestination.DASHBOARD, DashboardFragment())
        }
    }

    private fun configureTabs() {
        binding.tabLedger.setOnClickListener { switchPrimary(MainDestination.LEDGER) }
        binding.tabCalibration.setOnClickListener { switchPrimary(MainDestination.CALIBRATION) }
        binding.tabTodo.setOnClickListener { switchPrimary(MainDestination.TODO) }
        binding.tabAudit.setOnClickListener { switchPrimary(MainDestination.AUDIT) }
        binding.tabMore.setOnClickListener { switchPrimary(MainDestination.MORE) }
        updateBottomTabs()
    }

    private fun configureMorePanel() {
        configureMoreCard(binding.moreDashboard, R.drawable.ic_nav_dashboard, R.string.menu_dashboard, R.drawable.bg_more_icon_chip_blue, R.color.moreIconTintBlue)
        configureMoreCard(binding.moreEquipment, R.drawable.ic_nav_equipment, R.string.menu_equipment, R.drawable.bg_more_icon_chip_green, R.color.moreIconTintGreen)
        configureMoreCard(binding.moreCalibration, R.drawable.ic_nav_calibration, R.string.menu_calibration, R.drawable.bg_more_icon_chip_orange, R.color.moreIconTintOrange)
        configureMoreCard(binding.moreTodo, R.drawable.ic_nav_todo, R.string.menu_todo, R.drawable.bg_more_icon_chip_purple, R.color.moreIconTintPurple)
        configureMoreCard(binding.moreAudit, R.drawable.ic_nav_audit, R.string.menu_audit, R.drawable.bg_more_icon_chip_purple, R.color.moreIconTintPurple)
        configureMoreCard(binding.moreFiles, R.drawable.ic_nav_files, R.string.menu_files, R.drawable.bg_more_icon_chip_blue, R.color.moreIconTintBlue)
        configureMoreCard(binding.moreWebdav, R.drawable.ic_nav_webdav, R.string.menu_webdav, R.drawable.bg_more_icon_chip_green, R.color.moreIconTintGreen)
        configureMoreCard(binding.moreChanges, R.drawable.ic_nav_changes, R.string.menu_changes, R.drawable.bg_more_icon_chip_blue, R.color.moreIconTintBlue)
        configureMoreCard(binding.moreStatus, R.drawable.ic_nav_status, R.string.menu_status, R.drawable.bg_more_icon_chip_green, R.color.moreIconTintGreen)
        configureMoreCard(binding.moreDepartments, R.drawable.ic_nav_departments, R.string.menu_departments, R.drawable.bg_more_icon_chip_orange, R.color.moreIconTintOrange)
        configureMoreCard(binding.moreUsers, R.drawable.ic_nav_users, R.string.menu_users, R.drawable.bg_more_icon_chip_purple, R.color.moreIconTintPurple)
        configureMoreCard(binding.moreSettings, R.drawable.ic_nav_settings, R.string.menu_settings, R.drawable.bg_more_icon_chip_slate, R.color.moreIconTintSlate)

        binding.moreOverlay.setOnClickListener { closeMorePanel() }
        binding.morePanel.setOnClickListener {}
        binding.moreClose.setOnClickListener { closeMorePanel() }
        binding.moreLogout.setOnClickListener {
            showLogoutConfirmDialogLegacy()
        }

        binding.moreDashboard.root.setOnClickListener { openSinglePage(MainDestination.DASHBOARD, DashboardFragment()) }
        binding.moreEquipment.root.setOnClickListener { switchPrimary(MainDestination.LEDGER) }
        binding.moreCalibration.root.setOnClickListener { switchPrimary(MainDestination.CALIBRATION) }
        binding.moreTodo.root.setOnClickListener { switchPrimary(MainDestination.TODO) }
        binding.moreAudit.root.setOnClickListener { switchPrimary(MainDestination.AUDIT) }
        binding.moreFiles.root.setOnClickListener { openSinglePage(MainDestination.FILES, FilesFragment()) }
        binding.moreStatus.root.setOnClickListener { openSinglePage(MainDestination.STATUS, DeviceStatusFragment()) }
        binding.moreDepartments.root.setOnClickListener { openSinglePage(MainDestination.DEPARTMENTS, DepartmentFragment()) }
        binding.moreChanges.root.setOnClickListener { openSinglePage(MainDestination.CHANGES, ChangeRecordFragment()) }
        binding.moreWebdav.root.setOnClickListener { openSinglePage(MainDestination.WEBDAV, WebDavFragment()) }
        binding.moreUsers.root.setOnClickListener { openSinglePage(MainDestination.USERS, UserManagementFragment()) }
        binding.moreSettings.root.setOnClickListener { openSinglePage(MainDestination.SETTINGS, SystemMaintenanceFragment()) }
    }

    private fun openMorePanel() {
        if (isMoreOpen) return
        isMoreOpen = true
        binding.moreOverlay.isVisible = true
        binding.moreOverlay.alpha = 0f
        binding.morePanel.alpha = 0f
        binding.morePanel.translationY = 24f
        binding.moreOverlay.animate().alpha(1f).setDuration(180L).start()
        animateMoreIn()
        updateBottomTabs()
    }

    private fun animateMoreIn() {
        binding.morePanel.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(260L)
            .start()

        moreSectionViews.forEachIndexed { index, view ->
            view.alpha = 0f
            view.translationY = 18f
            view.animate()
                .alpha(1f)
                .translationY(0f)
                .setStartDelay(50L + index * 70L)
                .setDuration(240L)
                .start()
        }

        moreEntryViews.forEachIndexed { index, view ->
            view.alpha = 0f
            view.scaleX = 0.9f
            view.scaleY = 0.9f
            view.translationY = 16f
            view.animate()
                .alpha(1f)
                .scaleX(1f)
                .scaleY(1f)
                .translationY(0f)
                .setStartDelay(90L + index * 24L)
                .setDuration(220L)
                .start()
        }
    }

    private fun closeMorePanel(animated: Boolean = true) {
        if (!isMoreOpen) return
        isMoreOpen = false
        if (!animated) {
            binding.moreOverlay.isVisible = false
            binding.moreOverlay.alpha = 1f
            binding.morePanel.alpha = 1f
            binding.morePanel.translationY = 0f
            updateBottomTabs()
            return
        }
        binding.morePanel.animate()
            .alpha(0f)
            .translationY(20f)
            .setDuration(150L)
            .start()
        binding.moreOverlay.animate()
            .alpha(0f)
            .setDuration(150L)
            .withEndAction {
                binding.moreOverlay.isVisible = false
                binding.moreOverlay.alpha = 1f
                binding.morePanel.alpha = 1f
                binding.morePanel.translationY = 0f
                updateBottomTabs()
            }
            .start()
    }

    private fun switchPrimary(destination: MainDestination) {
        if (navSwitching || isFinishing || isDestroyed) return
        navSwitching = true
        closeMorePanel(false)
        clearBackStack()
        currentPrimary = destination
        val fragment = when (destination) {
            MainDestination.LEDGER -> DeviceListFragment.newInstance(DeviceMode.LEDGER)
            MainDestination.CALIBRATION -> DeviceListFragment.newInstance(DeviceMode.CALIBRATION)
            MainDestination.TODO -> DeviceListFragment.newInstance(DeviceMode.TODO)
            MainDestination.AUDIT -> AuditFragment()
            MainDestination.MORE -> MoreModulesFragment()
            else -> DeviceListFragment.newInstance(DeviceMode.LEDGER)
        }
        replaceFragmentSafely(fragment = fragment, addToBackStackName = null)
        updateHeader(destination)
        updateBottomTabs()
        binding.root.post { navSwitching = false }
    }

    fun navigateFromMore(destination: MainDestination) {
        when (destination) {
            MainDestination.LEDGER,
            MainDestination.CALIBRATION,
            MainDestination.TODO,
            MainDestination.AUDIT,
            MainDestination.MORE -> switchPrimary(destination)

            MainDestination.DASHBOARD -> openSinglePage(destination, DashboardFragment())
            MainDestination.FILES -> openSinglePage(destination, FilesFragment())
            MainDestination.STATUS -> openSinglePage(destination, DeviceStatusFragment())
            MainDestination.DEPARTMENTS -> openSinglePage(destination, DepartmentFragment())
            MainDestination.CHANGES -> openSinglePage(destination, ChangeRecordFragment())
            MainDestination.WEBDAV -> openSinglePage(destination, WebDavFragment())
            MainDestination.USERS -> openSinglePage(destination, UserManagementFragment())
            MainDestination.SETTINGS -> openSinglePage(destination, SystemMaintenanceFragment())
        }
    }

    private fun openSinglePage(destination: MainDestination, fragment: Fragment) {
        if (navSwitching || isFinishing || isDestroyed) return
        navSwitching = true
        closeMorePanel(false)
        replaceFragmentSafely(fragment = fragment, addToBackStackName = destination.name)
        updateHeader(destination)
        updateBottomTabs()
        binding.root.post { navSwitching = false }
    }

    private fun openPlaceholder(destination: MainDestination) {
        openSinglePage(
            destination = destination,
            fragment = PlaceholderFragment.newInstance(getString(destination.titleRes))
        )
    }

    private fun configureBackNavigation() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                when {
                    isMoreOpen -> closeMorePanel()
                    supportFragmentManager.backStackEntryCount > 0 -> {
                        supportFragmentManager.popBackStack()
                        updateHeader(currentPrimary)
                    }
                    currentPrimary != MainDestination.LEDGER -> switchPrimary(MainDestination.LEDGER)
                    else -> finish()
                }
            }
        })
    }

    private fun clearBackStack() {
        val fm = supportFragmentManager
        if (fm.backStackEntryCount <= 0) return
        if (fm.isStateSaved) {
            fm.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)
            return
        }
        runCatching {
            fm.popBackStackImmediate(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)
        }.onFailure {
            fm.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)
        }
    }

    private fun replaceFragmentSafely(fragment: Fragment, addToBackStackName: String?) {
        val fm = supportFragmentManager
        if (isFinishing || isDestroyed || fm.isStateSaved) return

        runCatching {
            val tx = fm.beginTransaction()
                .setReorderingAllowed(true)
                .replace(binding.fragmentContainer.id, fragment)
            if (!addToBackStackName.isNullOrBlank()) {
                tx.addToBackStack(addToBackStackName)
            }
            tx.commit()
        }.onFailure {
            if (isFinishing || isDestroyed || fm.isStateSaved) return@onFailure
            runCatching {
                val tx = fm.beginTransaction()
                    .setReorderingAllowed(true)
                    .replace(binding.fragmentContainer.id, fragment)
                if (!addToBackStackName.isNullOrBlank()) {
                    tx.addToBackStack(addToBackStackName)
                }
                tx.commitAllowingStateLoss()
            }
        }
    }

    private fun updateHeader(destination: MainDestination) {
        binding.topTitle.setText(destination.titleRes)
        val showBackToBoard = when (destination) {
            MainDestination.LEDGER,
            MainDestination.CALIBRATION,
            MainDestination.TODO -> true

            else -> false
        }
        binding.actionGoHome.visibility = if (showBackToBoard) View.VISIBLE else View.GONE
        val hideTopBar = destination == MainDestination.MORE
        binding.topBar.visibility = if (hideTopBar) View.GONE else View.VISIBLE
        val fragmentParams = binding.fragmentContainer.layoutParams as ViewGroup.MarginLayoutParams
        fragmentParams.topMargin = if (hideTopBar) 0 else dp(10)
        binding.fragmentContainer.layoutParams = fragmentParams
        if (destination == MainDestination.DASHBOARD) {
            binding.topSubtitle.visibility = View.VISIBLE
            binding.topSubtitle.text = "当前用户：${AppGraph.repository.username()}"
        } else {
            binding.topSubtitle.visibility = View.GONE
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    private fun updateBottomTabs() {
        val activeColor = getColor(R.color.navActive)
        val inactiveColor = getColor(R.color.navInactive)
        val activeBg = getDrawable(R.drawable.bg_tab_active)
        val inactiveBg = getDrawable(R.drawable.bg_tab_inactive)

        setTabState(binding.tabLedger, binding.tabLedgerIcon, binding.tabLedgerText, currentPrimary == MainDestination.LEDGER, activeBg, inactiveBg, activeColor, inactiveColor)
        setTabState(binding.tabCalibration, binding.tabCalibrationIcon, binding.tabCalibrationText, currentPrimary == MainDestination.CALIBRATION, activeBg, inactiveBg, activeColor, inactiveColor)
        setTabState(binding.tabTodo, binding.tabTodoIcon, binding.tabTodoText, currentPrimary == MainDestination.TODO, activeBg, inactiveBg, activeColor, inactiveColor)
        setTabState(binding.tabAudit, binding.tabAuditIcon, binding.tabAuditText, currentPrimary == MainDestination.AUDIT, activeBg, inactiveBg, activeColor, inactiveColor)
        setTabState(binding.tabMore, binding.tabMoreIcon, binding.tabMoreText, currentPrimary == MainDestination.MORE, activeBg, inactiveBg, activeColor, inactiveColor)
    }

    private fun setTabState(
        tab: LinearLayout,
        icon: ImageView,
        label: TextView,
        active: Boolean,
        activeBg: android.graphics.drawable.Drawable?,
        inactiveBg: android.graphics.drawable.Drawable?,
        activeColor: Int,
        inactiveColor: Int
    ) {
        tab.background = if (active) activeBg else inactiveBg
        val color = if (active) activeColor else inactiveColor
        icon.imageTintList = ColorStateList.valueOf(color)
        val targetIconAlpha = if (active) 1f else 0.78f
        val targetScale = if (active) 1.05f else 0.94f
        icon.animate()
            .alpha(targetIconAlpha)
            .scaleX(targetScale)
            .scaleY(targetScale)
            .setDuration(140L)
            .start()
        label.setTextColor(color)
        label.animate()
            .alpha(if (active) 1f else 0.86f)
            .setDuration(140L)
            .start()
        tab.animate()
            .translationY(if (active) -1f else 0f)
            .setDuration(140L)
            .start()
    }

    private fun configureMoreCard(
        card: ItemMoreEntryBinding,
        iconRes: Int,
        labelRes: Int,
        iconChipBgRes: Int,
        iconTintColorRes: Int
    ) {
        card.moreCardIconChip.setBackgroundResource(iconChipBgRes)
        card.moreCardIconLight.setImageResource(iconRes)
        card.moreCardIcon.setImageResource(iconRes)
        card.moreCardIcon.imageTintList = ColorStateList.valueOf(getColor(iconTintColorRes))
        card.moreCardLabel.setText(labelRes)
    }

    private fun showLogoutConfirmDialogLegacy() {
        val dialog = AlertDialog.Builder(this)
            .setTitle("退出登录")
            .setMessage("确认退出当前登录账号吗？")
            .setNegativeButton("再看看", null)
            .setPositiveButton("退出登录") { _, _ ->
                PushWorkScheduler.cancel(this)
                AppGraph.repository.logout()
                startActivity(Intent(this, LoginActivity::class.java))
                finish()
            }
            .create()
        dialog.setOnShowListener {
            dialog.applyMetrologyDialogStyle(positiveStyle = DialogPositiveStyle.DANGER)
        }
        dialog.show()
    }
}
