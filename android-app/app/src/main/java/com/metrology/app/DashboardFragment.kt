package com.metrology.app

import android.app.AlertDialog
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.metrology.app.databinding.FragmentDashboardBinding
import com.metrology.app.databinding.ItemDashboardDeptStatBinding
import kotlinx.coroutines.launch
import java.util.Locale

class DashboardFragment : Fragment() {
    private var _binding: FragmentDashboardBinding? = null
    private val binding get() = _binding!!

    private val viewModel: DashboardViewModel by lazy {
        ViewModelProvider(
            this,
            AppViewModelFactory { DashboardViewModel(AppGraph.repository) }
        )[DashboardViewModel::class.java]
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentDashboardBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.buttonRefreshDashboard.setOnClickListener { viewModel.load() }
        observeState()
        if (savedInstanceState == null) {
            viewModel.load()
        }
    }

    private fun observeState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    val b = _binding ?: return@collect
                    if (state.loading) {
                        b.txtDashboardHint.text = getString(R.string.label_loading)
                        return@collect
                    }
                    if (!state.error.isNullOrBlank()) {
                        b.txtDashboardHint.text = state.error.fixMojibake()
                        return@collect
                    }

                    val summary = state.summary ?: DashboardSummaryUi()
                    b.txtDashboardHint.text = "\u6570\u636e\u66f4\u65b0\u65f6\u95f4\uff1a\u521a\u521a"
                    b.txtTotal.text = summary.total.toString()
                    b.txtDue.text = summary.dueThisMonth.toString()
                    b.txtValid.text = summary.valid.toString()
                    b.txtRisk.text = (summary.warning + summary.expired).toString()
                    b.trendChart.setTrendData(summary.trend)
                    b.validityChart.setDistribution(summary.valid, summary.warning, summary.expired)
                    bindValidityDistribution(b, summary)
                    renderDepartmentStats(b.deptStatsContainer, summary.deptStats)
                }
            }
        }
    }

    private fun bindValidityDistribution(binding: FragmentDashboardBinding, summary: DashboardSummaryUi) {
        val total = summary.total.coerceAtLeast(0L)
        val validRatio = ratioText(summary.valid, total)
        val warningRatio = ratioText(summary.warning, total)
        val expiredRatio = ratioText(summary.expired, total)

        binding.txtDistValid.text = "有效 ${summary.valid} · $validRatio"
        binding.txtDistWarning.text = "即将过期 ${summary.warning} · $warningRatio"
        binding.txtDistExpired.text = "失效 ${summary.expired} · $expiredRatio"

        binding.rowDistValid.setOnClickListener {
            showDistributionDetail("有效", summary.valid, total)
        }
        binding.rowDistWarning.setOnClickListener {
            showDistributionDetail("即将过期", summary.warning, total)
        }
        binding.rowDistExpired.setOnClickListener {
            showDistributionDetail("失效", summary.expired, total)
        }

        binding.validityChart.setOnSegmentClickListener { segment ->
            when (segment) {
                ValidityDonutChartView.Segment.VALID -> {
                    showDistributionDetail("有效", summary.valid, total)
                }

                ValidityDonutChartView.Segment.WARNING -> {
                    showDistributionDetail("即将过期", summary.warning, total)
                }

                ValidityDonutChartView.Segment.EXPIRED -> {
                    showDistributionDetail("失效", summary.expired, total)
                }
            }
        }
    }

    private fun ratioText(value: Long, total: Long): String {
        if (total <= 0L) return "0%"
        val ratio = value.coerceAtLeast(0L).toDouble() * 100.0 / total.toDouble()
        return String.format(Locale.CHINA, "%.1f%%", ratio)
    }

    private fun showDistributionDetail(label: String, value: Long, total: Long) {
        val ratio = ratioText(value, total)
        val message = "数量：$value 台\n占比：$ratio\n总数：$total 台"
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("设备有效性分布 - $label")
            .setMessage(message)
            .setPositiveButton("关闭", null)
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun renderDepartmentStats(container: LinearLayout, items: List<DepartmentStatUi>) {
        val ctx = context ?: return
        container.removeAllViews()
        if (items.isEmpty()) {
            val empty = TextView(ctx).apply {
                text = "\u6682\u65e0\u90e8\u95e8\u7edf\u8ba1\u6570\u636e"
                setTextColor(ctx.getColor(R.color.textMuted))
                textSize = 13f
            }
            container.addView(empty)
            return
        }

        items.forEach { item ->
            val rowBinding = ItemDashboardDeptStatBinding.inflate(LayoutInflater.from(ctx), container, false)
            val name = item.name.fixMojibake().ifBlank { "\u672a\u5206\u914d" }
            val validRate = item.validRate.coerceIn(0, 100)

            rowBinding.txtDeptName.text = name
            rowBinding.txtDeptTotal.text = "\u603b\u6570 ${item.total}"
            rowBinding.txtDeptValid.text = "\u6709\u6548 ${item.valid}"
            rowBinding.txtDeptWarning.text = "\u9884\u8b66 ${item.warning}"
            rowBinding.txtDeptExpired.text = "\u5931\u6548 ${item.expired}"
            rowBinding.progressDeptValid.max = 100
            rowBinding.progressDeptValid.progress = validRate
            rowBinding.txtDeptValidRate.text = "\u6709\u6548\u5360\u6bd4 ${validRate}%"

            container.addView(rowBinding.root)
        }
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }
}
