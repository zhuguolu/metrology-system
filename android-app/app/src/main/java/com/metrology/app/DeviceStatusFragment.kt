package com.metrology.app

import android.app.AlertDialog
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.metrology.app.databinding.FragmentDeviceStatusBinding
import kotlinx.coroutines.launch

class DeviceStatusFragment : Fragment() {
    private var _binding: FragmentDeviceStatusBinding? = null
    private val binding get() = _binding!!

    private val adapter by lazy {
        DeviceStatusAdapter(
            onEdit = { showEditDialog(it) },
            onDelete = { deleteStatus(it) }
        )
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentDeviceStatusBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.recyclerStatus.layoutManager = LinearLayoutManager(requireContext())
        binding.recyclerStatus.adapter = adapter
        binding.buttonAddStatus.setOnClickListener { createStatus() }
        loadStatuses()
    }

    private fun loadStatuses() {
        viewLifecycleOwner.lifecycleScope.launch {
            binding.txtStatusHint.showLoadingState()
            runCatching { AppGraph.repository.deviceStatuses() }
                .onSuccess { list ->
                    adapter.submitList(list)
                    if (list.isEmpty()) {
                        binding.txtStatusHint.showEmptyState("暂无状态配置")
                    } else {
                        binding.txtStatusHint.showReadyState("共 ${list.size} 个状态")
                    }
                }
                .onFailure {
                    binding.txtStatusHint.showErrorState(it.message ?: "加载失败")
                }
        }
    }

    private fun createStatus() {
        val name = binding.inputStatusName.text?.toString().orEmpty().trim()
        if (name.isBlank()) {
            Toast.makeText(requireContext(), "请输入状态名称", Toast.LENGTH_SHORT).show()
            return
        }
        viewLifecycleOwner.lifecycleScope.launch {
            runCatching { AppGraph.repository.createDeviceStatus(name) }
                .onSuccess {
                    binding.inputStatusName.setText("")
                    loadStatuses()
                }
                .onFailure {
                    Toast.makeText(requireContext(), it.message ?: "新增失败", Toast.LENGTH_SHORT).show()
                }
        }
    }

    private fun showEditDialog(item: DeviceStatusDto) {
        val input = EditText(requireContext()).apply {
            setText(item.name.orEmpty())
            setPadding(36, 28, 36, 28)
        }
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("编辑状态")
            .setView(input)
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton(getString(R.string.action_save)) { _, _ ->
                val id = item.id ?: return@setPositiveButton
                val name = input.text?.toString().orEmpty().trim()
                if (name.isBlank()) return@setPositiveButton
                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.updateDeviceStatus(id, name) }
                        .onSuccess { loadStatuses() }
                        .onFailure {
                            Toast.makeText(requireContext(), it.message ?: "更新失败", Toast.LENGTH_SHORT).show()
                        }
                }
            }
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun deleteStatus(item: DeviceStatusDto) {
        val id = item.id ?: return
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("删除状态")
            .setMessage("确定删除“${item.name.orEmpty()}”吗？")
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton("删除") { _, _ ->
                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.deleteDeviceStatus(id) }
                        .onSuccess { loadStatuses() }
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
        _binding = null
        super.onDestroyView()
    }
}
