package com.metrology.app

import android.app.AlertDialog
import android.app.DatePickerDialog
import android.content.res.ColorStateList
import android.os.Bundle
import android.text.InputType
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.graphics.Typeface
import android.widget.ArrayAdapter
import android.widget.AutoCompleteTextView
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.core.widget.doOnTextChanged
import androidx.fragment.app.Fragment
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.metrology.app.databinding.FragmentDeviceListBinding
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.Locale

class DeviceListFragment : Fragment() {
    private var _binding: FragmentDeviceListBinding? = null
    private val binding get() = _binding!!

    private val adapter: DeviceAdapter by lazy {
        DeviceAdapter(
            mode = mode,
            onClick = { showDeviceDetail(it) },
            onQuickEdit = { handleQuickEdit(it) },
            onPageRequest = { targetPage -> requestLoad(page = targetPage) }
        )
    }

    private val mode: DeviceMode by lazy {
        val modeName = requireArguments().getString(ARG_MODE).orEmpty()
        runCatching { DeviceMode.valueOf(modeName) }.getOrElse { DeviceMode.LEDGER }
    }

    private val viewModel: DeviceListViewModel by lazy {
        ViewModelProvider(
            this,
            AppViewModelFactory { DeviceListViewModel(AppGraph.repository, mode) }
        )[DeviceListViewModel::class.java]
    }

    private var searchJob: Job? = null

    private var filterDept: String = ""
    private var filterValidity: String = ""
    private var filterUseStatus: String = ""
    private var filterNextDateFrom: String = ""
    private var filterNextDateTo: String = ""

    private var deptOptions: List<String> = emptyList()
    private var useStatusOptions: List<String> = emptyList()
    private val cycleDisplayOptions = listOf("半年", "一年")
    private val allOption = "\u5168\u90E8"
    private var filterCollapsed = true
    private var scrollChromeHidden = false

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentDeviceListBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        applyModeDefaultFilters()
        binding.deviceRecycler.layoutManager = LinearLayoutManager(requireContext())
        binding.deviceRecycler.adapter = adapter
        binding.deviceRecycler.itemAnimator = null
        binding.deviceRecycler.setHasFixedSize(true)
        binding.deviceRecycler.clipToPadding = false
        binding.deviceRecycler.setPadding(0, dp(4), 0, dp(8))
        setupAutoHideChromeOnScroll()

        binding.buttonSearch.setOnClickListener { toggleFilterPanel() }
        binding.buttonMoreFilters.setOnClickListener {
            val nextVisible = binding.layoutExtraActions.visibility != View.VISIBLE
            binding.layoutExtraActions.visibility = if (nextVisible) View.VISIBLE else View.GONE
            binding.buttonMoreFilters.text = if (nextVisible) "收起更多" else "更多功能"
        }
        binding.buttonResetFilters.setOnClickListener { resetFiltersAndReload() }
        binding.buttonResetInline.setOnClickListener { resetFiltersAndReload() }
        setupFilterDropdowns()
        setupDateRangeInputs()
        applyModeFilterVisibility()
        applyFilterPanelState()
        setupSummaryChipActions()

        binding.inputSearch.doOnTextChanged { _, _, _, _ ->
            scheduleReload()
        }

