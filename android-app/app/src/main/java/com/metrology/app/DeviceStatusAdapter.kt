package com.metrology.app

import android.widget.TextView
import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.metrology.app.databinding.ItemDeviceStatusBinding

class DeviceStatusAdapter(
    private val onEdit: (DeviceStatusDto) -> Unit,
    private val onDelete: (DeviceStatusDto) -> Unit
) : RecyclerView.Adapter<DeviceStatusAdapter.StatusViewHolder>() {
    private val items = mutableListOf<DeviceStatusDto>()

    fun submitList(data: List<DeviceStatusDto>) {
        items.clear()
        items.addAll(data)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): StatusViewHolder {
        val binding = ItemDeviceStatusBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return StatusViewHolder(binding, onEdit, onDelete)
    }

    override fun onBindViewHolder(holder: StatusViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    class StatusViewHolder(
        private val binding: ItemDeviceStatusBinding,
        private val onEdit: (DeviceStatusDto) -> Unit,
        private val onDelete: (DeviceStatusDto) -> Unit
    ) : RecyclerView.ViewHolder(binding.root) {
        fun bind(item: DeviceStatusDto) {
            val statusName = item.name.fixMojibakeOrDash()
            binding.txtStatusName.text = statusName
            applyUseStatusChipStyle(binding.txtStatusName, statusName)
            binding.txtStatusMeta.text = "ID: ${item.id ?: "-"}"
            binding.buttonEditStatus.setOnClickListener { onEdit(item) }
            binding.buttonDeleteStatus.setOnClickListener { onDelete(item) }
        }

        private fun applyUseStatusChipStyle(textView: TextView, rawValue: String) {
            val value = rawValue.fixMojibake()
            when {
                value.contains("正常") || value.contains("在用") || value.contains("使用中") -> {
                    applyChipStyle(textView, R.drawable.bg_chip_valid, R.color.statusValid)
                }
                value.contains("故障") || value.contains("维修") || value.contains("保养")
                    || value.contains("检修") || value.contains("停机") -> {
                    applyChipStyle(textView, R.drawable.bg_chip_warning, R.color.statusWarning)
                }
                value.contains("报废") || value.contains("停用") || value.contains("禁用")
                    || value.contains("丢失") -> {
                    applyChipStyle(textView, R.drawable.bg_chip_expired, R.color.statusExpired)
                }
                value.contains("借出") || value.contains("外借") || value.contains("闲置")
                    || value.contains("待用") -> {
                    applyChipStyle(textView, R.drawable.bg_chip_neutral, R.color.navActive)
                }
                else -> {
                    applyChipStyle(textView, R.drawable.bg_chip_neutral, R.color.textSecondary)
                }
            }
        }

        private fun applyChipStyle(textView: TextView, backgroundRes: Int, textColorRes: Int) {
            val context = textView.context
            textView.background = context.getDrawable(backgroundRes)
            textView.setTextColor(context.getColor(textColorRes))
            textView.setPadding(dp(10), dp(4), dp(10), dp(4))
        }

        private fun dp(value: Int): Int {
            return (value * binding.root.resources.displayMetrics.density).toInt()
        }
    }
}
