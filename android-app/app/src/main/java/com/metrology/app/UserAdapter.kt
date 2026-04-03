package com.metrology.app

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.metrology.app.databinding.ItemUserBinding

class UserAdapter(
    private val currentUsername: String,
    private val onResetPassword: (UserDto) -> Unit,
    private val onDelete: (UserDto) -> Unit,
    private val onPermission: (UserDto) -> Unit
) : RecyclerView.Adapter<UserAdapter.UserViewHolder>() {
    private val items = mutableListOf<UserDto>()

    fun submitList(data: List<UserDto>) {
        items.clear()
        items.addAll(data)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): UserViewHolder {
        val binding = ItemUserBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return UserViewHolder(binding, currentUsername, onResetPassword, onDelete, onPermission)
    }

    override fun onBindViewHolder(holder: UserViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    class UserViewHolder(
        private val binding: ItemUserBinding,
        private val currentUsername: String,
        private val onResetPassword: (UserDto) -> Unit,
        private val onDelete: (UserDto) -> Unit,
        private val onPermission: (UserDto) -> Unit
    ) : RecyclerView.ViewHolder(binding.root) {
        fun bind(item: UserDto) {
            val username = item.username.fixMojibakeOrDash()
            val role = item.role.fixMojibake().ifBlank { "USER" }
            val depts = item.departments.orEmpty()
                .map { it.fixMojibake() }
                .joinToString("、")
                .ifBlank { item.department.fixMojibakeOrDash() }
            val permissionSize = item.permissions.orEmpty().size

            binding.txtUserName.text = if (username == currentUsername) "$username（我）" else username
            binding.chipUserRole.text = if (role.equals("ADMIN", true)) "管理员" else "普通用户"
            binding.txtUserMeta1.text = "部门: $depts"
            binding.txtUserMeta2.text = "权限数: $permissionSize   创建: ${item.createdAt.fixMojibakeOrDash()}"

            binding.buttonResetUserPassword.setOnClickListener { onResetPassword(item) }

            val isAdmin = role.equals("ADMIN", true)
            binding.buttonUserPermission.alpha = if (isAdmin) 0.45f else 1f
            binding.buttonUserPermission.isEnabled = !isAdmin
            binding.buttonUserPermission.setOnClickListener {
                if (!isAdmin) onPermission(item)
            }

            val canDelete = username != currentUsername
            binding.buttonDeleteUser.alpha = if (canDelete) 1f else 0.4f
            binding.buttonDeleteUser.isEnabled = canDelete
            binding.buttonDeleteUser.setOnClickListener { if (canDelete) onDelete(item) }
        }
    }
}
