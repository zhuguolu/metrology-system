package com.metrology.app

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.metrology.app.databinding.ItemDepartmentBinding

class DepartmentAdapter(
    private val onEdit: (DepartmentDto) -> Unit,
    private val onDelete: (DepartmentDto) -> Unit
) : RecyclerView.Adapter<DepartmentAdapter.DepartmentViewHolder>() {
    private val items = mutableListOf<DepartmentDto>()
    private val namesById = mutableMapOf<Long, String>()

    fun submitList(data: List<DepartmentDto>) {
        items.clear()
        items.addAll(data)
        namesById.clear()
        data.forEach { dto ->
            val id = dto.id ?: return@forEach
            namesById[id] = dto.name.fixMojibake()
        }
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): DepartmentViewHolder {
        val binding = ItemDepartmentBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return DepartmentViewHolder(binding, onEdit, onDelete, namesById)
    }

    override fun onBindViewHolder(holder: DepartmentViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    class DepartmentViewHolder(
        private val binding: ItemDepartmentBinding,
        private val onEdit: (DepartmentDto) -> Unit,
        private val onDelete: (DepartmentDto) -> Unit,
        private val namesById: Map<Long, String>
    ) : RecyclerView.ViewHolder(binding.root) {
        fun bind(item: DepartmentDto) {
            binding.txtDeptName.text = item.name.fixMojibakeOrDash()
            binding.txtDeptMeta1.text = "编码: ${item.code.fixMojibakeOrDash()}   排序: ${item.sortOrder ?: 0}"
            val parentName = item.parentId?.let { namesById[it] }.fixMojibakeOrDash()
            binding.txtDeptMeta2.text = "上级: $parentName"
            binding.buttonEditDept.setOnClickListener { onEdit(item) }
            binding.buttonDeleteDept.setOnClickListener { onDelete(item) }
        }
    }
}