        observeState()
        loadFilterOptions()
        if (savedInstanceState == null) {
            requestLoad()
        }
    }

    private fun loadFilterOptions() {
        viewLifecycleOwner.lifecycleScope.launch {
            runCatching { AppGraph.repository.departments() }
                .onSuccess { depts ->
                    deptOptions = depts
                        .mapNotNull { it.name.fixMojibake().takeIf(String::isNotBlank) }
                        .distinct()
                        .sorted()
                    updateDeptDropdown()
                }
            runCatching { AppGraph.repository.deviceStatuses() }
                .onSuccess { statuses ->
                    useStatusOptions = statuses
                        .mapNotNull { it.name.fixMojibake().takeIf(String::isNotBlank) }
                        .distinct()
                        .sorted()
                    updateUseStatusDropdown()
                }
        }
    }

    private fun setupFilterDropdowns() {
        configureDropDownInput(binding.inputFilterDept, editable = false)
        configureDropDownInput(binding.inputFilterValidity, editable = false)
        configureDropDownInput(binding.inputFilterUseStatus, editable = false)

        setDropdownOptions(
            binding.inputFilterValidity,
            listOf(allOption, "\u6709\u6548", "\u5373\u5C06\u8FC7\u671F", "\u5931\u6548")
        )
        binding.inputFilterValidity.setText(allOption, false)
        binding.inputFilterValidity.setOnItemClickListener { _, _, position, _ ->
            val selected = (binding.inputFilterValidity.adapter.getItem(position) as? String).orEmpty()
            filterValidity = if (selected == allOption) "" else selected
            requestLoad(page = 1)
        }

        updateDeptDropdown()
        binding.inputFilterDept.setOnItemClickListener { _, _, position, _ ->
            val selected = (binding.inputFilterDept.adapter.getItem(position) as? String).orEmpty()
            filterDept = if (selected == allOption) "" else selected
            requestLoad(page = 1)
        }

        updateUseStatusDropdown()
        binding.inputFilterUseStatus.setOnItemClickListener { _, _, position, _ ->
            if (isCalibrationMode()) return@setOnItemClickListener
            val selected = (binding.inputFilterUseStatus.adapter.getItem(position) as? String).orEmpty()
            filterUseStatus = if (selected == allOption) "" else selected
            requestLoad(page = 1)
        }
    }

    private fun applyModeDefaultFilters() {
        if (isCalibrationMode()) {
            filterUseStatus = CALIBRATION_FIXED_USE_STATUS
        }
    }

    private fun setupDateRangeInputs() {
        setupDateInput(binding.inputNextDateFrom) { value ->
            filterNextDateFrom = value
            scheduleReload()
        }
        setupDateInput(binding.inputNextDateTo) { value ->
            filterNextDateTo = value
            scheduleReload()
        }
    }

    private fun applyModeFilterVisibility() {
        val ledgerMode = isLedgerMode()
        val showNextDateFilter = mode != DeviceMode.LEDGER
        binding.txtLabelNextDate.visibility = if (showNextDateFilter) View.VISIBLE else View.GONE
        binding.layoutNextDateRange.visibility = if (showNextDateFilter) View.VISIBLE else View.GONE
        binding.buttonResetInline.visibility = if (ledgerMode) View.VISIBLE else View.GONE
        binding.dividerMoreActions.visibility = if (ledgerMode) View.GONE else View.VISIBLE
        binding.buttonMoreFilters.visibility = if (ledgerMode) View.GONE else View.VISIBLE
        binding.layoutExtraActions.visibility = View.GONE
        binding.buttonMoreFilters.text = "更多功能"
        if (!showNextDateFilter) {
            filterNextDateFrom = ""
            filterNextDateTo = ""
            binding.inputNextDateFrom.setText("")
            binding.inputNextDateTo.setText("")
        }
    }

    private fun setupDateInput(input: EditText, onChanged: (String) -> Unit) {
        input.setOnClickListener {
            showDatePicker(input.text?.toString().orEmpty()) { value ->
                input.setText(value)
                onChanged(value)
            }
        }
        input.setOnLongClickListener {
            input.setText("")
            onChanged("")
            true
        }
    }

    private fun showDatePicker(currentValue: String, onChanged: (String) -> Unit) {
        val calendar = Calendar.getInstance()
        parseDate(currentValue)?.let { (year, month, day) ->
            calendar.set(year, month - 1, day)
        }

        val dialog = DatePickerDialog(
            requireContext(),
            { _, year, month, dayOfMonth ->
                val selected = formatDate(year, month + 1, dayOfMonth)
                onChanged(selected)
            },
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH),
            calendar.get(Calendar.DAY_OF_MONTH)
        )
        dialog.setButton(AlertDialog.BUTTON_NEUTRAL, "清空") { _, _ ->
            onChanged("")
        }
        dialog.show()
    }

    private fun parseDate(value: String): Triple<Int, Int, Int>? {
        val matcher = Regex("^(\\d{4})-(\\d{2})-(\\d{2})$").find(value.trim()) ?: return null
        val year = matcher.groupValues[1].toIntOrNull() ?: return null
        val month = matcher.groupValues[2].toIntOrNull() ?: return null
        val day = matcher.groupValues[3].toIntOrNull() ?: return null
        return Triple(year, month, day)
    }

    private fun formatDate(year: Int, month: Int, day: Int): String {
        return String.format(Locale.getDefault(), "%04d-%02d-%02d", year, month, day)
    }

    private fun toggleFilterPanel() {
        filterCollapsed = !filterCollapsed
        applyFilterPanelState()
    }

    private fun applyFilterPanelState() {
        binding.layoutFilterPanel.visibility = if (filterCollapsed) View.GONE else View.VISIBLE
        binding.buttonSearch.text = if (filterCollapsed) "\u5C55\u5F00" else "\u6536\u8D77"
    }

    private fun scheduleReload() {
        searchJob?.cancel()
        searchJob = viewLifecycleOwner.lifecycleScope.launch {
            delay(350L)
            requestLoad(page = 1)
        }
    }

    private fun setupAutoHideChromeOnScroll() {
        // Keep summary chips visible while scrolling for ledger/calibration/todo.
        scrollChromeHidden = false
        binding.layoutSummaryChips.visibility = View.VISIBLE
    }

    private fun refreshRecyclerEdgeIfNeeded(recyclerView: RecyclerView) {
        if (recyclerView.canScrollVertically(1) && recyclerView.canScrollVertically(-1)) return
        recyclerView.post {
            if (!isAdded || _binding == null) return@post
            recyclerView.invalidate()
            recyclerView.postInvalidateOnAnimation()
        }
    }

    private fun hideScrollChrome() {
        if (scrollChromeHidden) return
        scrollChromeHidden = true
        collapseChromeView(binding.layoutSummaryChips)
    }

    private fun showScrollChrome() {
        if (!scrollChromeHidden) return
        val recyclerView = binding.deviceRecycler
        val wasAtBottom = !recyclerView.canScrollVertically(1)
        scrollChromeHidden = false
        expandChromeView(binding.layoutSummaryChips)
        keepPagerFooterVisibleAfterChromeExpand(wasAtBottom)
    }

    private fun collapseChromeView(target: View) {
        target.animate().cancel()
        target.alpha = 1f
        target.translationY = 0f
        target.visibility = View.GONE
    }

    private fun expandChromeView(target: View) {
        target.animate().cancel()
        target.alpha = 1f
        target.translationY = 0f
        target.visibility = View.VISIBLE
    }

    private fun keepPagerFooterVisibleAfterChromeExpand(wasAtBottom: Boolean) {
        if (!wasAtBottom) return
        val recyclerView = binding.deviceRecycler
        recyclerView.post {
            if (!isAdded || _binding == null) return@post
            if (!recyclerView.canScrollVertically(1)) return@post
            val compensate = binding.layoutSummaryChips.height + dp(8)
            if (compensate > 0) {
                recyclerView.scrollBy(0, compensate)
            }
        }
    }

    private fun syncScrollChromeState() {
        if (scrollChromeHidden) {
            collapseChromeView(binding.layoutSummaryChips)
            return
        }
        expandChromeView(binding.layoutSummaryChips)
    }

    private fun configureDropDownInput(
        input: AutoCompleteTextView,
        editable: Boolean
    ) {
        input.threshold = 0
        input.setDropDownBackgroundResource(R.drawable.bg_dropdown_popup)
        input.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
        input.setTextColor(requireContext().getColor(R.color.textPrimary))
        input.setPadding(dp(10), dp(8), dp(36), dp(8))
        input.setCompoundDrawablesRelativeWithIntrinsicBounds(0, 0, R.drawable.ic_chevron_down_16, 0)
        input.compoundDrawablePadding = dp(6)
        input.compoundDrawableTintList =
            ColorStateList.valueOf(requireContext().getColor(R.color.textMuted))
        input.inputType = if (editable) InputType.TYPE_CLASS_TEXT else InputType.TYPE_NULL
        input.isFocusable = editable
        input.isFocusableInTouchMode = editable
        input.isCursorVisible = editable

        input.setOnTouchListener { view, event ->
            if (event.actionMasked == MotionEvent.ACTION_UP) {
                val iconTapStart = input.width - input.paddingRight - dp(18)
                if (event.x >= iconTapStart) {
                    showDropDownWithAllOptions(input)
                    view.performClick()
                    return@setOnTouchListener true
                }
            }
            false
        }
        input.setOnClickListener { showDropDownWithAllOptions(input) }
        input.setOnFocusChangeListener { _, hasFocus ->
            if (hasFocus) showDropDownWithAllOptions(input)
        }
    }

    private fun showDropDownWithAllOptions(input: AutoCompleteTextView) {
        val adapter = input.adapter as? ArrayAdapter<*>
        if (adapter == null) {
            input.post { input.showDropDown() }
            return
        }
        adapter.filter.filter(null) {
            input.post {
                if (input.isAttachedToWindow) {
                    input.showDropDown()
                }
            }
        }
    }

    private fun setDropdownOptions(input: AutoCompleteTextView, options: List<String>) {
        val normalizedOptions = options
            .map { it.fixMojibake().trim() }
            .filter { it.isNotBlank() }
            .distinct()
        input.setAdapter(
            ArrayAdapter(requireContext(), R.layout.item_dropdown_option, normalizedOptions)
        )
    }

    private fun updateDeptDropdown() {
        val options = listOf(allOption) + deptOptions
        setDropdownOptions(binding.inputFilterDept, options)
        if (filterDept.isNotBlank() && !deptOptions.contains(filterDept)) {
            filterDept = ""
        }
        binding.inputFilterDept.setText(filterDept.ifBlank { allOption }, false)
    }

    private fun updateUseStatusDropdown() {
        if (isCalibrationMode()) {
            setDropdownOptions(binding.inputFilterUseStatus, listOf(CALIBRATION_FIXED_USE_STATUS))
            filterUseStatus = CALIBRATION_FIXED_USE_STATUS
            binding.inputFilterUseStatus.setText(CALIBRATION_FIXED_USE_STATUS, false)
            binding.inputFilterUseStatus.isEnabled = false
            return
        }

        val options = listOf(allOption) + useStatusOptions
        setDropdownOptions(binding.inputFilterUseStatus, options)
        if (filterUseStatus.isNotBlank() && !useStatusOptions.contains(filterUseStatus)) {
            filterUseStatus = ""
        }
        binding.inputFilterUseStatus.setText(filterUseStatus.ifBlank { allOption }, false)
        binding.inputFilterUseStatus.isEnabled = true
    }

    private fun resetFiltersAndReload() {
        filterDept = ""
        filterValidity = ""
        filterUseStatus = if (isCalibrationMode()) CALIBRATION_FIXED_USE_STATUS else ""
        filterNextDateFrom = ""
        filterNextDateTo = ""
        binding.inputFilterDept.setText(allOption, false)
        binding.inputFilterValidity.setText(allOption, false)
        binding.inputFilterUseStatus.setText(
            if (isCalibrationMode()) CALIBRATION_FIXED_USE_STATUS else allOption,
            false
        )
        binding.inputNextDateFrom.setText("")
        binding.inputNextDateTo.setText("")
        binding.layoutExtraActions.visibility = View.GONE
        binding.buttonMoreFilters.text = "更多功能"
        requestLoad(page = 1)
    }

    private fun requestLoad(page: Int = 1) {
        val resolvedNextDateFrom = if (mode == DeviceMode.LEDGER) "" else filterNextDateFrom
        val resolvedNextDateTo = if (mode == DeviceMode.LEDGER) "" else filterNextDateTo
        viewModel.load(
            search = binding.inputSearch.text?.toString().orEmpty(),
            dept = filterDept,
            validity = filterValidity,
            useStatus = effectiveUseStatus(),
            nextDateFrom = resolvedNextDateFrom,
            nextDateTo = resolvedNextDateTo,
            page = page
        )
    }

    private fun isCalibrationMode(): Boolean = mode == DeviceMode.CALIBRATION

    private fun isCalibrationLikeMode(): Boolean =
        mode == DeviceMode.CALIBRATION || mode == DeviceMode.TODO

    private fun isLedgerMode(): Boolean = mode == DeviceMode.LEDGER

    private fun effectiveUseStatus(): String {
        return if (isCalibrationMode()) CALIBRATION_FIXED_USE_STATUS else filterUseStatus
    }

    private fun observeState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                if (!scrollChromeHidden) {
                    binding.layoutSummaryChips.visibility = View.VISIBLE
                }
                renderSummaryChips(state)
                updateQuickChipSelectionUi()
                syncScrollChromeState()

                when {
                    state.loading -> binding.txtDeviceStatus.showLoadingState()
                    !state.error.isNullOrBlank() -> binding.txtDeviceStatus.showErrorState(state.error.fixMojibake())
                    state.items.isEmpty() -> binding.txtDeviceStatus.showEmptyState(getString(R.string.label_empty))
                    else -> binding.txtDeviceStatus.showReadyState(getString(R.string.label_total, state.total.toInt()))
                }

                adapter.submitList(state.items)
                adapter.submitPager(state.page, state.totalPages, state.loading)
            }
        }
    }

    private fun setupSummaryChipActions() {
        setupSummaryChipPressFeedback()

        binding.chipTotal.setOnClickListener {
            when (mode) {
                DeviceMode.LEDGER -> applyLedgerQuickFilter(null)
                DeviceMode.CALIBRATION, DeviceMode.TODO -> applyValidityQuickFilter("")
            }
        }
        binding.chipValid.setOnClickListener {
            when (mode) {
                DeviceMode.LEDGER -> applyLedgerQuickFilter(UseStatusBucket.NORMAL)
                DeviceMode.CALIBRATION, DeviceMode.TODO -> applyValidityQuickFilter("有效")
            }
        }
        binding.chipWarning.setOnClickListener {
            when (mode) {
                DeviceMode.LEDGER -> applyLedgerQuickFilter(UseStatusBucket.FAULT)
                DeviceMode.CALIBRATION, DeviceMode.TODO -> applyValidityQuickFilter("即将过期")
            }
        }
        binding.chipExpired.setOnClickListener {
            when (mode) {
                DeviceMode.LEDGER -> applyLedgerQuickFilter(UseStatusBucket.SCRAP)
                DeviceMode.CALIBRATION, DeviceMode.TODO -> applyValidityQuickFilter("失效")
            }
        }
        binding.chipOther.setOnClickListener {
            if (mode == DeviceMode.LEDGER) {
                applyLedgerQuickFilter(UseStatusBucket.OTHER)
            }
        }
    }

    private fun setupSummaryChipPressFeedback() {
        listOf(
            binding.chipTotal,
            binding.chipValid,
            binding.chipWarning,
            binding.chipExpired,
            binding.chipOther
        ).forEach { chip ->
            chip.setOnTouchListener { _, event ->
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        chip.animate().cancel()
                        chip.animate()
                            .alpha(if (chip.isSelected) 0.88f else 0.7f)
                            .scaleX(0.965f)
                            .scaleY(0.965f)
                            .setDuration(90L)
                            .start()
                    }

                    MotionEvent.ACTION_UP,
                    MotionEvent.ACTION_CANCEL -> animateSummaryChipIdle(chip)
                }
                false
            }
        }
    }

    private fun applyLedgerQuickFilter(bucket: UseStatusBucket?) {
        filterUseStatus = bucket?.let { resolveQuickUseStatusValue(it) }.orEmpty()
        binding.inputFilterUseStatus.setText(filterUseStatus.ifBlank { allOption }, false)
        updateQuickChipSelectionUi()
        requestLoad(page = 1)
    }

    private fun resolveQuickUseStatusValue(bucket: UseStatusBucket): String {
        val options = useStatusOptions
        val canonical = when (bucket) {
            UseStatusBucket.NORMAL -> "正常"
            UseStatusBucket.FAULT -> "故障"
            UseStatusBucket.SCRAP -> "报废"
            UseStatusBucket.OTHER -> "其他"
        }
        if (options.isEmpty()) return canonical

        options.firstOrNull { it == canonical }?.let { return it }
        options.firstOrNull { resolveUseStatusBucket(it) == bucket }?.let { return it }
        return canonical
    }

    private fun applyValidityQuickFilter(value: String) {
        filterValidity = value
        binding.inputFilterValidity.setText(filterValidity.ifBlank { allOption }, false)
        updateQuickChipSelectionUi()
        requestLoad(page = 1)
    }

    private fun updateQuickChipSelectionUi() {
        when (mode) {
            DeviceMode.LEDGER -> {
                val selectedBucket = filterUseStatus.takeIf { it.isNotBlank() }?.let {
                    resolveUseStatusBucket(it)
                }
                applyQuickSelected(binding.chipTotal, selectedBucket == null)
                applyQuickSelected(binding.chipValid, selectedBucket == UseStatusBucket.NORMAL)
                applyQuickSelected(binding.chipWarning, selectedBucket == UseStatusBucket.FAULT)
                applyQuickSelected(binding.chipExpired, selectedBucket == UseStatusBucket.SCRAP)
                applyQuickSelected(binding.chipOther, selectedBucket == UseStatusBucket.OTHER)
            }

            DeviceMode.CALIBRATION,
            DeviceMode.TODO -> {
                val selectedValidity = filterValidity.fixMojibake()
                applyQuickSelected(binding.chipTotal, selectedValidity.isBlank())
                applyQuickSelected(binding.chipValid, selectedValidity == "有效")
                applyQuickSelected(binding.chipWarning, selectedValidity == "即将过期")
                applyQuickSelected(binding.chipExpired, selectedValidity == "失效")
                applyQuickSelected(binding.chipOther, false)
            }
        }
    }

    private fun applyQuickSelected(chip: TextView, selected: Boolean) {
        if (chip.visibility != View.VISIBLE) return
        chip.isSelected = selected
        chip.setTypeface(chip.typeface, if (selected) Typeface.BOLD else Typeface.NORMAL)
        if (selected) {
            when (chip.id) {
                R.id.chipValid -> chip.setBackgroundResource(R.drawable.bg_chip_valid_selected)
                R.id.chipWarning -> chip.setBackgroundResource(R.drawable.bg_chip_warning_selected)
                R.id.chipExpired -> chip.setBackgroundResource(R.drawable.bg_chip_expired_selected)
                else -> chip.setBackgroundResource(R.drawable.bg_chip_neutral_selected)
            }
            chip.setTextColor(requireContext().getColor(R.color.white))
        } else {
            when (chip.id) {
                R.id.chipValid -> chip.setBackgroundResource(R.drawable.bg_chip_valid)
                R.id.chipWarning -> chip.setBackgroundResource(R.drawable.bg_chip_warning)
                R.id.chipExpired -> chip.setBackgroundResource(R.drawable.bg_chip_expired)
                else -> chip.setBackgroundResource(R.drawable.bg_chip_neutral)
            }
            chip.setTextColor(
                requireContext().getColor(
                    when (chip.id) {
                        R.id.chipTotal -> R.color.navActive
                        R.id.chipValid -> R.color.statusValid
                        R.id.chipWarning -> R.color.statusWarning
                        R.id.chipExpired -> R.color.statusExpired
                        else -> R.color.textSecondary
                    }
                )
            )
        }
        animateSummaryChipIdle(chip)
    }

    private fun animateSummaryChipIdle(chip: TextView) {
        chip.animate().cancel()
        chip.animate()
            .alpha(if (chip.isSelected) 1f else 0.92f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(130L)
            .start()
    }

    private fun renderSummaryChips(state: DeviceListUiState) {
        when (mode) {
            DeviceMode.LEDGER -> renderLedgerSummaryChips(state)
            DeviceMode.CALIBRATION -> renderCalibrationSummaryChips(state)
            DeviceMode.TODO -> renderTodoSummaryChips(state)
        }
    }

    private fun renderLedgerSummaryChips(state: DeviceListUiState) {
        val summary = toUseStatusSummary(state)

        binding.chipTotal.text = "\u5171 ${state.total} \u53f0"
        styleChip(binding.chipTotal, R.drawable.bg_chip_neutral, R.color.navActive, visible = true)

        binding.chipValid.text = "\u6b63\u5e38 ${summary.normal}"
        styleChip(binding.chipValid, R.drawable.bg_chip_valid, R.color.statusValid, visible = true)

        binding.chipWarning.text = "\u6545\u969c ${summary.fault}"
        styleChip(binding.chipWarning, R.drawable.bg_chip_warning, R.color.statusWarning, visible = true)

        binding.chipExpired.text = "\u62a5\u5e9f ${summary.scrap}"
        styleChip(binding.chipExpired, R.drawable.bg_chip_expired, R.color.statusExpired, visible = true)

        binding.chipOther.text = "\u5176\u4ed6 ${summary.other}"
        styleChip(binding.chipOther, R.drawable.bg_chip_neutral, R.color.textSecondary, visible = true)
    }

    private fun renderCalibrationSummaryChips(state: DeviceListUiState) {
        val valid = state.summaryCounts["\u6709\u6548"] ?: 0L
        val warning = state.summaryCounts["\u5373\u5c06\u8fc7\u671f"] ?: 0L
        val expired = state.summaryCounts["\u5931\u6548"] ?: 0L

        binding.chipTotal.text = "\u5171 ${state.total} \u6761"
        styleChip(binding.chipTotal, R.drawable.bg_chip_neutral, R.color.navActive, visible = true)

        binding.chipValid.text = "\u6709\u6548 $valid"
        styleChip(binding.chipValid, R.drawable.bg_chip_valid, R.color.statusValid, visible = true)

        binding.chipWarning.text = "\u5373\u5c06\u8fc7\u671f $warning"
        styleChip(binding.chipWarning, R.drawable.bg_chip_warning, R.color.statusWarning, visible = true)

        binding.chipExpired.text = "\u5931\u6548 $expired"
        styleChip(binding.chipExpired, R.drawable.bg_chip_expired, R.color.statusExpired, visible = true)

        styleChip(binding.chipOther, R.drawable.bg_chip_neutral, R.color.textSecondary, visible = false)
    }

    private fun renderTodoSummaryChips(state: DeviceListUiState) {
        val warning = state.summaryCounts["\u5373\u5c06\u8fc7\u671f"] ?: 0L
        val expired = state.summaryCounts["\u5931\u6548"] ?: 0L

        binding.chipTotal.text = "\u5f85\u5904\u7406 ${state.total} \u6761"
        styleChip(binding.chipTotal, R.drawable.bg_chip_neutral, R.color.navActive, visible = true)

        styleChip(binding.chipValid, R.drawable.bg_chip_valid, R.color.statusValid, visible = false)

        binding.chipWarning.text = "\u5373\u5c06\u8fc7\u671f $warning"
        styleChip(binding.chipWarning, R.drawable.bg_chip_warning, R.color.statusWarning, visible = true)

        binding.chipExpired.text = "\u5931\u6548 $expired"
        styleChip(binding.chipExpired, R.drawable.bg_chip_expired, R.color.statusExpired, visible = true)

        styleChip(binding.chipOther, R.drawable.bg_chip_neutral, R.color.textSecondary, visible = false)
    }

    private fun toUseStatusSummary(state: DeviceListUiState): UseStatusSummary {
        if (state.useStatusSummary.isNotEmpty()) {
            return aggregateUseStatusSummary(state.useStatusSummary)
        }
        val fallback = mutableMapOf<String, Long>()
        state.items.forEach { item ->
            val key = item.useStatus.fixMojibake().ifBlank { "\u5176\u4ed6" }
            fallback[key] = (fallback[key] ?: 0L) + 1L
        }
        return aggregateUseStatusSummary(fallback)
    }

    private fun aggregateUseStatusSummary(rawSummary: Map<String, Long>): UseStatusSummary {
        var normal = 0L
        var fault = 0L
        var scrap = 0L
        var other = 0L

        rawSummary.forEach { (rawKey, countValue) ->
            val count = countValue.coerceAtLeast(0L)
            when (resolveUseStatusBucket(rawKey)) {
                UseStatusBucket.NORMAL -> normal += count
                UseStatusBucket.FAULT -> fault += count
                UseStatusBucket.SCRAP -> scrap += count
                UseStatusBucket.OTHER -> other += count
            }
        }

        return UseStatusSummary(
            normal = normal,
            fault = fault,
            scrap = scrap,
            other = other
        )
    }

    private fun resolveUseStatusBucket(rawStatus: String?): UseStatusBucket {
        val text = rawStatus.fixMojibake()
        return when {
            text.contains("\u6b63\u5e38") ||
                text.contains("\u5728\u7528") ||
                text.contains("\u4f7f\u7528\u4e2d") -> UseStatusBucket.NORMAL

            text.contains("\u6545\u969c") ||
                text.contains("\u7ef4\u4fee") ||
                text.contains("\u4fdd\u517b") ||
                text.contains("\u68c0\u4fee") ||
                text.contains("\u505c\u673a") -> UseStatusBucket.FAULT

            text.contains("\u62a5\u5e9f") ||
                text.contains("\u505c\u7528") ||
                text.contains("\u7981\u7528") ||
                text.contains("\u4e22\u5931") -> UseStatusBucket.SCRAP

            else -> UseStatusBucket.OTHER
        }
    }

    private fun styleChip(
        chip: TextView,
        backgroundRes: Int,
        textColorRes: Int,
        visible: Boolean
    ) {
        chip.visibility = if (visible) View.VISIBLE else View.GONE
        chip.isEnabled = visible
        chip.isClickable = visible
        if (!visible) return
        chip.setBackgroundResource(backgroundRes)
        chip.setTextColor(requireContext().getColor(textColorRes))
    }

    private data class UseStatusSummary(
        val normal: Long = 0L,
        val fault: Long = 0L,
        val scrap: Long = 0L,
        val other: Long = 0L
    )

    private enum class UseStatusBucket {
        NORMAL,
        FAULT,
        SCRAP,
        OTHER
    }

    private fun showDeviceDetail(item: DeviceDto) {
        when {
            isLedgerMode() -> showLedgerDetailDialog(item)
            isCalibrationLikeMode() -> showCalibrationDetailDialog(item)
        }
    }

    private fun showReadOnlyDetailDialog(item: DeviceDto) {
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle(item.name.fixMojibake().ifBlank { "设备详情" })
            .setMessage(buildAllPropertyText(item))
            .setPositiveButton("关闭", null)
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun showLedgerDetailDialog(item: DeviceDto) {
        val detailView = buildLedgerDetailView(item)
        val title = "设备详情 - ${item.name.fixMojibake().ifBlank { "未命名设备" }}"
        val content = layoutInflater.inflate(R.layout.dialog_device_detail_fullscreen, null)
        content.findViewById<TextView>(R.id.txtLedgerDetailTitle).text = title
        val bodyContainer = content.findViewById<ViewGroup>(R.id.layoutLedgerDetailContent)
        bodyContainer.addView(
            detailView,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        val dialog = AlertDialog.Builder(requireContext())
            .setView(content)
            .create()

        content.findViewById<View>(R.id.buttonLedgerDetailClose).setOnClickListener {
            dialog.dismiss()
        }
        content.findViewById<View>(R.id.buttonLedgerDetailEdit).setOnClickListener {
            dialog.dismiss()
            showLedgerEditDialog(item)
        }
        content.findViewById<View>(R.id.buttonLedgerDetailDelete).setOnClickListener {
            dialog.dismiss()
            confirmDeleteDevice(item)
        }

        dialog.show()
        dialog.window?.setBackgroundDrawableResource(R.drawable.bg_card)
        dialog.window?.setLayout(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    }

    private fun buildLedgerDetailView(item: DeviceDto): View {
        val (scrollView, container) = createFormContainer()

        addDetailSectionTitle(container, "基本信息")
        addDetailPairRow(
            container,
            "仪器名称",
            item.name.fixMojibakeOrDash(),
            "计量编号",
            item.metricNo.fixMojibakeOrDash()
        )
        addDetailPairRow(
            container,
            "资产编号",
            item.assetNo.fixMojibakeOrDash(),
            "出厂编号",
            item.serialNo.fixMojibakeOrDash()
        )
        addDetailPairRow(
            container,
            "ABC分类",
            item.abcClass.fixMojibakeOrDash(),
            "设备型号",
            item.model.fixMojibakeOrDash()
        )
        addDetailPairRow(
            container,
            "制造厂",
            item.manufacturer.fixMojibakeOrDash(),
            "使用部门",
            item.dept.fixMojibakeOrDash()
        )
        addDetailPairRow(
            container,
            "设备位置",
            item.location.fixMojibakeOrDash(),
            "使用责任人",
            item.responsiblePerson.fixMojibakeOrDash()
        )
        addDetailSingleRow(
            container,
            "使用状态",
            item.useStatus.fixMojibakeOrDash(),
            chipStyle = DetailChipStyle.USE_STATUS
        )

        addDetailDivider(container)
        addDetailSectionTitle(container, "采购信息")
        addDetailPairRow(
            container,
            "采购时间",
            item.purchaseDate.fixMojibakeOrDash(),
            "采购价格",
            item.purchasePrice?.let { "¥${it.toLong()}" }.fixMojibakeOrDash()
        )
        addDetailSingleRow(
            container,
            "使用年限",
            item.serviceLife?.let { "$it 年" } ?: "-"
        )

        addDetailDivider(container)
        addDetailSectionTitle(container, "技术参数")
        addDetailPairRow(
            container,
            "分度值",
            item.graduationValue.fixMojibakeOrDash(),
            "测试范围",
            item.testRange.fixMojibakeOrDash()
        )
        addDetailSingleRow(
            container,
            "允许误差",
            item.allowableError.fixMojibakeOrDash()
        )

        addDetailDivider(container)
        addDetailSectionTitle(container, "校准信息")
        addDetailPairRow(
            container,
            "上次校准",
            item.calDate.fixMojibakeOrDash(),
            "下次校准",
            item.nextDate.fixMojibakeOrDash()
        )
        addDetailPairRow(
            container,
            "检定周期",
            formatCycleDisplay(item.cycle),
            "校准结果",
            item.calibrationResult.fixMojibakeOrDash()
        )
        addDetailSingleRow(
            container,
            "有效状态",
            item.validity.fixMojibakeOrDash(),
            chipStyle = DetailChipStyle.VALIDITY
        )
        addDetailSingleRow(
            container,
            "备注",
            item.remark.fixMojibakeOrDash()
        )

        return scrollView
    }

    private fun addDetailSectionTitle(container: LinearLayout, title: String) {
        val sectionTitle = TextView(requireContext()).apply {
            text = title
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setTextColor(requireContext().getColor(R.color.textPrimary))
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(6)
                bottomMargin = dp(6)
            }
        }
        container.addView(sectionTitle)
    }

    private fun addDetailDivider(container: LinearLayout) {
        val divider = View(requireContext()).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(1)
            ).apply {
                topMargin = dp(12)
                bottomMargin = dp(12)
            }
            setBackgroundColor(requireContext().getColor(R.color.navBarStroke))
        }
        container.addView(divider)
    }

    private fun addDetailPairRow(
        container: LinearLayout,
        leftLabel: String,
        leftValue: String,
        rightLabel: String,
        rightValue: String,
        leftChipStyle: DetailChipStyle = DetailChipStyle.NONE,
        rightChipStyle: DetailChipStyle = DetailChipStyle.NONE
    ) {
        val row = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(6) }
        }

        val leftColumn = createDetailColumn(leftLabel, leftValue, leftChipStyle)
        val rightColumn = createDetailColumn(rightLabel, rightValue, rightChipStyle)

        row.addView(
            leftColumn,
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        )
        row.addView(
            rightColumn,
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(12)
            }
        )
        container.addView(row)
    }

    private fun addDetailSingleRow(
        container: LinearLayout,
        label: String,
        value: String,
        chipStyle: DetailChipStyle = DetailChipStyle.NONE
    ) {
        val row = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(8) }
        }
        val column = createDetailColumn(label, value, chipStyle)
        row.addView(column)
        container.addView(row)
    }

    private fun createDetailColumn(
        label: String,
        value: String,
        chipStyle: DetailChipStyle
    ): LinearLayout {
        val column = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
        }

        val labelView = TextView(requireContext()).apply {
            text = label
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setTextColor(requireContext().getColor(R.color.textSecondary))
        }
        column.addView(labelView)

        val valueView = TextView(requireContext()).apply {
            text = value.ifBlank { "-" }
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setTextColor(requireContext().getColor(R.color.textPrimary))
            setLineSpacing(0f, 1.15f)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(4) }
        }

        when (chipStyle) {
            DetailChipStyle.NONE -> {
                // no-op
            }
            DetailChipStyle.NEUTRAL -> {
                applyChipStyle(valueView, R.drawable.bg_chip_neutral, R.color.textSecondary)
            }
            DetailChipStyle.USE_STATUS -> {
                applyUseStatusChipStyle(valueView, value)
            }
            DetailChipStyle.VALIDITY -> {
                applyValidityChipStyle(valueView, value)
            }
        }

        column.addView(valueView)
        return column
    }

    private fun applyChipStyle(textView: TextView, backgroundRes: Int, textColorRes: Int) {
        textView.background = requireContext().getDrawable(backgroundRes)
        textView.setTextColor(requireContext().getColor(textColorRes))
        textView.setPadding(dp(10), dp(4), dp(10), dp(4))
        textView.gravity = Gravity.CENTER_VERTICAL
    }

    private fun applyUseStatusChipStyle(textView: TextView, rawValue: String) {
        val value = rawValue.fixMojibake()
        when {
            value.contains("正常") || value.contains("在用") || value.contains("使用中") -> {
                applyChipStyle(textView, R.drawable.bg_chip_valid, R.color.statusValid)
            }
            value.contains("故障") || value.contains("维修") || value.contains("保养") ||
                value.contains("检修") || value.contains("停机") -> {
                applyChipStyle(textView, R.drawable.bg_chip_warning, R.color.statusWarning)
            }
            value.contains("报废") || value.contains("停用") || value.contains("禁用") || value.contains("丢失") -> {
                applyChipStyle(textView, R.drawable.bg_chip_expired, R.color.statusExpired)
            }
            else -> {
                applyChipStyle(textView, R.drawable.bg_chip_neutral, R.color.textSecondary)
            }
        }
    }

    private fun applyValidityChipStyle(textView: TextView, rawValue: String) {
        when (rawValue.fixMojibake()) {
            "有效" -> applyChipStyle(textView, R.drawable.bg_chip_valid, R.color.statusValid)
            "即将过期" -> applyChipStyle(textView, R.drawable.bg_chip_warning, R.color.statusWarning)
            "失效" -> applyChipStyle(textView, R.drawable.bg_chip_expired, R.color.statusExpired)
            else -> applyChipStyle(textView, R.drawable.bg_chip_neutral, R.color.textSecondary)
        }
    }

    private enum class DetailChipStyle {
        NONE,
        NEUTRAL,
        USE_STATUS,
        VALIDITY
    }

    private fun showCalibrationDetailDialog(item: DeviceDto) {
        val detailView = buildCalibrationDetailView(item)
        val titlePrefix = if (mode == DeviceMode.TODO) "待办记录" else "校准记录"
        val title = "$titlePrefix - ${item.name.fixMojibake().ifBlank { "未命名设备" }}"
        val content = layoutInflater.inflate(R.layout.dialog_device_detail_fullscreen, null)
        content.findViewById<TextView>(R.id.txtLedgerDetailTitle).text = title
        val bodyContainer = content.findViewById<ViewGroup>(R.id.layoutLedgerDetailContent)
        bodyContainer.addView(
            detailView,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        content.findViewById<TextView>(R.id.buttonLedgerDetailDelete).visibility = View.GONE

        val dialog = AlertDialog.Builder(requireContext())
            .setView(content)
            .create()

        content.findViewById<View>(R.id.buttonLedgerDetailClose).setOnClickListener {
            dialog.dismiss()
        }
        content.findViewById<View>(R.id.buttonLedgerDetailEdit).setOnClickListener {
            dialog.dismiss()
            showCalibrationEditDialog(item)
        }

        dialog.show()
        dialog.window?.setBackgroundDrawableResource(R.drawable.bg_card)
        dialog.window?.setLayout(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    }

    private fun buildCalibrationDetailView(item: DeviceDto): View {
        val (scrollView, container) = createFormContainer()

        addDetailSectionTitle(container, "设备信息")
        addDetailPairRow(
            container,
            "设备名称",
            item.name.fixMojibakeOrDash(),
            "计量编号",
            item.metricNo.fixMojibakeOrDash()
        )
        addDetailPairRow(
            container,
            "使用部门",
            item.dept.fixMojibakeOrDash(),
            "使用责任人",
            item.responsiblePerson.fixMojibakeOrDash()
        )
        addDetailSingleRow(
            container,
            "使用状态",
            item.useStatus.fixMojibakeOrDash(),
            chipStyle = DetailChipStyle.USE_STATUS
        )

        addDetailDivider(container)
        addDetailSectionTitle(container, "校准信息")
        addDetailPairRow(
            container,
            "上次校准",
            item.calDate.fixMojibakeOrDash(),
            "下次校准",
            item.nextDate.fixMojibakeOrDash()
        )
        addDetailPairRow(
            container,
            "检定周期",
            formatCycleDisplay(item.cycle),
            "校准结果",
            item.calibrationResult.fixMojibakeOrDash()
        )
        addDetailSingleRow(
            container,
            "有效状态",
            item.validity.fixMojibakeOrDash(),
            chipStyle = DetailChipStyle.VALIDITY
        )
        addDetailSingleRow(
            container,
            "备注",
            item.remark.fixMojibakeOrDash()
        )

        return scrollView
    }

    private fun handleQuickEdit(item: DeviceDto) {
        when {
            isLedgerMode() -> showQuickEditDialog(item)
            isCalibrationLikeMode() -> showCalibrationQuickEditDialog(item)
        }
    }

    private fun showCalibrationQuickEditDialog(item: DeviceDto) {
        showCalibrationEditDialogInternal(
            item = item,
            dialogTitle = "快改校准记录",
            successMessage = "校准记录已快改"
        )
    }

    private fun showQuickEditDialog(item: DeviceDto) {
        if (mode != DeviceMode.LEDGER) return
        val id = item.id ?: return
        val (scrollView, container) = createFormContainer()
        val deptEditOptions = buildDeptEditOptions(item.dept)
        val useStatusEditOptions = buildUseStatusEditOptions(item.useStatus)

        val nameInput = addFormInput(container, "设备名称*", item.name)
        val metricNoInput = addFormInput(container, "计量编号*", item.metricNo)
        val assetNoInput = addFormInput(container, "资产编号", item.assetNo)
        val deptInput = addFormDropdownInput(
            container = container,
            label = "使用部门",
            options = deptEditOptions,
            value = item.dept,
            editable = true
        )
        val responsibleInput = addFormInput(container, "责任人", item.responsiblePerson)
        val useStatusInput = addFormDropdownInput(
            container = container,
            label = "使用状态",
            options = useStatusEditOptions,
            value = item.useStatus,
            editable = true
        )

        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("快改卡片信息")
            .setView(scrollView)
            .setNegativeButton("取消", null)
            .setPositiveButton("保存修改", null)
            .create()

        dialog.setOnShowListener {
            styleFormDialogButtons(dialog)
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                val name = nameInput.textValue()
                val metricNo = metricNoInput.textValue()
                if (name.isBlank() || metricNo.isBlank()) {
                    toast("设备名称和计量编号不能为空")
                    return@setOnClickListener
                }

                val payload = DeviceUpdatePayload(
                    name = name,
                    metricNo = metricNo,
                    assetNo = assetNoInput.textValue(),
                    abcClass = item.abcClass,
                    dept = deptInput.textValue(),
                    location = item.location,
                    cycle = item.cycle ?: 12,
                    calDate = item.calDate,
                    status = item.status,
                    remark = item.remark,
                    useStatus = useStatusInput.textValue(),
                    serialNo = item.serialNo,
                    purchasePrice = item.purchasePrice,
                    purchaseDate = item.purchaseDate,
                    calibrationResult = item.calibrationResult,
                    responsiblePerson = responsibleInput.textValue(),
                    manufacturer = item.manufacturer,
                    model = item.model,
                    graduationValue = item.graduationValue,
                    testRange = item.testRange,
                    allowableError = item.allowableError
                )

                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.updateDevice(id, payload) }
                        .onSuccess {
                            toast("卡片信息已更新")
                            dialog.dismiss()
                            requestLoad(page = viewModel.uiState.value.page)
                        }
                        .onFailure {
                            toast(it.toUserMessage("快改失败"))
                        }
                }
            }
        }

        dialog.show()
    }

    private fun confirmDeleteDevice(item: DeviceDto) {
        val id = item.id ?: return
        val content = layoutInflater.inflate(R.layout.dialog_delete_device_confirm, null)
        val dialog = AlertDialog.Builder(requireContext())
            .setView(content)
            .create()

        content.findViewById<TextView>(R.id.txtDeleteDeviceName).text =
            item.name.fixMojibake().ifBlank { "未命名设备" }
        content.findViewById<TextView>(R.id.txtDeleteMetricNo).text =
            item.metricNo.fixMojibakeOrDash()
        content.findViewById<TextView>(R.id.txtDeleteDept).text =
            item.dept.fixMojibakeOrDash()
        content.findViewById<TextView>(R.id.txtDeleteResponsible).text =
            item.responsiblePerson.fixMojibakeOrDash()
        content.findViewById<TextView>(R.id.txtDeleteValidity).apply {
            text = item.validity.fixMojibakeOrDash()
            applyValidityChipStyle(this, item.validity.fixMojibake())
        }

        content.findViewById<ImageView>(R.id.buttonCloseDeleteDialog).setOnClickListener {
            dialog.dismiss()
        }
        content.findViewById<TextView>(R.id.buttonCancelDeleteDevice).setOnClickListener {
            dialog.dismiss()
        }
        content.findViewById<TextView>(R.id.buttonConfirmDeleteDevice).setOnClickListener {
            viewLifecycleOwner.lifecycleScope.launch {
                runCatching { AppGraph.repository.deleteDevice(id) }
                    .onSuccess {
                        toast("删除已处理")
                        dialog.dismiss()
                        requestLoad(page = viewModel.uiState.value.page)
                    }
                    .onFailure {
                        toast(it.toUserMessage("删除设备失败"))
                    }
            }
        }

        dialog.show()
        dialog.window?.setBackgroundDrawableResource(R.drawable.bg_card)
    }

    private fun showLedgerEditDialog(item: DeviceDto) {
        val id = item.id ?: return
        val (scrollView, container) = createFormContainer()

        val abcClassOptions = buildAbcClassOptions(item.abcClass)
        val deptEditOptions = buildDeptEditOptions(item.dept)
        val useStatusEditOptions = buildUseStatusEditOptions(item.useStatus)

        val nameInput = addFormInput(container, "设备名称*", item.name)
        val metricNoInput = addFormInput(container, "计量编号*", item.metricNo)
        val assetNoInput = addFormInput(container, "资产编号", item.assetNo)
        val serialNoInput = addFormInput(container, "出厂编号", item.serialNo)
        val abcClassInput = addFormDropdownInput(
            container = container,
            label = "ABC分类",
            options = abcClassOptions,
            value = item.abcClass,
            editable = true
        )
        val deptInput = addFormDropdownInput(
            container = container,
            label = "使用部门",
            options = deptEditOptions,
            value = item.dept,
            editable = true
        )
        val locationInput = addFormInput(container, "设备位置", item.location)
        val responsibleInput = addFormInput(container, "责任人", item.responsiblePerson)
        val useStatusInput = addFormDropdownInput(
            container = container,
            label = "使用状态",
            options = useStatusEditOptions,
            value = item.useStatus,
            editable = true
        )
        val manufacturerInput = addFormInput(container, "制造厂", item.manufacturer)
        val modelInput = addFormInput(container, "设备型号", item.model)
        val purchaseDateInput = addFormInput(container, "采购时间(YYYY-MM-DD)", item.purchaseDate)
        configureDatePickerOnlyInput(purchaseDateInput)
        val purchasePriceInput = addFormInput(
            container,
            "采购价格(元)",
            item.purchasePrice?.toString(),
            InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
        )
        val graduationInput = addFormInput(container, "分度值", item.graduationValue)
        val testRangeInput = addFormInput(container, "测试范围", item.testRange)
        val allowableErrorInput = addFormInput(container, "允许误差", item.allowableError)
        val cycleInput = addFormDropdownInput(
            container = container,
            label = "检定周期（半年/一年）",
            options = cycleDisplayOptions,
            value = formatCycleInputValue(item.cycle)
        )
        val calDateInput = addFormInput(container, "上次校准时间(YYYY-MM-DD)", item.calDate)
        configureDatePickerOnlyInput(calDateInput)
        val calibrationResultInput = addFormDropdownInput(
            container = container,
            label = "校准结果",
            options = buildCalibrationResultOptions(item.calibrationResult),
            value = item.calibrationResult,
            editable = true
        )
        val remarkInput = addFormInput(container, "备注", item.remark)

        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("编辑设备")
            .setView(scrollView)
            .setNegativeButton("取消", null)
            .setPositiveButton("保存修改", null)
            .create()

        dialog.setOnShowListener {
            styleFormDialogButtons(dialog)
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                val name = nameInput.textValue()
                val metricNo = metricNoInput.textValue()
                if (name.isBlank() || metricNo.isBlank()) {
                    toast("设备名称和计量编号不能为空")
                    return@setOnClickListener
                }

                val purchasePrice = purchasePriceInput.textValue().toDoubleOrNull()
                if (purchasePriceInput.textValue().isNotBlank() && purchasePrice == null) {
                    toast("采购价格格式不正确")
                    return@setOnClickListener
                }

                val cycle = parseCycleInput(cycleInput.textValue())
                if (cycleInput.textValue().isNotBlank() && cycle == null) {
                    toast("检定周期仅支持半年或一年")
                    return@setOnClickListener
                }

                val payload = DeviceUpdatePayload(
                    name = name,
                    metricNo = metricNo,
                    assetNo = assetNoInput.textValue(),
                    abcClass = abcClassInput.text?.toString()?.trim().orEmpty(),
                    dept = deptInput.text?.toString()?.trim().orEmpty(),
                    location = locationInput.textValue(),
                    cycle = cycle ?: item.cycle ?: 12,
                    calDate = calDateInput.textValue(),
                    status = item.status,
                    remark = remarkInput.textValue(),
                    useStatus = useStatusInput.text?.toString()?.trim().orEmpty(),
                    serialNo = serialNoInput.textValue(),
                    purchasePrice = purchasePrice,
                    purchaseDate = purchaseDateInput.textValue(),
                    calibrationResult = calibrationResultInput.textValue(),
                    responsiblePerson = responsibleInput.textValue(),
                    manufacturer = manufacturerInput.textValue(),
                    model = modelInput.textValue(),
                    graduationValue = graduationInput.textValue(),
                    testRange = testRangeInput.textValue(),
                    allowableError = allowableErrorInput.textValue()
                )

                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.updateDevice(id, payload) }
                        .onSuccess {
                            toast("设备已更新")
                            dialog.dismiss()
                            requestLoad(page = viewModel.uiState.value.page)
                        }
                        .onFailure {
                            toast(it.toUserMessage("更新设备失败"))
                        }
                }
            }
        }

        dialog.show()
    }

    private fun showCalibrationEditDialog(item: DeviceDto) {
        showCalibrationEditDialogInternal(
            item = item,
            dialogTitle = "编辑校准记录",
            successMessage = "校准记录已更新"
        )
    }

    private fun showCalibrationEditDialogInternal(
        item: DeviceDto,
        dialogTitle: String,
        successMessage: String
    ) {
        val id = item.id ?: return
        val (scrollView, container) = createFormContainer()

        val defaultCalDate = todayDateString()
        val calDateInput = addFormInput(
            container,
            "本次校准时间(YYYY-MM-DD)",
            defaultCalDate
        ).apply {
            inputType = InputType.TYPE_NULL
            isFocusable = false
            isFocusableInTouchMode = false
            setOnClickListener {
                showDatePicker(textValue()) { value ->
                    setText(value)
                }
            }
            setOnLongClickListener {
                setText(defaultCalDate)
                true
            }
        }
        val cycleInput = addFormDropdownInput(
            container = container,
            label = "检定周期（半年/一年）",
            options = cycleDisplayOptions,
            value = formatCycleInputValue(item.cycle)
        )
        val resultInput = addFormDropdownInput(
            container = container,
            label = "校准结果",
            options = buildCalibrationResultOptions("合格"),
            value = "合格"
        )
        val remarkInput = addFormInput(container, "备注", item.remark)

        val dialog = AlertDialog.Builder(requireContext())
            .setTitle(dialogTitle)
            .setView(scrollView)
            .setNegativeButton("取消", null)
            .setPositiveButton("保存修改", null)
            .create()

        dialog.setOnShowListener {
            styleFormDialogButtons(dialog)
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                val cycle = parseCycleInput(cycleInput.textValue())
                if (cycleInput.textValue().isNotBlank() && cycle == null) {
                    toast("检定周期仅支持半年或一年")
                    return@setOnClickListener
                }

                val payload = DeviceCalibrationPayload(
                    calDate = calDateInput.textValue().ifBlank { defaultCalDate },
                    cycle = cycle ?: item.cycle ?: 12,
                    calibrationResult = resultInput.text?.toString()?.trim().orEmpty().ifBlank { "合格" },
                    remark = remarkInput.textValue()
                )

                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.updateDeviceCalibration(id, payload) }
                        .onSuccess {
                            toast(successMessage)
                            dialog.dismiss()
                            requestLoad(page = viewModel.uiState.value.page)
                        }
                        .onFailure {
                            toast(it.toUserMessage("更新校准记录失败"))
                        }
                }
            }
        }

        dialog.show()
    }

    private fun styleFormDialogButtons(dialog: AlertDialog) {
        dialog.applyMetrologyDialogStyle()
        val negativeButton = dialog.getButton(AlertDialog.BUTTON_NEGATIVE) ?: return
        val positiveButton = dialog.getButton(AlertDialog.BUTTON_POSITIVE) ?: return
        negativeButton.text = "取消"
        positiveButton.text = "保存修改"
        styleDialogActionButton(
            button = negativeButton,
            backgroundRes = R.drawable.bg_dialog_action_cancel,
            textColorRes = R.color.dialogActionCancelText
        )
        styleDialogActionButton(
            button = positiveButton,
            backgroundRes = R.drawable.bg_dialog_action_save,
            textColorRes = R.color.white
        )
        updateDialogActionButtonLayout(
            button = negativeButton,
            marginStart = 0,
            marginEnd = dp(6)
        )
        updateDialogActionButtonLayout(
            button = positiveButton,
            marginStart = dp(6),
            marginEnd = 0
        )
    }

    private fun styleDialogActionButton(
        button: Button,
        backgroundRes: Int,
        textColorRes: Int
    ) {
        button.visibility = View.VISIBLE
        button.isEnabled = true
        button.setAllCaps(false)
        button.textSize = 14f
        button.setTextColor(requireContext().getColor(textColorRes))
        button.backgroundTintList = null
        button.setBackgroundResource(backgroundRes)
        button.alpha = 1f
        button.stateListAnimator = null
        button.gravity = Gravity.CENTER
        button.minHeight = dp(42)
        button.setPadding(dp(10), 0, dp(10), 0)
    }

    private fun updateDialogActionButtonLayout(
        button: Button,
        marginStart: Int,
        marginEnd: Int
    ) {
        val params = button.layoutParams as? LinearLayout.LayoutParams ?: return
        val parent = button.parent as? LinearLayout
        val isHorizontal = parent?.orientation == LinearLayout.HORIZONTAL
        val isPrimaryButton = marginStart > marginEnd
        if (isHorizontal) {
            params.width = 0
            params.weight = 1f
            params.height = dp(44)
            params.marginStart = dp(6)
            params.marginEnd = dp(6)
            params.topMargin = 0
            params.bottomMargin = 0
        } else {
            params.width = ViewGroup.LayoutParams.MATCH_PARENT
            params.weight = 0f
            params.height = dp(44)
            params.marginStart = 0
            params.marginEnd = 0
            params.topMargin = if (isPrimaryButton) dp(8) else 0
            params.bottomMargin = 0
        }
        button.layoutParams = params
    }

    private fun buildAllPropertyText(item: DeviceDto): String {
        return buildString {
            appendLine("设备名称: ${item.name.fixMojibakeOrDash()}")
            appendLine("计量编号: ${item.metricNo.fixMojibakeOrDash()}")
            appendLine("资产编号: ${item.assetNo.fixMojibakeOrDash()}")
            appendLine("出厂编号: ${item.serialNo.fixMojibakeOrDash()}")
            appendLine("ABC分类: ${item.abcClass.fixMojibakeOrDash()}")
            appendLine("使用部门: ${item.dept.fixMojibakeOrDash()}")
            appendLine("设备位置: ${item.location.fixMojibakeOrDash()}")
            appendLine("责任人: ${item.responsiblePerson.fixMojibakeOrDash()}")
            appendLine("使用状态: ${item.useStatus.fixMojibakeOrDash()}")
            appendLine("制造厂: ${item.manufacturer.fixMojibakeOrDash()}")
            appendLine("设备型号: ${item.model.fixMojibakeOrDash()}")
            appendLine("采购时间: ${item.purchaseDate.fixMojibakeOrDash()}")
            appendLine("采购价格: ${item.purchasePrice?.toString() ?: "-"}")
            appendLine("使用年限: ${item.serviceLife?.let { "$it 年" } ?: "-"}")
            appendLine("分度值: ${item.graduationValue.fixMojibakeOrDash()}")
            appendLine("测试范围: ${item.testRange.fixMojibakeOrDash()}")
            appendLine("允许误差: ${item.allowableError.fixMojibakeOrDash()}")
            appendLine("检定周期: ${formatCycleDisplay(item.cycle)}")
            appendLine("上次校准: ${item.calDate.fixMojibakeOrDash()}")
            appendLine("下次校准: ${item.nextDate.fixMojibakeOrDash()}")
            appendLine("有效状态: ${item.validity.fixMojibakeOrDash()}")
            appendLine("校准结果: ${item.calibrationResult.fixMojibakeOrDash()}")
            append("备注: ${item.remark.fixMojibakeOrDash()}")
        }
    }

    private fun formatCycleDisplay(cycle: Int?): String {
        return when (cycle) {
            6 -> "半年"
            12 -> "一年"
            null -> "-"
            else -> "${cycle}个月"
        }
    }

    private fun formatCycleInputValue(cycle: Int?): String {
        return when (cycle) {
            6 -> "半年"
            12 -> "一年"
            null -> ""
            else -> cycle.toString()
        }
    }

    private fun parseCycleInput(value: String): Int? {
        return when (value.fixMojibake().trim()) {
            "" -> null
            "半年" -> 6
            "一年" -> 12
            else -> null
        }
    }

    private fun createFormContainer(): Pair<ScrollView, LinearLayout> {
        val padding = dp(16)
        val scroll = ScrollView(requireContext())
        val container = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding / 2, padding, padding / 2)
        }
        scroll.setBackgroundResource(R.drawable.bg_card)
        scroll.setPadding(dp(2), dp(2), dp(2), dp(2))
        scroll.addView(container)
        return scroll to container
    }

    private fun addFormInput(
        container: LinearLayout,
        label: String,
        value: String?,
        inputType: Int = InputType.TYPE_CLASS_TEXT
    ): EditText {
        val title = TextView(requireContext()).apply {
            text = label
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setTextColor(requireContext().getColor(R.color.textSecondary))
        }
        val input = EditText(requireContext()).apply {
            this.inputType = inputType
            setText(value.fixMojibake())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setTextColor(requireContext().getColor(R.color.textPrimary))
            setBackgroundResource(R.drawable.bg_input)
            setPadding(dp(10), dp(8), dp(10), dp(8))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(4)
                bottomMargin = dp(10)
            }
        }
        container.addView(title)
        container.addView(input)
        return input
    }

    private fun addFormDropdownInput(
        container: LinearLayout,
        label: String,
        options: List<String>,
        value: String?,
        editable: Boolean = false
    ): AutoCompleteTextView {
        val title = TextView(requireContext()).apply {
            text = label
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setTextColor(requireContext().getColor(R.color.textSecondary))
        }
        val input = AutoCompleteTextView(requireContext()).apply {
            setText(value.fixMojibake(), false)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setTextColor(requireContext().getColor(R.color.textPrimary))
            setBackgroundResource(R.drawable.bg_input)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(4)
                bottomMargin = dp(10)
            }
        }
        val resolvedOptions = mergeEditableOptions(options, value)
        setDropdownOptions(input, resolvedOptions)
        configureDropDownInput(input, editable = editable)
        container.addView(title)
        container.addView(input)
        return input
    }

    private fun configureDatePickerOnlyInput(input: EditText) {
        input.inputType = InputType.TYPE_NULL
        input.isFocusable = false
        input.isFocusableInTouchMode = false
        input.setOnClickListener {
            showDatePicker(input.textValue()) { value ->
                input.setText(value)
            }
        }
        input.setOnLongClickListener {
            input.setText("")
            true
        }
    }

    private fun mergeEditableOptions(options: List<String>, currentValue: String?): List<String> {
        return (options + listOf(currentValue.fixMojibake()))
            .map { it.fixMojibake().trim() }
            .filter { it.isNotBlank() }
            .distinct()
    }

    private fun buildDeptEditOptions(currentValue: String?): List<String> {
        val currentItems = viewModel.uiState.value.items
            .mapNotNull { it.dept.fixMojibake().takeIf(String::isNotBlank) }
        return mergeEditableOptions(deptOptions + currentItems, currentValue)
    }

    private fun buildUseStatusEditOptions(currentValue: String?): List<String> {
        val defaults = listOf("正常", "故障", "维修", "报废", "丢失", "停用")
        val currentItems = viewModel.uiState.value.items
            .mapNotNull { it.useStatus.fixMojibake().takeIf(String::isNotBlank) }
        val source = if (useStatusOptions.isNotEmpty()) useStatusOptions else defaults
        return mergeEditableOptions(source + currentItems, currentValue)
    }

    private fun buildCalibrationResultOptions(currentValue: String?): List<String> {
        val defaults = listOf("合格", "不合格")
        val currentItems = viewModel.uiState.value.items
            .mapNotNull { it.calibrationResult.fixMojibake().takeIf(String::isNotBlank) }
        return mergeEditableOptions(defaults + currentItems, currentValue)
    }

    private fun buildAbcClassOptions(currentValue: String?): List<String> {
        val defaultOptions = listOf("A类", "B类", "C类")
        val currentItems = viewModel.uiState.value.items.mapNotNull { it.abcClass.fixMojibake().takeIf(String::isNotBlank) }
        return mergeEditableOptions(defaultOptions + currentItems, currentValue)
    }

    private fun todayDateString(): String {
        val calendar = Calendar.getInstance()
        return formatDate(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH)
        )
    }

    private fun EditText.textValue(): String {
        return text?.toString()?.trim().orEmpty()
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private fun toast(message: String) {
        val ctx = context ?: return
        Toast.makeText(ctx, message.fixMojibake(), Toast.LENGTH_SHORT).show()
    }

    override fun onDestroyView() {
        searchJob?.cancel()
        _binding = null
        super.onDestroyView()
    }

    companion object {
        private const val ARG_MODE = "arg_mode"
        private const val CALIBRATION_FIXED_USE_STATUS = "正常"

        fun newInstance(mode: DeviceMode): DeviceListFragment {
            return DeviceListFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_MODE, mode.name)
                }
            }
        }
    }
}
