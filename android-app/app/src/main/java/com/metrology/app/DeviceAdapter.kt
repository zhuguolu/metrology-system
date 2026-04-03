package com.metrology.app

import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.text.style.TypefaceSpan
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.metrology.app.databinding.ItemDeviceBinding
import com.metrology.app.databinding.ItemDevicePagerBinding

class DeviceAdapter(
    private val mode: DeviceMode,
    private val onClick: ((DeviceDto) -> Unit)? = null,
    private val onQuickEdit: ((DeviceDto) -> Unit)? = null,
    private val onPageRequest: ((Int) -> Unit)? = null
) : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
    private val items = mutableListOf<DeviceDto>()
    private var pagerState = PagerState(page = 1, totalPages = 1, loading = false)

    fun submitList(list: List<DeviceDto>) {
        items.clear()
        items.addAll(list)
        notifyDataSetChanged()
    }

    fun submitPager(page: Int, totalPages: Int, loading: Boolean) {
        val safeTotal = totalPages.coerceAtLeast(1)
        val safePage = page.coerceIn(1, safeTotal)
        val next = PagerState(safePage, safeTotal, loading)
        if (pagerState == next) return
        pagerState = next
        if (itemCount > 0) {
            notifyItemChanged(itemCount - 1)
        }
    }

    override fun getItemCount(): Int = items.size + 1

    override fun getItemViewType(position: Int): Int {
        return if (position < items.size) VIEW_TYPE_DEVICE else VIEW_TYPE_PAGER
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        return when (viewType) {
            VIEW_TYPE_PAGER -> {
                val binding = ItemDevicePagerBinding.inflate(
                    LayoutInflater.from(parent.context),
                    parent,
                    false
                )
                PagerViewHolder(binding, onPageRequest)
            }

            else -> {
                val binding = ItemDeviceBinding.inflate(
                    LayoutInflater.from(parent.context),
                    parent,
                    false
                )
                DeviceViewHolder(binding, mode, onClick, onQuickEdit)
            }
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        when (holder) {
            is DeviceViewHolder -> holder.bind(items[position])
            is PagerViewHolder -> holder.bind(pagerState)
        }
    }

    class DeviceViewHolder(
        private val binding: ItemDeviceBinding,
        private val mode: DeviceMode,
        private val onClick: ((DeviceDto) -> Unit)?,
        private val onQuickEdit: ((DeviceDto) -> Unit)?
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(item: DeviceDto) {
            binding.txtName.text = item.name.fixMojibake().ifBlank { "未命名设备" }
            val metricNo = item.metricNo.fixMojibakeOrDash()
            val assetNo = item.assetNo.fixMojibakeOrDash()
            val responsible = item.responsiblePerson.fixMojibakeOrDash()
            val dept = item.dept.fixMojibakeOrDash()
            val nextDate = item.nextDate.fixMojibakeOrDash()
            val useStatus = item.useStatus.fixMojibakeOrDash()

            binding.txtLine1.setText(
                buildPairLine(
                    firstLabel = "编号",
                    firstValue = metricNo,
                    secondLabel = "资产",
                    secondValue = assetNo
                ),
                TextView.BufferType.SPANNABLE
            )
            binding.txtLine2.setText(
                buildPairLine(
                    firstLabel = "责任人",
                    firstValue = responsible,
                    secondLabel = "部门",
                    secondValue = dept
                ),
                TextView.BufferType.SPANNABLE
            )

            val validity = item.validity.fixMojibake()
            binding.chipValidity.text = if (validity.isBlank()) "-" else validity
            binding.chipValidity.setTypeface(Typeface.DEFAULT_BOLD, Typeface.BOLD)
            val validityColor = when (validity) {
                "有效" -> {
                    binding.chipValidity.setBackgroundResource(R.drawable.bg_chip_valid_selected)
                    binding.chipValidity.setTextColor(binding.root.context.getColor(R.color.white))
                    binding.root.context.getColor(R.color.statusValid)
                }

                "即将过期" -> {
                    binding.chipValidity.setBackgroundResource(R.drawable.bg_chip_warning_selected)
                    binding.chipValidity.setTextColor(binding.root.context.getColor(R.color.white))
                    binding.root.context.getColor(R.color.statusWarning)
                }

                "失效" -> {
                    binding.chipValidity.setBackgroundResource(R.drawable.bg_chip_expired_selected)
                    binding.chipValidity.setTextColor(binding.root.context.getColor(R.color.white))
                    binding.root.context.getColor(R.color.statusExpired)
                }

                else -> {
                    binding.chipValidity.setBackgroundResource(R.drawable.bg_chip_device_other)
                    binding.chipValidity.setTextColor(binding.root.context.getColor(R.color.white))
                    binding.root.context.getColor(R.color.textSecondary)
                }
            }
            val useStatusColor = colorForUseStatus(useStatus)
            binding.txtLine3.setText(
                buildLine3Text(
                    nextDate = nextDate,
                    useStatus = useStatus,
                    nextDateColor = validityColor,
                    useStatusColor = useStatusColor
                ),
                TextView.BufferType.SPANNABLE
            )

            val showQuickEdit = mode == DeviceMode.LEDGER ||
                mode == DeviceMode.CALIBRATION ||
                mode == DeviceMode.TODO
            binding.buttonQuickEdit.visibility = if (showQuickEdit) View.VISIBLE else View.GONE
            binding.buttonQuickEdit.text = when (mode) {
                DeviceMode.LEDGER -> "快改"
                DeviceMode.CALIBRATION, DeviceMode.TODO -> "快改校准"
            }
            binding.buttonQuickEdit.setOnClickListener {
                onQuickEdit?.invoke(item)
            }

            binding.root.setOnClickListener {
                onClick?.invoke(item)
            }
        }

        private fun buildLine3Text(
            nextDate: String,
            useStatus: String,
            nextDateColor: Int,
            useStatusColor: Int
        ): CharSequence {
            val builder = SpannableStringBuilder()
            appendBoldLabel(builder, "下次校准: ")
            val nextDateStart = builder.length
            builder.append(nextDate)
            builder.setSpan(
                ForegroundColorSpan(nextDateColor),
                nextDateStart,
                builder.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )

            builder.append(" / ")
            appendBoldLabel(builder, "状态: ")
            val statusStart = builder.length
            builder.append(useStatus)
            builder.setSpan(
                ForegroundColorSpan(useStatusColor),
                statusStart,
                builder.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
            return builder
        }

        private fun buildPairLine(
            firstLabel: String,
            firstValue: String,
            secondLabel: String,
            secondValue: String
        ): CharSequence {
            val builder = SpannableStringBuilder()
            appendBoldLabel(builder, "$firstLabel: ")
            builder.append(firstValue)
            builder.append(" / ")
            appendBoldLabel(builder, "$secondLabel: ")
            builder.append(secondValue)
            return builder
        }

        private fun appendBoldLabel(builder: SpannableStringBuilder, labelText: String) {
            val start = builder.length
            builder.append(labelText)
            val labelColor = binding.root.context.getColor(R.color.textPrimary)
            builder.setSpan(
                StyleSpan(Typeface.BOLD),
                start,
                builder.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
            builder.setSpan(
                TypefaceSpan("sans-serif-medium"),
                start,
                builder.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
            builder.setSpan(
                ForegroundColorSpan(labelColor),
                start,
                builder.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        private fun colorForUseStatus(useStatus: String): Int {
            val context = binding.root.context
            val text = useStatus.fixMojibake()
            return when {
                text.contains("在用") ||
                    text.contains("使用中") ||
                    text.contains("正常") ->
                    context.getColor(R.color.statusValid)

                text.contains("维修") ||
                    text.contains("保养") ||
                    text.contains("检修") ||
                    text.contains("停机") ->
                    context.getColor(R.color.statusWarning)

                text.contains("停用") ||
                    text.contains("报废") ||
                    text.contains("禁用") ||
                    text.contains("丢失") ->
                    context.getColor(R.color.statusExpired)

                text.contains("借出") ||
                    text.contains("外借") ||
                    text.contains("闲置") ||
                    text.contains("待用") ->
                    context.getColor(R.color.navActive)

                else -> context.getColor(R.color.textSecondary)
            }
        }
    }

    private class PagerViewHolder(
        private val binding: ItemDevicePagerBinding,
        private val onPageRequest: ((Int) -> Unit)?
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(state: PagerState) {
            val safeTotal = state.totalPages.coerceAtLeast(1)
            val safeCurrent = state.page.coerceIn(1, safeTotal)

            binding.buttonPrev.isEnabled = safeCurrent > 1 && !state.loading
            binding.buttonPrev.alpha = if (binding.buttonPrev.isEnabled) 1f else 0.5f
            binding.buttonNext.isEnabled = safeCurrent < safeTotal && !state.loading
            binding.buttonNext.alpha = if (binding.buttonNext.isEnabled) 1f else 0.5f

            binding.buttonPrev.setOnClickListener {
                if (safeCurrent > 1 && !state.loading) {
                    onPageRequest?.invoke(safeCurrent - 1)
                }
            }
            binding.buttonNext.setOnClickListener {
                if (safeCurrent < safeTotal && !state.loading) {
                    onPageRequest?.invoke(safeCurrent + 1)
                }
            }

            renderPagerItems(safeCurrent, safeTotal, state.loading)
        }

        private fun renderPagerItems(currentPage: Int, totalPages: Int, loading: Boolean) {
            val container = binding.layoutPageItems
            container.removeAllViews()

            val items = buildPagerItems(currentPage, totalPages)
            items.forEachIndexed { index, item ->
                val textView = TextView(binding.root.context).apply {
                    gravity = Gravity.CENTER
                    minWidth = dp(28)
                    minHeight = dp(28)
                    setPadding(dp(6), 0, dp(6), 0)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                }

                when (item) {
                    is PagerItem.Page -> {
                        textView.tag = "page_${item.number}"
                        textView.text = item.number.toString()
                        val active = item.number == currentPage
                        textView.setBackgroundResource(
                            if (active) R.drawable.bg_pager_item_active else R.drawable.bg_pager_item
                        )
                        textView.setTextColor(
                            binding.root.context.getColor(
                                if (active) R.color.white else R.color.textPrimary
                            )
                        )
                        textView.alpha = if (active) 1f else 0.96f
                        textView.isEnabled = !active && !loading
                        if (!active) {
                            textView.setOnClickListener { onPageRequest?.invoke(item.number) }
                        }
                    }

                    PagerItem.Ellipsis -> {
                        textView.text = "..."
                        textView.setBackgroundResource(R.drawable.bg_pager_item)
                        textView.setTextColor(binding.root.context.getColor(R.color.textSecondary))
                        textView.alpha = 0.88f
                        textView.isEnabled = false
                    }
                }

                textView.layoutParams = ViewGroup.MarginLayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply {
                    if (index > 0) marginStart = dp(3)
                }
                container.addView(textView)
            }

            binding.scrollPageItems.post {
                val activeView = container.findViewWithTag<View>("page_$currentPage") ?: return@post
                val targetX = ((activeView.left + activeView.right - binding.scrollPageItems.width) / 2)
                    .coerceAtLeast(0)
                binding.scrollPageItems.smoothScrollTo(targetX, 0)
            }
        }

        private fun buildPagerItems(currentPage: Int, totalPages: Int): List<PagerItem> {
            if (totalPages <= 9) {
                return (1..totalPages).map { PagerItem.Page(it) }
            }

            val items = mutableListOf<PagerItem>()
            items += PagerItem.Page(1)

            var start = (currentPage - 3).coerceAtLeast(2)
            var end = (currentPage + 2).coerceAtMost(totalPages - 1)

            if (currentPage <= 5) {
                start = 2
                end = 7.coerceAtMost(totalPages - 1)
            }
            if (currentPage >= totalPages - 4) {
                start = (totalPages - 6).coerceAtLeast(2)
                end = totalPages - 1
            }

            if (start > 2) items += PagerItem.Ellipsis
            for (page in start..end) {
                items += PagerItem.Page(page)
            }
            if (end < totalPages - 1) items += PagerItem.Ellipsis
            items += PagerItem.Page(totalPages)
            return items
        }

        private fun dp(value: Int): Int {
            return TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                value.toFloat(),
                binding.root.resources.displayMetrics
            ).toInt()
        }
    }

    private sealed class PagerItem {
        data class Page(val number: Int) : PagerItem()
        object Ellipsis : PagerItem()
    }

    private data class PagerState(
        val page: Int,
        val totalPages: Int,
        val loading: Boolean
    )

    companion object {
        private const val VIEW_TYPE_DEVICE = 0
        private const val VIEW_TYPE_PAGER = 1
    }
}



