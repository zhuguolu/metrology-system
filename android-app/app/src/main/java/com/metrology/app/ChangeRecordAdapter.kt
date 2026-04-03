package com.metrology.app

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.metrology.app.databinding.ItemChangeRecordBinding

class ChangeRecordAdapter(
    private val onView: (ChangeRecordItemDto) -> Unit
) : RecyclerView.Adapter<ChangeRecordAdapter.ChangeRecordViewHolder>() {
    private val items = mutableListOf<ChangeRecordItemDto>()

    fun submitList(data: List<ChangeRecordItemDto>) {
        items.clear()
        items.addAll(data)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ChangeRecordViewHolder {
        val binding = ItemChangeRecordBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ChangeRecordViewHolder(binding, onView)
    }

    override fun onBindViewHolder(holder: ChangeRecordViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    class ChangeRecordViewHolder(
        private val binding: ItemChangeRecordBinding,
        private val onView: (ChangeRecordItemDto) -> Unit
    ) : RecyclerView.ViewHolder(binding.root) {
        fun bind(item: ChangeRecordItemDto) {
            binding.txtChangeDevice.text = item.deviceName.fixMojibake().ifBlank { "未命名设备" }
            val typeLabel = when (item.type) {
                "CREATE" -> "新增"
                "UPDATE" -> "修改"
                "DELETE" -> "删除"
                else -> item.type.fixMojibakeOrDash()
            }
            binding.chipChangeType.text = typeLabel
            when (item.type) {
                "CREATE" -> {
                    binding.chipChangeType.setBackgroundResource(R.drawable.bg_chip_valid)
                    binding.chipChangeType.setTextColor(binding.root.context.getColor(R.color.statusValid))
                }
                "UPDATE" -> {
                    binding.chipChangeType.setBackgroundResource(R.drawable.bg_chip_warning)
                    binding.chipChangeType.setTextColor(binding.root.context.getColor(R.color.statusWarning))
                }
                "DELETE" -> {
                    binding.chipChangeType.setBackgroundResource(R.drawable.bg_chip_expired)
                    binding.chipChangeType.setTextColor(binding.root.context.getColor(R.color.statusExpired))
                }
                else -> {
                    binding.chipChangeType.setBackgroundResource(R.drawable.bg_chip_neutral)
                    binding.chipChangeType.setTextColor(binding.root.context.getColor(R.color.textSecondary))
                }
            }
            binding.txtChangeMeta1.text = "编号: ${item.metricNo.fixMojibakeOrDash()}   状态: ${item.status.fixMojibakeOrDash()}"
            binding.txtChangeMeta2.text =
                "提交人: ${item.submittedBy.fixMojibakeOrDash()}   时间: ${item.submittedAt.formatToMinuteDateTime()}"
            binding.buttonViewChange.setOnClickListener { onView(item) }
            binding.root.setOnClickListener { onView(item) }
        }
    }
}
