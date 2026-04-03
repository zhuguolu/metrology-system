package com.metrology.app

import android.app.AlertDialog
import android.os.Bundle
import android.text.InputType
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.metrology.app.databinding.FragmentUserManagementBinding
import kotlinx.coroutines.launch

class UserManagementFragment : Fragment() {
    private var _binding: FragmentUserManagementBinding? = null
    private val binding get() = _binding!!

    private val adapter by lazy {
        UserAdapter(
            currentUsername = AppGraph.repository.username(),
            onResetPassword = { showResetPasswordDialog(it) },
            onDelete = { deleteUser(it) },
            onPermission = { showPermissionDialog(it) }
        )
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentUserManagementBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.recyclerUser.layoutManager = LinearLayoutManager(requireContext())
        binding.recyclerUser.adapter = adapter
        binding.buttonRefreshUser.setOnClickListener { loadUsers() }
        binding.buttonAddUser.setOnClickListener { showCreateUserDialog() }
        loadUsers()
    }

    private fun loadUsers() {
        viewLifecycleOwner.lifecycleScope.launch {
            binding.txtUserHint.text = getString(R.string.label_loading)
            runCatching { AppGraph.repository.users() }
                .onSuccess { list ->
                    adapter.submitList(list)
                    binding.txtUserSummary.text = "用户总数: ${list.size}"
                    binding.txtUserHint.text = if (list.isEmpty()) {
                        "暂无用户数据"
                    } else {
                        "可重置密码、删除用户或设置普通用户权限"
                    }
                }
                .onFailure {
                    binding.txtUserHint.text = it.toUserMessage("加载失败")
                }
        }
    }

    private fun showCreateUserDialog() {
        val scroll = ScrollView(requireContext())
        val container = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(36, 24, 36, 8)
        }
        scroll.addView(container)

        val username = EditText(requireContext()).apply {
            hint = "用户名"
        }
        val password = EditText(requireContext()).apply {
            hint = "密码（至少6位）"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        }
        val adminCheck = CheckBox(requireContext()).apply {
            text = "创建为管理员"
        }

        container.addView(username)
        container.addView(password)
        container.addView(adminCheck)

        val permissionTitle = TextView(requireContext()).apply {
            text = "普通用户权限"
            textSize = 13f
            setTextColor(requireContext().getColor(R.color.textSecondary))
            setPadding(0, 16, 0, 8)
        }
        container.addView(permissionTitle)

        val permissionChecks = addPermissionChecks(
            container = container,
            selected = defaultUserPermissionCodes
        )

