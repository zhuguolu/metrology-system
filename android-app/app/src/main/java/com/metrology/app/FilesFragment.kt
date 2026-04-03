package com.metrology.app

import android.app.AlertDialog
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.OnBackPressedCallback
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.metrology.app.databinding.FragmentFilesBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class FilesFragment : Fragment() {
    private var _binding: FragmentFilesBinding? = null
    private val binding get() = _binding!!

    private val adapter by lazy {
        FileAdapter(
            onOpen = { openItem(it) },
            onMore = { showItemActions(it) }
        )
    }

    private var currentFolderId: Long? = null
    private var currentPath: String = "/"
    private var currentItems: List<UserFileItemDto> = emptyList()
    private var displayItems: List<UserFileItemDto> = emptyList()
    private var canWrite: Boolean = false
    private var readOnlyFolder: Boolean = false
    private var backPressedCallback: OnBackPressedCallback? = null

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
        _binding = FragmentFilesBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        registerBackGestureHandler()
        binding.recyclerFile.layoutManager = LinearLayoutManager(requireContext())
        binding.recyclerFile.adapter = adapter

        binding.buttonFileRoot.setOnClickListener {
            currentFolderId = null
            currentPath = "/"
            loadFiles()
        }
        binding.buttonFileBack.setOnClickListener {
            if (currentFolderId == null) return@setOnClickListener
            resolveParentFromBreadcrumb()
        }
        binding.buttonRefreshFiles.setOnClickListener { loadFiles() }

        binding.buttonSearchFiles.setOnClickListener { applySearchFilter() }
        binding.buttonClearFileSearch.setOnClickListener {
            binding.editFileSearch.setText("")
            applySearchFilter()
        }
        binding.editFileSearch.setOnEditorActionListener { _, actionId, event ->
            val matchedAction = actionId == EditorInfo.IME_ACTION_SEARCH
            val matchedEnter = event?.keyCode == KeyEvent.KEYCODE_ENTER && event.action == KeyEvent.ACTION_DOWN
            if (matchedAction || matchedEnter) {
                applySearchFilter()
                true
            } else {
                false
            }
        }

        binding.buttonUploadFiles.setOnClickListener {
            if (!canWrite) {
                toast("当前目录为只读，不能上传")
                return@setOnClickListener
            }
            uploadLauncher.launch(arrayOf("*/*"))
        }
        binding.buttonCreateFolder.setOnClickListener {
            if (!canWrite) {
                toast("当前目录为只读，不能新建文件夹")
                return@setOnClickListener
            }
            showCreateFolderDialog()
        }
        binding.buttonScanSync.setOnClickListener {
            if (!canWrite) {
                toast("当前目录为只读，不能扫描同步")
                return@setOnClickListener
            }
            runScanSync()
        }

        loadFiles()
    }

    private fun registerBackGestureHandler() {
        val callback = object : OnBackPressedCallback(false) {
            override fun handleOnBackPressed() {
                if (currentFolderId == null) {
                    isEnabled = false
                    activity?.onBackPressedDispatcher?.onBackPressed()
                    isEnabled = true
                    return
                }
                resolveParentFromBreadcrumb()
            }
        }
        requireActivity().onBackPressedDispatcher.addCallback(viewLifecycleOwner, callback)
        backPressedCallback = callback
    }

    private fun loadFiles() {
        viewLifecycleOwner.lifecycleScope.launch {
            binding.txtFileHint.showLoadingState()
            binding.txtFilePath.text = "路径: $currentPath"
            runCatching { AppGraph.repository.files(currentFolderId) }
                .onSuccess { response ->
                    currentItems = response.items.orEmpty()
                    readOnlyFolder = response.access?.readOnly == true
                    canWrite = response.access?.canWrite == true
                    binding.layoutFileWriteActions.isVisible = canWrite && !readOnlyFolder
                    applySearchFilter()
                }
                .onFailure {
                    if (it.isCancellationLike()) return@onFailure
                    val message = it.toUserMessage("加载文件列表失败")
                    binding.txtFileHint.showErrorState(message)
                    toast(message)
                }
            refreshActionState()
        }
    }

    private fun applySearchFilter() {
        val query = binding.editFileSearch.text?.toString().orEmpty().trim()
        displayItems = if (query.isBlank()) {
            currentItems
        } else {
            currentItems.filter { item ->
                item.name.fixMojibake().contains(query, ignoreCase = true)
            }
        }
        adapter.submitList(displayItems)

        val accessText = "只读: ${if (readOnlyFolder) "是" else "否"}  写入: ${if (canWrite) "是" else "否"}"
        val hint = if (query.isBlank()) {
            "共 ${displayItems.size} 项  $accessText"
        } else {
            "搜索“$query”命中 ${displayItems.size} 项  $accessText"
        }
        if (displayItems.isEmpty()) {
            binding.txtFileHint.showEmptyState(hint)
        } else {
            binding.txtFileHint.showReadyState(hint)
        }
    }

    private fun refreshActionState() {
        binding.buttonFileBack.isEnabled = currentFolderId != null
        backPressedCallback?.isEnabled = currentFolderId != null
    }

    private fun resolveParentFromBreadcrumb() {
        val folderId = currentFolderId ?: return
        viewLifecycleOwner.lifecycleScope.launch {
            runCatching { AppGraph.repository.fileBreadcrumb(folderId) }
                .onSuccess { crumbs ->
                    val newCurrent = if (crumbs.size >= 2) crumbs[crumbs.size - 2].id else null
                    currentFolderId = newCurrent
                    currentPath = crumbs.dropLast(1).joinToString(
                        separator = "/",
                        prefix = "/"
                    ) { it.name.orEmpty() }.ifBlank { "/" }
                    loadFiles()
                }
                .onFailure {
                    if (it.isCancellationLike()) return@onFailure
                    toast(it.toUserMessage("返回上级失败"))
                }
        }
    }

    private fun openItem(item: UserFileItemDto) {
        val isFolder = item.type.equals("FOLDER", true)
        if (isFolder) {
            currentFolderId = item.id
            val name = item.name.fixMojibake().ifBlank { "未命名" }
            currentPath = when {
                currentPath == "/" -> "/$name"
                else -> "$currentPath/$name"
            }
            loadFiles()
            return
        }
        showPreviewDialog(item)
    }

    private fun showItemActions(item: UserFileItemDto) {
        if (item.type.equals("FOLDER", true)) {
            val options = mutableListOf("打开文件夹")
            if (isItemWritable(item)) {
                options += "重命名"
                options += "删除"
            }
            val dialog = AlertDialog.Builder(requireContext())
                .setItems(options.toTypedArray()) { _, which ->
                    when (options[which]) {
                        "打开文件夹" -> openItem(item)
                        "重命名" -> showRenameDialog(item)
                        "删除" -> confirmDeleteItem(item)
                    }
                }
                .create()
            dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
            dialog.show()
            return
        }
        showFileActionDialog(item)
    }

    private fun showFileActionDialog(item: UserFileItemDto) {
        val options = mutableListOf("预览", "下载到本地", "下载并打开")
        if (isItemWritable(item)) {
            options += "重命名"
            options += "删除"
        }
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle(item.name.fixMojibakeOrDash())
            .setItems(options.toTypedArray()) { _, which ->
                when (options[which]) {
                    "预览" -> showPreviewDialog(item)
                    "下载到本地" -> downloadFile(item, openAfterDownload = false)
                    "下载并打开" -> downloadFile(item, openAfterDownload = true)
                    "重命名" -> showRenameDialog(item)
                    "删除" -> confirmDeleteItem(item)
                }
            }
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun showPreviewDialog(item: UserFileItemDto) {
        val fileId = item.id
        if (fileId == null || fileId <= 0L) {
            toast("文件ID无效，无法预览")
            return
        }
        val fm = parentFragmentManager
        if (fm.isStateSaved) {
            toast("页面正在切换，请稍后再试")
            return
        }
        val tag = "file_preview_${fileId}"
        if (fm.findFragmentByTag(tag) != null) {
            return
        }
        runCatching {
            FilePreviewDialogFragment.newInstance(item).show(fm, tag)
        }.onFailure {
            toast(it.toUserMessage("打开预览失败"))
        }
    }

    private fun isItemWritable(item: UserFileItemDto): Boolean {
        return canWrite && item.readOnly != true
    }

    private fun downloadFile(item: UserFileItemDto, openAfterDownload: Boolean) {
        val id = item.id ?: run {
            toast("文件ID无效")
            return
        }
        viewLifecycleOwner.lifecycleScope.launch {
            val name = item.name.fixMojibake().ifBlank { "download.bin" }
            binding.txtFileHint.showLoadingState("正在下载 $name")
            runCatching {
                val body = AppGraph.repository.downloadFile(id)
                val ctx = context ?: throw IllegalStateException("页面已离开")
                saveToDownloadDir(ctx, name, body)
            }.onSuccess { savedFile ->
                binding.txtFileHint.showReadyState("已下载: ${savedFile.name}")
                toast("已保存到: ${savedFile.absolutePath}")
                if (openAfterDownload) {
                    val ctx = context ?: return@onSuccess
                    openFileByIntent(ctx, savedFile, item.mimeType)
                }
            }.onFailure {
                if (it.isCancellationLike()) return@onFailure
                val message = it.toUserMessage("下载失败")
                binding.txtFileHint.showErrorState(message)
                toast(message)
            }
        }
    }

    private fun showCreateFolderDialog() {
        val input = EditText(requireContext()).apply {
            hint = "请输入文件夹名称"
            setText("")
        }
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("新建文件夹")
            .setView(input)
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton("创建") { _, _ ->
                val name = input.text?.toString().orEmpty().trim()
                if (name.isBlank()) {
                    toast("文件夹名称不能为空")
                    return@setPositiveButton
                }
                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.createFolder(name, currentFolderId) }
                        .onSuccess {
                            toast("文件夹创建成功")
                            loadFiles()
                        }
                        .onFailure {
                            if (it.isCancellationLike()) return@onFailure
                            toast(it.toUserMessage("新建文件夹失败"))
                        }
                }
            }
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun showRenameDialog(item: UserFileItemDto) {
        if (!isItemWritable(item)) {
            toast("当前目录为只读，不能重命名")
            return
        }
        val itemId = item.id ?: run {
            toast("对象ID无效")
            return
        }
        val input = EditText(requireContext()).apply {
            hint = "请输入新名称"
            setText(item.name.fixMojibake())
            setSelection(text?.length ?: 0)
        }
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("重命名")
            .setView(input)
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton(getString(R.string.action_save)) { _, _ ->
                val newName = input.text?.toString().orEmpty().trim()
                if (newName.isBlank()) {
                    toast("名称不能为空")
                    return@setPositiveButton
                }
                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.renameFile(itemId, newName) }
                        .onSuccess {
                            toast("重命名成功")
                            loadFiles()
                        }
                        .onFailure {
                            if (it.isCancellationLike()) return@onFailure
                            toast(it.toUserMessage("重命名失败"))
                        }
                }
            }
            .create()
        dialog.setOnShowListener { dialog.applyMetrologyDialogStyle() }
        dialog.show()
    }

    private fun confirmDeleteItem(item: UserFileItemDto) {
        if (!isItemWritable(item)) {
            toast("当前目录为只读，不能删除")
            return
        }
        val itemId = item.id ?: run {
            toast("对象ID无效")
            return
        }
        val dialog = AlertDialog.Builder(requireContext())
            .setTitle("确认删除")
            .setMessage("确定删除“${item.name.fixMojibakeOrDash()}”？")
            .setNegativeButton(getString(R.string.action_cancel), null)
            .setPositiveButton("删除") { _, _ ->
                viewLifecycleOwner.lifecycleScope.launch {
                    runCatching { AppGraph.repository.deleteFile(itemId) }
                        .onSuccess {
                            toast("删除成功")
                            loadFiles()
                        }
                        .onFailure {
                            if (it.isCancellationLike()) return@onFailure
                            toast(it.toUserMessage("删除失败"))
                        }
                }
            }
            .create()
        dialog.setOnShowListener {
            dialog.applyMetrologyDialogStyle(positiveStyle = DialogPositiveStyle.DANGER)
        }
        dialog.show()
    }

    private fun runScanSync() {
        viewLifecycleOwner.lifecycleScope.launch {
            binding.txtFileHint.showLoadingState("正在扫描同步...")
            runCatching { AppGraph.repository.scanSync(currentFolderId) }
                .onSuccess { result ->
                    val summary = "新增目录 ${result.foldersCreated ?: 0}，新增文件 ${result.filesCreated ?: 0}，删除目录 ${result.foldersDeleted ?: 0}，删除文件 ${result.filesDeleted ?: 0}"
                    toast("扫描同步完成：$summary")
                    loadFiles()
                }
                .onFailure {
                    if (it.isCancellationLike()) return@onFailure
                    val message = it.toUserMessage("扫描同步失败")
                    binding.txtFileHint.showErrorState(message)
                    toast(message)
                }
        }
    }

    private fun uploadFiles(uris: List<Uri>) {
        viewLifecycleOwner.lifecycleScope.launch {
            var successCount = 0
            var failCount = 0
            binding.txtFileHint.showLoadingState("正在上传 ${uris.size} 个文件...")
            for (uri in uris) {
                val payload = readUploadPayload(uri)
                if (payload == null) {
                    failCount += 1
                    continue
                }
                val result = runCatching {
                    AppGraph.repository.uploadFile(
                        parentId = currentFolderId,
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
            binding.txtFileHint.showReadyState(summary)
            toast(summary)
            loadFiles()
        }
    }

    private suspend fun readUploadPayload(uri: Uri): UploadPayload? = withContext(Dispatchers.IO) {
        runCatching {
            val ctx = context ?: return@runCatching null
            val resolver = ctx.contentResolver
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

    private fun toast(message: String) {
        val ctx = context ?: return
        Toast.makeText(ctx, message.fixMojibake(), Toast.LENGTH_SHORT).show()
    }

    override fun onDestroyView() {
        backPressedCallback?.remove()
        backPressedCallback = null
        _binding = null
        super.onDestroyView()
    }

    private data class UploadPayload(
        val name: String,
        val mimeType: String?,
        val bytes: ByteArray
    )
}
