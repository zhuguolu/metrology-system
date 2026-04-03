package com.metrology.app

import android.app.AlertDialog
import android.os.Bundle
import android.text.InputType
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.android.material.tabs.TabLayout
import com.metrology.app.databinding.FragmentAuditBinding
import kotlinx.coroutines.launch

class AuditFragment : Fragment() {
    private var _binding: FragmentAuditBinding? = null
    private val binding get() = _binding!!

    private var currentMode: AuditListMode = AuditListMode.MY
    private var currentItems: List<AuditRecordDto> = emptyList()
    private var loading: Boolean = false
    private var error: String? = null

    private val isAdmin by lazy { AppGraph.repository.isAdmin() }

    private val adapter = AuditAdapter(
        onView = { record -> openDetail(record) },
        onApprove = { record ->
            val id = record.id ?: return@AuditAdapter
            approve(id)
        },
        onReject = { record ->
            val id = record.id ?: return@AuditAdapter
            showRejectDialog(id)
        },
        modeProvider = { currentMode }
    )

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentAuditBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.auditRecycler.layoutManager = LinearLayoutManager(requireContext())
        binding.auditRecycler.adapter = adapter
        binding.buttonRefreshAudit.setOnClickListener { loadCurrentMode() }

        setupTabs()
        if (savedInstanceState == null) {
            loadCurrentMode()
        }
    }

    private fun setupTabs() {
        val tabs = binding.auditTabLayout
        tabs.removeAllTabs()
        tabs.clearOnTabSelectedListeners()

        if (isAdmin) {
            tabs.addTab(tabs.newTab().setText("待审批").setTag(AuditListMode.PENDING))
        }
        tabs.addTab(tabs.newTab().setText("我的申请").setTag(AuditListMode.MY))
        if (isAdmin) {
            tabs.addTab(tabs.newTab().setText("审批历史").setTag(AuditListMode.HISTORY))
        }

        currentMode = if (isAdmin) AuditListMode.PENDING else AuditListMode.MY
        selectTabByMode(currentMode)

        tabs.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab?) {
                currentMode = (tab?.tag as? AuditListMode) ?: AuditListMode.MY
                loadCurrentMode()
            }
            override fun onTabUnselected(tab: TabLayout.Tab?) = Unit
            override fun onTabReselected(tab: TabLayout.Tab?) {
                loadCurrentMode()
            }
        })
    }

    private fun selectTabByMode(mode: AuditListMode) {
        val tabs = binding.auditTabLayout
        for (i in 0 until tabs.tabCount) {
            val tab = tabs.getTabAt(i)
            if ((tab?.tag as? AuditListMode) == mode) {
                tab.select()
                return
            }
        }
    }

    private fun loadCurrentMode() {
        viewLifecycleOwner.lifecycleScope.launch {
            loading = true
            error = null
            renderState()
            when (currentMode) {
                AuditListMode.PENDING -> {
                    runCatching { AppGraph.repository.pendingAudit() }
                        .onSuccess {
                            currentItems = it
                            error = null
                        }
                        .onFailure {
                            currentItems = emptyList()
                            error = it.toUserMessage("加载待审批记录失败")
                        }
                }
                AuditListMode.MY -> {
                    runCatching { AppGraph.repository.myAudit() }
                        .onSuccess {
                            currentItems = it
                            error = null
                        }
                        .onFailure {
                            currentItems = emptyList()
                            error = it.toUserMessage("加载我的申请失败")
                        }
                }
                AuditListMode.HISTORY -> {
                    runCatching { AppGraph.repository.allAudit(page = 1, size = 200) }
                        .onSuccess { pageResult ->
                            currentItems = pageResult.content.orEmpty()
                                .filter { !it.status.equals("PENDING", ignoreCase = true) }
                            error = null
                        }
                        .onFailure {
                            currentItems = emptyList()
                            error = it.toUserMessage("加载审批历史失败")
                        }
                }
            }
            loading = false
            renderState()
        }
    }

    private fun renderState() {
        binding.chipPending.text = when (currentMode) {
            AuditListMode.PENDING -> "待审批 ${currentItems.size}"
            AuditListMode.MY -> "我的申请 ${currentItems.size}"
            AuditListMode.HISTORY -> "历史记录 ${currentItems.size}"
        }
        when {
            loading -> binding.txtAuditStatus.showLoadingState()
            !error.isNullOrBlank() -> binding.txtAuditStatus.showErrorState(error.orEmpty())
            currentItems.isEmpty() -> binding.txtAuditStatus.showEmptyState(getString(R.string.label_empty))
            else -> binding.txtAuditStatus.showReadyState(getString(R.string.label_total, currentItems.size))
        }
        adapter.submitList(currentItems)
    }

    private fun approve(id: Long) {
        viewLifecycleOwner.lifecycleScope.launch {
            runCatching { AppGraph.repository.approveAudit(id) }
                .onSuccess { loadCurrentMode() }
                .onFailure {
                    error = it.toUserMessage("审批失败")
                    renderState()
                }
        }
    }

    private fun showRejectDialog(id: Long) {
        val input = EditText(requireContext()).apply {
            inputType = InputType.TYPE_CLASS_TEXT
            hint = getString(R.string.hint_reject_reason)
            setPadding(36, 24, 36, 24)
        }
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle(getString(R.string.audit_reject_title))
            .setView(input)
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton(getString(R.string.action_reject)) { _, _ ->
                reject(id, input.text?.toString())
            }
            .create()
        dialog.setOnShowListener {
            dialog.applyMetrologyDialogStyle(positiveStyle = DialogPositiveStyle.DANGER)
        }
        dialog.show()
    }

    private fun reject(id: Long, reason: String?) {
        viewLifecycleOwner.lifecycleScope.launch {
            runCatching { AppGraph.repository.rejectAudit(id, reason) }
                .onSuccess { loadCurrentMode() }
                .onFailure {
                    error = it.toUserMessage("驳回失败")
                    renderState()
                }
        }
    }

    private fun openDetail(record: AuditRecordDto) {
        val id = record.id ?: return
        viewLifecycleOwner.lifecycleScope.launch {
            runCatching { AppGraph.repository.auditDetail(id) }
                .onSuccess { detail ->
                    showDetailDialog(detail)
                }
                .onFailure {
                    error = it.toUserMessage("加载详情失败")
                    renderState()
                }
        }
    }

    private fun showDetailDialog(record: AuditRecordDto) {
        showAuditDetailDialog(record)
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }
}
