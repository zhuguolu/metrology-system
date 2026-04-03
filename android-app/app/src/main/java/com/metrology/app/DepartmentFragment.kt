package com.metrology.app

import android.app.AlertDialog
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Toast
import androidx.core.widget.doOnTextChanged
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.metrology.app.databinding.FragmentDepartmentBinding
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class DepartmentFragment : Fragment() {
    private var _binding: FragmentDepartmentBinding? = null
    private val binding get() = _binding!!

    private val adapter by lazy {
        DepartmentAdapter(
            onEdit = { showEditDialog(it) },
            onDelete = { deleteDepartment(it) }
        )
    }

    private var searchJob: Job? = null
    private var lastKeyword: String = ""
    private var currentData: List<DepartmentDto> = emptyList()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentDepartmentBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.recyclerDept.layoutManager = LinearLayoutManager(requireContext())
        binding.recyclerDept.adapter = adapter

        binding.buttonSearchDept.setOnClickListener { load(binding.inputDeptSearch.text?.toString().orEmpty()) }
        binding.buttonRefreshDept.setOnClickListener { load(lastKeyword) }
        binding.buttonAddDept.setOnClickListener { showCreateDialog() }
        binding.inputDeptSearch.doOnTextChanged { text, _, _, _ ->
            searchJob?.cancel()
            searchJob = viewLifecycleOwner.lifecycleScope.launch {
                delay(350L)
                load(text?.toString().orEmpty())
            }
        }
        load("")
    }

    private fun load(search: String) {
        lastKeyword = search.trim()
        viewLifecycleOwner.lifecycleScope.launch {
            binding.txtDeptHint.showLoadingState()
            runCatching { AppGraph.repository.departments(lastKeyword) }
                .onSuccess { list ->
                    currentData = list
                    adapter.submitList(list)
                    if (list.isEmpty()) {
                        binding.txtDeptHint.showEmptyState("暂无部门数据")
                    } else {
                        binding.txtDeptHint.showReadyState("共 ${list.size} 个部门")
                    }
                }
                .onFailure {
                    binding.txtDeptHint.showErrorState(it.message ?: "加载失败")
                }
        }
    }

    private fun showCreateDialog() {
        showDepartmentEditor(
            title = "新增部门",
            current = null
        ) { name, code, sortOrder, parentId ->
            viewLifecycleOwner.lifecycleScope.launch {
                runCatching {
                    AppGraph.repository.createDepartment(
                        name = name,
                        code = code,
                        sortOrder = sortOrder,
                        parentId = parentId
                    )
                }.onSuccess {
                    load(lastKeyword)
                }.onFailure {
                    Toast.makeText(requireContext(), it.message ?: "新增失败", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun showEditDialog(item: DepartmentDto) {
        showDepartmentEditor(
            title = "编辑部门",
            current = item
        ) { name, code, sortOrder, parentId ->
            val id = item.id ?: return@showDepartmentEditor
            viewLifecycleOwner.lifecycleScope.launch {
                runCatching {
                    AppGraph.repository.updateDepartment(
                        id = id,
                        name = name,
                        code = code,
                        sortOrder = sortOrder,
                        parentId = parentId
                    )
                }.onSuccess {
                    load(lastKeyword)
                }.onFailure {
                    Toast.makeText(requireContext(), it.message ?: "更新失败", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun showDepartmentEditor(
        title: String,
        current: DepartmentDto?,
        onConfirm: (name: String, code: String, sortOrder: Int, parentId: Long?) -> Unit
    ) {
        val container = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(36, 24, 36, 8)
        }
        val inputName = EditText(requireContext()).apply {
            hint = "部门名称"
            setText(current?.name.orEmpty())
        }
        val inputCode = EditText(requireContext()).apply {
            hint = "部门编码（可选）"
            setText(current?.code.orEmpty())
        }
        val inputSort = EditText(requireContext()).apply {
            hint = "排序值（数字）"
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
            setText((current?.sortOrder ?: 0).toString())
        }
        val inputParent = EditText(requireContext()).apply {
            hint = "上级部门ID（可空）"
            setText(current?.parentId?.toString().orEmpty())
        }
        container.addView(inputName)
        container.addView(inputCode)
        container.addView(inputSort)
        container.addView(inputParent)

        val dialog = AlertDialog.Builder(requireContext())
            .setTitle(title)
            .setView(container)
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton(getString(R.string.action_save)) { _, _ ->
                val name = inputName.text?.toString().orEmpty().trim()
                val code = inputCode.text?.toString().orEmpty().trim()
                val sort = inputSort.text?.toString()?.toIntOrNull() ?: 0
                val parent = inputParent.text?.toString()?.toLongOrNull()
                if (name.isBlank()) {
                    Toast.makeText(requireContext(), "部门名称不能为空", Toast.LENGTH_SHORT).show()
                    return@setPositiveButton
                }
                onConfirm(name, code, sort, parent)
            }
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun deleteDepartment(item: DepartmentDto) {
        val id = item.id ?: return
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("删除部门")
            .setMessage("确定删除“${item.name.orEmpty()}”吗？")
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton("删除") { _, _ ->
                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.deleteDepartment(id) }
                        .onSuccess { load(lastKeyword) }
                        .onFailure {
                            Toast.makeText(requireContext(), it.message ?: "删除失败", Toast.LENGTH_SHORT).show()
                        }
                }
            }
            .create()
        dialog.setOnShowListener {
            dialog.applyMetrologyDialogStyle(positiveStyle = DialogPositiveStyle.DANGER)
        }
        dialog.show()
    }

    override fun onDestroyView() {
        searchJob?.cancel()
        _binding = null
        super.onDestroyView()
    }
}
