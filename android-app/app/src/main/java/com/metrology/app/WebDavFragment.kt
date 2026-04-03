package com.metrology.app

import android.app.AlertDialog
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.text.InputType
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.metrology.app.databinding.FragmentWebdavBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class WebDavFragment : Fragment() {
    private var _binding: FragmentWebdavBinding? = null
    private val binding get() = _binding!!

    private val fileAdapter by lazy { WebDavFileAdapter(onOpen = { openWebDavItem(it) }) }

    private var mounts: List<WebDavMountDto> = emptyList()
    private var selectedMountId: Long? = null
    private var currentPath: String = ""

    private val uploadLauncher = registerForActivityResult(
        ActivityResultContracts.OpenMultipleDocuments()
    ) { uris ->
        if (uris.isNullOrEmpty()) return@registerForActivityResult
        uploadFiles(uris)
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentWebdavBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.recyclerWebDavFile.layoutManager = LinearLayoutManager(requireContext())
        binding.recyclerWebDavFile.adapter = fileAdapter

        binding.spinnerMount.onItemSelectedListener = object : android.widget.AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: android.widget.AdapterView<*>?, view: View?, position: Int, id: Long) {
                val mount = mounts.getOrNull(position) ?: return
                if (mount.id == selectedMountId) return
                selectedMountId = mount.id
                currentPath = ""
                loadFiles()
            }

            override fun onNothingSelected(parent: android.widget.AdapterView<*>?) = Unit
        }

        binding.buttonRefreshMount.setOnClickListener { loadMounts() }
        binding.buttonAddMount.setOnClickListener { showMountDialog(null) }
        binding.buttonEditMount.setOnClickListener { showEditMountDialog() }
        binding.buttonDeleteMount.setOnClickListener { confirmDeleteSelectedMount() }
        binding.buttonTestMount.setOnClickListener { testSelectedMountConnection() }

        binding.buttonRefreshWebDavFiles.setOnClickListener { loadFiles() }
        binding.buttonWebDavRoot.setOnClickListener {
            currentPath = ""
            loadFiles()
        }
        binding.buttonWebDavBack.setOnClickListener {
            if (currentPath.isBlank()) return@setOnClickListener
            val normalized = currentPath.trim('/').split('/').dropLast(1)
            currentPath = if (normalized.isEmpty()) "" else normalized.joinToString("/", postfix = "/")
            loadFiles()
        }
        binding.buttonUploadWebDav.setOnClickListener {
            if (selectedMountId == null) {
                toast("请先选择挂载点")
                return@setOnClickListener
            }
            uploadLauncher.launch(arrayOf("*/*"))
        }

        loadMounts()
    }

    private fun loadMounts() {
        viewLifecycleOwner.lifecycleScope.launch {
            binding.txtWebDavHint.showLoadingState()
            runCatching { AppGraph.repository.webDavMounts() }
                .onSuccess { list ->
                    mounts = list
                    val names = if (list.isEmpty()) {
                        listOf("无可用挂载点")
                    } else {
                        list.map { it.name.fixMojibake().ifBlank { "未命名挂载" } }
                    }
                    val spinnerAdapter = ArrayAdapter(
                        requireContext(),
                        android.R.layout.simple_spinner_dropdown_item,
                        names
                    )
                    binding.spinnerMount.adapter = spinnerAdapter

                    if (list.isEmpty()) {
                        selectedMountId = null
                        currentPath = ""
                        fileAdapter.submitList(emptyList())
                        binding.txtWebDavPath.text = "路径: /"
                        binding.txtWebDavHint.showEmptyState("暂无挂载点，请先新增")
                    } else {
                        val selectedIndex = list.indexOfFirst { it.id == selectedMountId }.takeIf { it >= 0 } ?: 0
                        binding.spinnerMount.setSelection(selectedIndex)
                        selectedMountId = list[selectedIndex].id
                        loadFiles()
                    }
                    refreshMountButtonsState()
                }
                .onFailure {
                    val message = it.toUserMessage("加载挂载点失败")
                    binding.txtWebDavHint.showErrorState(message)
                    toast(message)
                }
        }
    }

    private fun refreshMountButtonsState() {
        val hasMount = selectedMount() != null
        binding.buttonEditMount.isEnabled = hasMount
        binding.buttonDeleteMount.isEnabled = hasMount
        binding.buttonTestMount.isEnabled = hasMount
        binding.buttonUploadWebDav.isEnabled = hasMount
    }

    private fun loadFiles() {
        val mountId = selectedMountId ?: run {
            binding.txtWebDavHint.showEmptyState("请先选择挂载点")
            refreshMountButtonsState()
            return
        }
        viewLifecycleOwner.lifecycleScope.launch {
            binding.txtWebDavPath.text = "路径: /${currentPath}"
            binding.txtWebDavHint.showLoadingState()
            runCatching { AppGraph.repository.webDavBrowse(mountId, currentPath.ifBlank { null }) }
                .onSuccess { list ->
                    fileAdapter.submitList(list)
                    if (list.isEmpty()) {
                        binding.txtWebDavHint.showEmptyState("当前目录暂无文件")
                    } else {
                        binding.txtWebDavHint.showReadyState("共 ${list.size} 项")
                    }
                }
                .onFailure {
                    val message = it.toUserMessage("加载目录失败")
                    binding.txtWebDavHint.showErrorState(message)
                    toast(message)
                }
            refreshMountButtonsState()
        }
    }

    private fun openWebDavItem(item: WebDavFileDto) {
        if (item.isDirectory == true) {
            val path = item.path.orEmpty().trim('/')
            currentPath = if (path.isBlank()) "" else "$path/"
            loadFiles()
            return
        }
        showWebDavFileActionDialog(item)
    }

    private fun showWebDavFileActionDialog(item: WebDavFileDto) {
        val options = arrayOf("下载到本地", "下载并打开")
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle(item.name.fixMojibakeOrDash())
            .setItems(options) { _, which ->
                when (which) {
                    0 -> downloadFile(item, openAfterDownload = false)
                    1 -> downloadFile(item, openAfterDownload = true)
                }
            }
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun downloadFile(item: WebDavFileDto, openAfterDownload: Boolean) {
        val mountId = selectedMountId ?: run {
            toast("请先选择挂载点")
            return
        }
        val path = item.path.orEmpty().trim()
        if (path.isBlank()) {
            toast("文件路径无效")
            return
        }
        viewLifecycleOwner.lifecycleScope.launch {
            val name = item.name.fixMojibake().ifBlank { "download.bin" }
            binding.txtWebDavHint.showLoadingState("正在下载 $name")
            runCatching {
                val body = AppGraph.repository.webDavDownload(mountId = mountId, path = path, filename = item.name)
                saveToDownloadDir(requireContext(), name, body)
            }.onSuccess { savedFile ->
                binding.txtWebDavHint.showReadyState("已下载: ${savedFile.name}")
                toast("已保存到: ${savedFile.absolutePath}")
                if (openAfterDownload) {
                    openFileByIntent(requireContext(), savedFile, item.contentType)
                }
            }.onFailure {
                val message = it.toUserMessage("下载失败")
                binding.txtWebDavHint.showErrorState(message)
                toast(message)
            }
        }
    }

    private fun uploadFiles(uris: List<Uri>) {
        val mountId = selectedMountId ?: return
        viewLifecycleOwner.lifecycleScope.launch {
            var successCount = 0
            var failCount = 0
            binding.txtWebDavHint.showLoadingState("正在上传 ${uris.size} 个文件...")
            for (uri in uris) {
                val payload = readUploadPayload(uri)
                if (payload == null) {
                    failCount += 1
                    continue
                }
                val result = runCatching {
                    AppGraph.repository.webDavUpload(
                        mountId = mountId,
                        path = uploadDirectoryPath(),
                        fileName = payload.name,
                        mimeType = payload.mimeType,
                        bytes = payload.bytes
                    )
                }
                if (result.isSuccess) {
                    successCount += 1
                } else {
                    failCount += 1
                }
            }
            val summary = "上传完成：成功 $successCount，失败 $failCount"
            binding.txtWebDavHint.showReadyState(summary)
            toast(summary)
            loadFiles()
        }
    }

    private fun uploadDirectoryPath(): String {
        if (currentPath.isBlank()) return "/"
        return if (currentPath.endsWith('/')) currentPath else "$currentPath/"
    }

    private suspend fun readUploadPayload(uri: Uri): UploadPayload? = withContext(Dispatchers.IO) {
        runCatching {
            val resolver = requireContext().contentResolver
            val displayName = resolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )?.use { cursor ->
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && cursor.moveToFirst()) {
                    cursor.getString(idx)
                } else {
                    null
                }
            }
            val name = displayName?.trim().takeUnless { it.isNullOrBlank() }
                ?: "upload_${System.currentTimeMillis()}.bin"
            val mimeType = resolver.getType(uri)
            val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw IllegalArgumentException("读取文件失败")
            UploadPayload(name = name, mimeType = mimeType, bytes = bytes)
        }.getOrNull()
    }

    private fun showEditMountDialog() {
        val mount = selectedMount() ?: run {
            toast("请先选择挂载点")
            return
        }
        showMountDialog(mount)
    }

    private fun confirmDeleteSelectedMount() {
        val mount = selectedMount() ?: run {
            toast("请先选择挂载点")
            return
        }
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("删除挂载点")
            .setMessage("确定删除挂载点“${mount.name.fixMojibakeOrDash()}”？")
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton("删除") { _, _ ->
                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.deleteWebDavMount(mount.id ?: -1L) }
                        .onSuccess {
                            toast("挂载点已删除")
                            if (selectedMountId == mount.id) {
                                selectedMountId = null
                                currentPath = ""
                            }
                            loadMounts()
                        }
                        .onFailure {
                            toast(it.toUserMessage("删除挂载点失败"))
                        }
                }
            }
            .create()
        dialog.setOnShowListener {
            dialog.applyMetrologyDialogStyle(positiveStyle = DialogPositiveStyle.DANGER)
        }
        dialog.show()
    }

    private fun testSelectedMountConnection() {
        val mount = selectedMount() ?: run {
            toast("请先选择挂载点")
            return
        }
        viewLifecycleOwner.lifecycleScope.launch {
            runCatching {
                AppGraph.repository.testWebDavConnection(
                    url = mount.url.orEmpty(),
                    username = mount.username.orEmpty(),
                    password = mount.password.orEmpty()
                )
            }.onSuccess { success ->
                toast(if (success) "连接测试成功" else "连接测试失败")
            }.onFailure {
                toast(it.toUserMessage("连接测试失败"))
            }
        }
    }

    private fun showMountDialog(editingMount: WebDavMountDto?) {
        val container = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(36, 24, 36, 8)
        }
        val inputName = EditText(requireContext()).apply {
            hint = "挂载名称"
            setText(editingMount?.name.fixMojibake())
        }
        val inputUrl = EditText(requireContext()).apply {
            hint = "WebDAV 地址"
            setText(editingMount?.url.fixMojibake())
        }
        val inputUsername = EditText(requireContext()).apply {
            hint = "用户名（可空）"
            setText(editingMount?.username.fixMojibake())
        }
        val inputPassword = EditText(requireContext()).apply {
            hint = if (editingMount == null) "密码（可空）" else "密码（留空则不修改）"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        }

        container.addView(inputName)
        container.addView(inputUrl)
        container.addView(inputUsername)
        container.addView(inputPassword)

        val dialog = AlertDialog.Builder(requireContext())
            .setTitle(if (editingMount == null) "新增挂载点" else "编辑挂载点")
            .setView(container)
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setNeutralButton("测试连接", null)
            .setPositiveButton(getString(R.string.action_save), null)
            .create()

        dialog.setOnShowListener {
            dialog.applyMetrologyDialogStyle()
            val positiveButton = dialog.getButton(AlertDialog.BUTTON_POSITIVE)
            val neutralButton = dialog.getButton(AlertDialog.BUTTON_NEUTRAL)

            positiveButton.setOnClickListener {
                val payload = buildMountPayload(
                    inputName.text?.toString(),
                    inputUrl.text?.toString(),
                    inputUsername.text?.toString(),
                    inputPassword.text?.toString()
                ) ?: return@setOnClickListener

                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching {
                        if (editingMount?.id != null) {
                            AppGraph.repository.updateWebDavMount(editingMount.id, payload)
                        } else {
                            AppGraph.repository.createWebDavMount(
                                payload["name"].orEmpty(),
                                payload["url"].orEmpty(),
                                payload["username"].orEmpty(),
                                payload["password"].orEmpty()
                            )
                        }
                    }.onSuccess {
                        toast(if (editingMount == null) "挂载点已新增" else "挂载点已更新")
                        dialog.dismiss()
                        loadMounts()
                    }.onFailure {
                        toast(it.toUserMessage("保存挂载点失败"))
                    }
                }
            }

            neutralButton.setOnClickListener {
                val payload = buildMountPayload(
                    inputName.text?.toString(),
                    inputUrl.text?.toString(),
                    inputUsername.text?.toString(),
                    inputPassword.text?.toString()
                ) ?: return@setOnClickListener
                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching {
                        AppGraph.repository.testWebDavConnection(
                            url = payload["url"].orEmpty(),
                            username = payload["username"].orEmpty(),
                            password = payload["password"].orEmpty()
                        )
                    }.onSuccess { success ->
                        toast(if (success) "连接测试成功" else "连接测试失败")
                    }.onFailure {
                        toast(it.toUserMessage("连接测试失败"))
                    }
                }
            }
        }

        dialog.show()
    }

    private fun buildMountPayload(
        nameRaw: String?,
        urlRaw: String?,
        usernameRaw: String?,
        passwordRaw: String?
    ): Map<String, String>? {
        val name = nameRaw.orEmpty().trim()
        val url = urlRaw.orEmpty().trim()
        val username = usernameRaw.orEmpty().trim()
        val password = passwordRaw.orEmpty()
        if (name.isBlank()) {
            toast("请填写挂载名称")
            return null
        }
        if (url.isBlank()) {
            toast("请填写 WebDAV 地址")
            return null
        }
        return mapOf(
            "name" to name,
            "url" to url,
            "username" to username,
            "password" to password
        )
    }

    private fun selectedMount(): WebDavMountDto? {
        val id = selectedMountId ?: return null
        return mounts.firstOrNull { it.id == id }
    }

    private fun toast(message: String) {
        Toast.makeText(requireContext(), message.fixMojibake(), Toast.LENGTH_SHORT).show()
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }

    private data class UploadPayload(
        val name: String,
        val mimeType: String?,
        val bytes: ByteArray
    )
}
