package com.metrology.app

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.metrology.app.databinding.ItemAuditBinding

class AuditAdapter(
    private val onView: (AuditRecordDto) -> Unit,
    private val onApprove: (AuditRecordDto) -> Unit,
    private val onReject: (AuditRecordDto) -> Unit,
    private val modeProvider: () -> AuditListMode
) : RecyclerView.Adapter<AuditAdapter.AuditViewHolder>() {
    private val items = mutableListOf<AuditRecordDto>()

    fun submitList(list: List<AuditRecordDto>) {
        items.clear()
        items.addAll(list)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): AuditViewHolder {
        val binding = ItemAuditBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return AuditViewHolder(binding, onView, onApprove, onReject, modeProvider)
    }

    override fun onBindViewHolder(holder: AuditViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    class AuditViewHolder(
        private val binding: ItemAuditBinding,
        private val onView: (AuditRecordDto) -> Unit,
        private val onApprove: (AuditRecordDto) -> Unit,
        private val onReject: (AuditRecordDto) -> Unit,
        private val modeProvider: () -> AuditListMode
    ) : RecyclerView.ViewHolder(binding.root) {
        fun bind(item: AuditRecordDto) {
            val entity = item.entityType.fixMojibake().ifBlank { "未知对象" }
            val action = item.type.fixMojibake().ifBlank { "操作" }
            binding.txtAuditTitle.text = "$entity · $action"
            binding.txtAuditMeta.text =
                "提交人: ${item.submittedBy.fixMojibake()}   提交时间: ${item.submittedAt.formatToMinuteDateTime()}"
            val status = item.status.fixMojibake().ifBlank { "PENDING" }
            binding.txtAuditStatus.text = when (status) {
                "PENDING" -> "待审批"
                "APPROVED" -> "已通过"
                "REJECTED" -> "已驳回"
                else -> status
            }
            when (status) {
                "PENDING" -> {
                    binding.txtAuditStatus.setBackgroundResource(R.drawable.bg_chip_warning)
                    binding.txtAuditStatus.setTextColor(binding.root.context.getColor(R.color.statusWarning))
                }
                "APPROVED" -> {
                    binding.txtAuditStatus.setBackgroundResource(R.drawable.bg_chip_valid)
                    binding.txtAuditStatus.setTextColor(binding.root.context.getColor(R.color.statusValid))
                }
                "REJECTED" -> {
                    binding.txtAuditStatus.setBackgroundResource(R.drawable.bg_chip_expired)
                    binding.txtAuditStatus.setTextColor(binding.root.context.getColor(R.color.statusExpired))
                }
                else -> {
                    binding.txtAuditStatus.setBackgroundResource(R.drawable.bg_chip_neutral)
                    binding.txtAuditStatus.setTextColor(binding.root.context.getColor(R.color.textSecondary))
                }
            }

            val pendingMode = modeProvider() == AuditListMode.PENDING
            binding.buttonApprove.visibility = if (pendingMode) android.view.View.VISIBLE else android.view.View.GONE
            binding.buttonReject.visibility = if (pendingMode) android.view.View.VISIBLE else android.view.View.GONE
            binding.buttonViewAudit.setOnClickListener { onView(item) }
            binding.buttonApprove.setOnClickListener { onApprove(item) }
            binding.buttonReject.setOnClickListener { onReject(item) }
            binding.root.setOnClickListener { onView(item) }
        }
    }
}