        adminCheck.setOnCheckedChangeListener { _, checked ->
            setPermissionControlsEnabled(permissionChecks, !checked)
            permissionTitle.alpha = if (checked) 0.45f else 1f
        }

        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("新增用户")
            .setView(scroll)
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton(getString(R.string.action_save)) { _, _ ->
                val u = username.text?.toString().orEmpty().trim()
                val p = password.text?.toString().orEmpty()
                if (u.isBlank() || p.length < 6) {
                    Toast.makeText(requireContext(), "请输入有效用户名和密码", Toast.LENGTH_SHORT).show()
                    return@setPositiveButton
                }

                val selectedPermissions = permissionChecks
                    .filterValues { it.isChecked }
                    .keys
                    .toList()

                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching {
                        AppGraph.repository.createUser(
                            username = u,
                            password = p,
                            admin = adminCheck.isChecked,
                            permissions = selectedPermissions
                        )
                    }.onSuccess {
                        toast("用户创建成功")
                        loadUsers()
                    }.onFailure {
                        Toast.makeText(requireContext(), it.toUserMessage("创建失败"), Toast.LENGTH_SHORT).show()
                    }
                }
            }
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun showPermissionDialog(item: UserDto) {
        val id = item.id ?: return
        val role = item.role.fixMojibake().ifBlank { "USER" }
        if (role.equals("ADMIN", true)) {
            toast("管理员默认拥有全部权限，无需单独设置")
            return
        }

        val selected = item.permissions.orEmpty()
            .map { it.fixMojibake().trim() }
            .filter { it.isNotBlank() }
            .toSet()

        val scroll = ScrollView(requireContext())
        val container = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(36, 24, 36, 8)
        }
        scroll.addView(container)

        val tip = TextView(requireContext()).apply {
            text = "用户：${item.username.fixMojibakeOrDash()}"
            textSize = 13f
            setTextColor(requireContext().getColor(R.color.textSecondary))
            setPadding(0, 0, 0, 8)
        }
        container.addView(tip)

        val permissionChecks = addPermissionChecks(container = container, selected = selected)

        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("设置普通用户权限")
            .setView(scroll)
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton(getString(R.string.action_save)) { _, _ ->
                val permissions = permissionChecks
                    .filterValues { it.isChecked }
                    .keys
                    .toList()
                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching {
                        AppGraph.repository.updateUserRolePermissions(
                            id = id,
                            role = "USER",
                            departments = resolveDepartments(item),
                            permissions = permissions,
                            readonlyFolderIds = item.readonlyFolderIds.orEmpty()
                        )
                    }.onSuccess {
                        toast("权限已更新")
                        loadUsers()
                    }.onFailure {
                        toast(it.toUserMessage("更新权限失败"))
                    }
                }
            }
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun addPermissionChecks(
        container: LinearLayout,
        selected: Set<String>
    ): Map<String, CheckBox> {
        val checks = linkedMapOf<String, CheckBox>()
        permissionOptions.forEach { option ->
            val checkBox = CheckBox(requireContext()).apply {
                text = option.label
                isChecked = if (selected.isNotEmpty()) {
                    selected.contains(option.code)
                } else {
                    defaultUserPermissionCodes.contains(option.code)
                }
            }
            checks[option.code] = checkBox
            container.addView(checkBox)
        }
        return checks
    }

    private fun setPermissionControlsEnabled(
        checks: Map<String, CheckBox>,
        enabled: Boolean
    ) {
        checks.values.forEach { check ->
            check.isEnabled = enabled
            check.alpha = if (enabled) 1f else 0.45f
        }
    }

    private fun resolveDepartments(item: UserDto): List<String> {
        val fromList = item.departments.orEmpty()
            .map { it.fixMojibake().trim() }
            .filter { it.isNotBlank() }
            .distinct()
        if (fromList.isNotEmpty()) return fromList

        return item.department.fixMojibake()
            .replace('，', ',')
            .split(',')
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
    }

    private fun showResetPasswordDialog(item: UserDto) {
        val id = item.id ?: return
        val input = EditText(requireContext()).apply {
            hint = "输入新密码（至少6位）"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            setPadding(36, 24, 36, 24)
        }
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("重置密码")
            .setMessage("用户: ${item.username.fixMojibakeOrDash()}")
            .setView(input)
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton(getString(R.string.action_save)) { _, _ ->
                val newPassword = input.text?.toString().orEmpty()
                if (newPassword.length < 6) {
                    Toast.makeText(requireContext(), "密码长度不足", Toast.LENGTH_SHORT).show()
                    return@setPositiveButton
                }
                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.resetUserPassword(id, newPassword) }
                        .onSuccess {
                            Toast.makeText(requireContext(), "密码已更新", Toast.LENGTH_SHORT).show()
                        }
                        .onFailure {
                            Toast.makeText(requireContext(), it.toUserMessage("重置失败"), Toast.LENGTH_SHORT).show()
                        }
                }
            }
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun deleteUser(item: UserDto) {
        val id = item.id ?: return
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("删除用户")
            .setMessage("确定删除用户“${item.username.fixMojibakeOrDash()}”吗？")
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton("删除") { _, _ ->
                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.deleteUser(id) }
                        .onSuccess { loadUsers() }
                        .onFailure {
                            Toast.makeText(requireContext(), it.toUserMessage("删除失败"), Toast.LENGTH_SHORT).show()
                        }
                }
            }
            .create()
        dialog.setOnShowListener {
            dialog.applyMetrologyDialogStyle(positiveStyle = DialogPositiveStyle.DANGER)
        }
        dialog.show()
    }

    private fun toast(message: String) {
        Toast.makeText(requireContext(), message.fixMojibake(), Toast.LENGTH_SHORT).show()
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }

    private data class PermissionOption(
        val code: String,
        val label: String
    )

    companion object {
        private val permissionOptions = listOf(
            PermissionOption("DEVICE_VIEW", "设备查看"),
            PermissionOption("DEVICE_CREATE", "设备新增"),
            PermissionOption("DEVICE_UPDATE", "设备编辑"),
            PermissionOption("DEVICE_DELETE", "设备删除"),
            PermissionOption("CALIBRATION_RECORD", "校准记录"),
            PermissionOption("STATUS_MANAGE", "使用状态管理"),
            PermissionOption("FILE_ACCESS", "我的文件"),
            PermissionOption("WEBDAV_ACCESS", "网络挂载"),
            PermissionOption("USER_MANAGE", "用户管理")
        )

        private val defaultUserPermissionCodes = setOf(
            "DEVICE_VIEW",
            "DEVICE_CREATE",
            "DEVICE_UPDATE",
            "DEVICE_DELETE",
            "CALIBRATION_RECORD",
            "STATUS_MANAGE",
            "FILE_ACCESS",
            "WEBDAV_ACCESS"
        )
    }
}
