package com.metrology.app

import android.app.AlertDialog
import android.app.DatePickerDialog
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import androidx.core.view.isVisible
import androidx.core.widget.doOnTextChanged
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.metrology.app.databinding.FragmentChangeRecordBinding
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.Locale

class ChangeRecordFragment : Fragment() {
    private var _binding: FragmentChangeRecordBinding? = null
    private val binding get() = _binding!!

    private val adapter = ChangeRecordAdapter(onView = { openDetail(it) })
    private var searchJob: Job? = null

    private var page = 1
    private val size = 20
    private var total = 0L

    private var keyword: String = ""
    private var type: String = ""
    private var status: String = ""
    private var submittedBy: String = ""
    private var dateFrom: String = ""
    private var dateTo: String = ""

    private val isAdmin by lazy { AppGraph.repository.isAdmin() }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentChangeRecordBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.recyclerChange.layoutManager = LinearLayoutManager(requireContext())
        binding.recyclerChange.adapter = adapter

        binding.inputSubmittedBy.isVisible = isAdmin

        binding.buttonChangeType.setOnClickListener { openTypeFilterDialog() }
        binding.buttonChangeStatus.setOnClickListener { openStatusFilterDialog() }
        setupDateInputs()

        binding.buttonSearchChange.setOnClickListener {
            page = 1
            syncFilterInputs()
            load()
        }
        binding.buttonResetChange.setOnClickListener {
            resetFilter()
            load()
        }

        binding.buttonPrevChange.setOnClickListener {
            if (page <= 1) return@setOnClickListener
            page -= 1
            load()
        }
        binding.buttonNextChange.setOnClickListener {
            val totalPages = ((total + size - 1) / size).toInt().coerceAtLeast(1)
            if (page >= totalPages) return@setOnClickListener
            page += 1
            load()
        }

        binding.inputChangeKeyword.doOnTextChanged { text, _, _, _ ->
            searchJob?.cancel()
            searchJob = viewLifecycleOwner.lifecycleScope.launch {
                delay(350L)
                keyword = text?.toString().orEmpty()
                page = 1
                load()
            }
        }

        updateFilterButtons()
        load()
    }

    private fun syncFilterInputs() {
        keyword = binding.inputChangeKeyword.text?.toString().orEmpty().trim()
        dateFrom = binding.inputDateFrom.text?.toString().orEmpty().trim()
        dateTo = binding.inputDateTo.text?.toString().orEmpty().trim()
        submittedBy = if (isAdmin) binding.inputSubmittedBy.text?.toString().orEmpty().trim() else ""
    }

    private fun load() {
        viewLifecycleOwner.lifecycleScope.launch {
            binding.txtChangeHint.showLoadingState()
            syncFilterInputs()
            runCatching {
                AppGraph.repository.changeRecords(
                    page = page,
                    size = size,
                    keyword = keyword,
                    type = type,
                    status = status,
                    submittedBy = submittedBy,
                    dateFrom = dateFrom,
                    dateTo = dateTo
                )
            }.onSuccess { result ->
                val list = result.items.orEmpty()
                total = result.total ?: 0L
                val totalPages = ((total + size - 1) / size).toInt().coerceAtLeast(1)
                adapter.submitList(list)

                val stats = result.stats
                binding.chipChangeTotal.text = "总数 ${stats?.total ?: total}"
                binding.chipChangePending.text = "待审批 ${stats?.pending ?: 0}"
                binding.chipChangeApproved.text = "已通过 ${stats?.approved ?: 0}"
                binding.chipChangeRejected.text = "已驳回 ${stats?.rejected ?: 0}"

                binding.txtChangeHint.showReadyState("共 $total 条记录")
                binding.txtChangePage.text = "$page / $totalPages 页"
                binding.buttonPrevChange.isEnabled = page > 1
                binding.buttonNextChange.isEnabled = page < totalPages
            }.onFailure {
                binding.txtChangeHint.showErrorState(it.toUserMessage("加载变更记录失败"))
                adapter.submitList(emptyList())
            }
        }
    }

    private fun resetFilter() {
        keyword = ""
        type = ""
        status = ""
        dateFrom = ""
        dateTo = ""
        submittedBy = ""
        page = 1

        binding.inputChangeKeyword.setText("")
        binding.inputDateFrom.setText("")
        binding.inputDateTo.setText("")
        binding.inputSubmittedBy.setText("")
        updateFilterButtons()
    }

    private fun updateFilterButtons() {
        binding.buttonChangeType.text = "操作类型: ${if (type.isBlank()) "全部" else typeLabel(type)}"
        binding.buttonChangeStatus.text = "处理状态: ${if (status.isBlank()) "全部" else statusLabel(status)}"
    }

    private fun openTypeFilterDialog() {
        val options = listOf("全部", "新增", "修改", "删除")
        val values = listOf("", "CREATE", "UPDATE", "DELETE")
        val selected = values.indexOf(type).coerceAtLeast(0)
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("选择操作类型")
            .setSingleChoiceItems(options.toTypedArray(), selected) { dialog, which ->
                type = values[which]
                page = 1
                updateFilterButtons()
                load()
                dialog.dismiss()
            }
            .setNegativeButton(getString(R.string.action_cancel), null)
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun openStatusFilterDialog() {
        val options = listOf("全部", "待审批", "已通过", "已驳回")
        val values = listOf("", "PENDING", "APPROVED", "REJECTED")
        val selected = values.indexOf(status).coerceAtLeast(0)
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("选择处理状态")
            .setSingleChoiceItems(options.toTypedArray(), selected) { dialog, which ->
                status = values[which]
                page = 1
                updateFilterButtons()
                load()
                dialog.dismiss()
            }
            .setNegativeButton(getString(R.string.action_cancel), null)
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun setupDateInputs() {
        setupDateInput(binding.inputDateFrom)
        setupDateInput(binding.inputDateTo)
    }

    private fun setupDateInput(input: EditText) {
        input.setOnClickListener {
            showDatePicker(input.text?.toString().orEmpty()) { value ->
                input.setText(value)
            }
        }
        input.setOnLongClickListener {
            input.setText("")
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
                onChanged(formatDate(year, month + 1, dayOfMonth))
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

    private fun openDetail(row: ChangeRecordItemDto) {
        val id = row.id ?: return
        viewLifecycleOwner.lifecycleScope.launch {
            runCatching { AppGraph.repository.changeRecordDetail(id) }
                .onSuccess { detail -> showDetailDialog(detail) }
                .onFailure {
                    binding.txtChangeHint.showErrorState(it.toUserMessage("加载详情失败"))
                }
        }
    }

    private fun showDetailDialog(detail: AuditRecordDto) {
        showAuditDetailDialog(detail)
    }

    private fun typeLabel(typeValue: String?): String {
        return when (typeValue) {
            "CREATE" -> "新增"
            "UPDATE" -> "修改"
            "DELETE" -> "删除"
            else -> typeValue.fixMojibakeOrDash()
        }
    }

    private fun statusLabel(statusValue: String?): String {
        return when (statusValue) {
            "PENDING" -> "待审批"
            "APPROVED" -> "已通过"
            "REJECTED" -> "已驳回"
            else -> statusValue.fixMojibakeOrDash()
        }
    }

    override fun onDestroyView() {
        searchJob?.cancel()
        _binding = null
        super.onDestroyView()
    }
}
