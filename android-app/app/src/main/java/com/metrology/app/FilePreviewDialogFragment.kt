package com.metrology.app

import android.app.AlertDialog
import android.app.Dialog
import android.content.DialogInterface
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.drawable.ColorDrawable
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.MediaController
import android.widget.TextView
import android.widget.Toast
import androidx.fragment.app.DialogFragment
import androidx.lifecycle.lifecycleScope
import com.metrology.app.databinding.DialogFilePreviewBinding
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.ResponseBody
import retrofit2.Call
import java.io.File
import java.nio.charset.Charset
import java.util.Locale
import kotlin.math.sqrt

class FilePreviewDialogFragment : DialogFragment() {
    private val logTag = "FilePreview"
    private var _binding: DialogFilePreviewBinding? = null
    private val binding get() = _binding!!

    private var cachedFile: File? = null
    private var pdfDescriptor: ParcelFileDescriptor? = null
    private var pdfRenderer: PdfRenderer? = null
    private var imageBitmap: Bitmap? = null
    private val renderedPdfBitmaps = mutableListOf<Bitmap>()
    private var previewJob: Job? = null
    private var actionJob: Job? = null
    @Volatile
    private var activeDownloadCall: Call<ResponseBody>? = null
    @Volatile
    private var previewDownloadBody: ResponseBody? = null
    @Volatile
    private var activeActionBody: ResponseBody? = null
    @Volatile
    private var isClosingDialog: Boolean = false

    private val fileId: Long by lazy { requireArguments().getLong(ARG_FILE_ID) }
    private val fileName: String by lazy { requireArguments().getString(ARG_FILE_NAME).orEmpty() }
    private val fileMimeType: String? by lazy { requireArguments().getString(ARG_MIME_TYPE) }
    private val fileSize: Long by lazy { requireArguments().getLong(ARG_FILE_SIZE, -1L) }

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        _binding = DialogFilePreviewBinding.inflate(LayoutInflater.from(requireContext()))

        val dialog = AlertDialog.Builder(requireContext())
            .setView(binding.root)
            .create()

        dialog.setOnShowListener {
            val b = _binding ?: return@setOnShowListener
            b.txtPreviewTitle.text = fileName.fixMojibake().ifBlank { "文件预览" }
            b.buttonPreviewClose.setOnClickListener { closePreviewDialog() }

            updateActionButtons(enabled = false)
            updateDialogCancelable()

            b.buttonPreviewOpen.setOnClickListener {
                val file = cachedFile
                if (file != null) {
                    val ctx = context ?: return@setOnClickListener
                    openFileByIntent(ctx, file, fileMimeType)
                    return@setOnClickListener
                }
                downloadAndHandle(openAfterDownload = true)
            }

            b.buttonPreviewSave.setOnClickListener {
                val file = cachedFile
                if (file != null) {
                    actionJob?.cancel()
                    actionJob = lifecycleScope.launch {
                        updateActionButtons(enabled = false)
                        try {
                            val ctx = context ?: return@launch
                            runCatching {
                                copyFileToDownloadDir(ctx, fileName, file)
                            }.onSuccess { target ->
                                toast("已保存到: ${target.absolutePath}")
                            }.onFailure {
                                if (it.isCancellationLike()) return@onFailure
                                toast(it.toUserMessage("保存到本地失败"))
                            }
                        } finally {
                            updateActionButtons(enabled = true)
                            actionJob = null
                        }
                    }
                    return@setOnClickListener
                }
                downloadAndHandle(openAfterDownload = false)
            }

            loadPreview()
        }

        return dialog
    }

    override fun onStart() {
        super.onStart()
        dialog?.window?.let { window ->
            window.setLayout(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            window.decorView.setPadding(0, 0, 0, 0)
            window.setDimAmount(0f)
        }
    }

    private fun loadPreview() {
        val knownSize = fileSize.takeIf { it > 0L }
        Log.i(logTag, "loadPreview fileId=$fileId name=$fileName knownSize=$knownSize mime=$fileMimeType")
        if (knownSize != null && knownSize > MAX_INLINE_PREVIEW_BYTES) {
            Log.w(logTag, "skip inline preview by knownSize=$knownSize threshold=$MAX_INLINE_PREVIEW_BYTES")
            updateActionButtons(enabled = true)
            showUnsupported(
                "文件过大（${formatFileSize(knownSize)}），当前不支持应用内预览。可使用“外部打开”或“保存到本地”。"
            )
            updateDialogCancelable()
            return
        }

        val isLargeKnownFile = knownSize != null && knownSize > LARGE_FILE_PREVIEW_HINT_BYTES
        showLoading(if (isLargeKnownFile) "大文件加载中，请稍候..." else "正在加载预览...")
        previewJob?.cancel()
        actionJob?.cancel()
        cancelCallInBackground(activeDownloadCall)
        activeDownloadCall = null
        val appContext = context?.applicationContext ?: return
        previewJob = lifecycleScope.launch {
            try {
                if (isLargeKnownFile) {
                    Log.i(logTag, "large file preview delayed start=$LARGE_PREVIEW_START_DELAY_MS ms")
                    delay(LARGE_PREVIEW_START_DELAY_MS)
                    currentCoroutineContext().ensureActive()
                    if (_binding == null || isClosingDialog) {
                        Log.i(logTag, "skip delayed large preview because dialog is closing/destroyed")
                        return@launch
                    }
                }
                val result = downloadPreviewToCacheWithRetry(appContext)
                if (result.responseSize != null && result.responseSize > LARGE_FILE_PREVIEW_HINT_BYTES) {
                    showLoading("大文件下载完成，正在生成预览...")
                }
                val file = result.file
                Log.i(logTag, "download saved path=${file.absolutePath} size=${file.length()}")
                if (_binding == null) return@launch
                cachedFile = file
                updateActionButtons(enabled = true)
                runCatching { renderPreview(file) }
                    .onFailure { throwable ->
                        Log.e(logTag, "renderPreview failed", throwable)
                        if (throwable.isCancellationLike()) return@onFailure
                        showUnsupported("加载预览失败：${throwable.toUserMessage("文件读取失败")}")
                    }
            } catch (tooLarge: PreviewTooLargeException) {
                updateActionButtons(enabled = true)
                showUnsupported(
                    "文件过大（${formatFileSize(tooLarge.fileSizeBytes)}），当前不支持应用内预览。可使用“外部打开”或“保存到本地”。"
                )
            } catch (throwable: Throwable) {
                Log.e(logTag, "loadPreview failed", throwable)
                if (throwable.isCancellationLike()) return@launch
                showUnsupported("加载预览失败：${throwable.toUserMessage("文件读取失败")}")
            } finally {
                activeDownloadCall = null
                previewDownloadBody = null
                updateDialogCancelable()
            }
        }
        updateDialogCancelable()
    }

    private fun closePreviewDialog() {
        if (isClosingDialog) return
        isClosingDialog = true
        // Do not wait for network coroutine completion here, otherwise users feel
        // a long "close" freeze on large files. Cancel in background and dismiss immediately.
        cancelPreviewWork()
        if (isAdded) {
            dismissAllowingStateLoss()
        }
    }

    private fun cancelPreviewWork() {
        previewJob?.cancel(CancellationException("preview dismissed"))
        previewJob = null
        actionJob?.cancel(CancellationException("preview dismissed"))
        actionJob = null
        val call = activeDownloadCall
        activeDownloadCall = null
        cancelCallInBackground(call)
        activeActionBody = null
        previewDownloadBody = null
        updateDialogCancelable()
    }

    private suspend fun renderPreview(file: File) {
        val previewType = detectPreviewType(file.name, fileMimeType)
        Log.i(logTag, "renderPreview type=$previewType fileSize=${file.length()} name=${file.name}")
        when (previewType) {
            PreviewType.IMAGE -> showImage(file)
            PreviewType.TEXT -> showText(file)
            PreviewType.PDF -> showPdf(file)
            PreviewType.MEDIA -> showMedia(file)
            PreviewType.UNSUPPORTED -> showUnsupported("当前格式暂不支持应用内预览，请使用“外部打开”或“保存到本地”。")
        }
    }

    private fun showLoading(message: String) {
        val b = _binding ?: return
        resetContentVisibility(b)
        b.progressPreview.visibility = View.VISIBLE
        b.txtPreviewStatus.visibility = View.VISIBLE
        b.txtPreviewStatus.text = message
    }

    private fun showUnsupported(message: String) {
        val b = _binding ?: return
        resetContentVisibility(b)
        b.progressPreview.visibility = View.GONE
        b.txtPreviewStatus.visibility = View.VISIBLE
        b.txtPreviewStatus.text = "预览不可用"
        b.txtPreviewUnsupported.visibility = View.VISIBLE
        b.txtPreviewUnsupported.text = message
    }

    private fun resetContentVisibility(b: DialogFilePreviewBinding) {
        b.imagePreview.visibility = View.GONE
        b.layoutPdfPages.visibility = View.GONE
        b.layoutPdfPages.removeAllViews()
        b.videoPreview.visibility = View.GONE
        b.txtPreviewContent.visibility = View.GONE
        b.txtPreviewUnsupported.visibility = View.GONE
        b.imagePreview.setImageDrawable(null)
        releaseImageBitmap()
        clearRenderedPdfBitmaps()
    }

    private suspend fun showImage(file: File) {
        val b = _binding ?: return
        resetContentVisibility(b)
        b.progressPreview.visibility = View.GONE
        b.txtPreviewStatus.visibility = View.VISIBLE
        b.txtPreviewStatus.text = "图片预览（上下滑动查看）"
        b.imagePreview.visibility = View.VISIBLE

        val targetWidth = (resources.displayMetrics.widthPixels - dp(32)).coerceAtLeast(dp(240))
        val targetHeight = (resources.displayMetrics.heightPixels - dp(220)).coerceAtLeast(dp(240))
        val bitmap = runCatching {
            withContext(Dispatchers.IO) {
                decodeSampledImage(file, targetWidth, targetHeight)
            }
        }.getOrElse {
            if (it is CancellationException) return
            showUnsupported("图片预览失败：${it.toUserMessage("解析失败")}")
            return
        }

        if (bitmap == null) {
            showUnsupported("图片预览失败：文件无法解析")
            return
        }
        currentCoroutineContext().ensureActive()
        val latest = _binding
        if (latest == null) {
            if (!bitmap.isRecycled) {
                bitmap.recycle()
            }
            return
        }
        imageBitmap = bitmap
        latest.imagePreview.setImageBitmap(bitmap)
    }

    private suspend fun showText(file: File) {
        val b = _binding ?: return
        resetContentVisibility(b)
        b.progressPreview.visibility = View.GONE
        b.txtPreviewStatus.visibility = View.VISIBLE
        b.txtPreviewStatus.text = "文本预览（上下滑动查看）"

        val content = withContext(Dispatchers.IO) {
            runCatching { file.readText(Charsets.UTF_8) }.getOrElse {
                runCatching { file.readText(Charset.forName("GBK")) }.getOrElse { "<文件内容读取失败>" }
            }
        }

        val limited = if (content.length > MAX_TEXT_LENGTH) {
            content.take(MAX_TEXT_LENGTH) + "\n\n...（内容较长，仅显示前 ${MAX_TEXT_LENGTH} 字符）"
        } else {
            content
        }
        val latest = _binding ?: return
        latest.txtPreviewContent.visibility = View.VISIBLE
        latest.txtPreviewContent.text = limited
    }

    private fun showMedia(file: File) {
        val b = _binding ?: return
        resetContentVisibility(b)
        b.progressPreview.visibility = View.GONE
        b.txtPreviewStatus.visibility = View.VISIBLE
        b.txtPreviewStatus.text = "媒体预览（上下滑动可返回）"
        b.videoPreview.visibility = View.VISIBLE

        val ctx = context ?: return
        val mediaController = MediaController(ctx)
        mediaController.setAnchorView(b.videoPreview)
        b.videoPreview.setMediaController(mediaController)
        b.videoPreview.setVideoPath(file.absolutePath)
        b.videoPreview.setOnPreparedListener { player ->
            player.isLooping = false
            b.videoPreview.start()
        }
    }

    private suspend fun showPdf(file: File) {
        Log.i(logTag, "showPdf start path=${file.absolutePath} size=${file.length()}")
        val renderer = runCatching {
            pdfDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            PdfRenderer(pdfDescriptor!!)
        }.getOrElse {
            Log.e(logTag, "showPdf create renderer failed", it)
            if (it is CancellationException) return
            showUnsupported("PDF 预览失败：${it.toUserMessage("解析失败")}")
            return
        }
        pdfRenderer = renderer

        val b = _binding ?: return
        resetContentVisibility(b)
        b.layoutPdfPages.visibility = View.VISIBLE
        b.txtPreviewStatus.visibility = View.VISIBLE
        b.progressPreview.visibility = View.VISIBLE
        val totalPages = renderer.pageCount
        if (totalPages <= 0) {
            showUnsupported("PDF 文件没有可渲染页面")
            return
        }
        val isLargePdf = file.length() > LARGE_FILE_PREVIEW_HINT_BYTES
        val pagesToRender = if (isLargePdf) {
            totalPages.coerceAtMost(MAX_PDF_PAGES_FOR_LARGE_FILE)
        } else {
            totalPages
        }
        Log.i(logTag, "showPdf totalPages=$totalPages pagesToRender=$pagesToRender large=$isLargePdf")
        val targetWidth = (resources.displayMetrics.widthPixels - dp(34)).coerceAtLeast(dp(240))
        b.txtPreviewStatus.text = if (pagesToRender < totalPages) {
            "PDF 预览（共 $totalPages 页，当前展示前 $pagesToRender 页）"
        } else {
            "PDF 预览（共 $totalPages 页，整体上下滑动）"
        }

        for (index in 0 until pagesToRender) {
            currentCoroutineContext().ensureActive()
            Log.d(logTag, "rendering pdf page=${index + 1}/$pagesToRender")
            val bitmap = withContext(Dispatchers.IO) { renderPdfBitmap(renderer, index, targetWidth) }
            currentCoroutineContext().ensureActive()
            val latest = _binding
            if (latest == null) {
                if (!bitmap.isRecycled) {
                    bitmap.recycle()
                }
                return
            }
            renderedPdfBitmaps += bitmap
            latest.layoutPdfPages.addView(
                createPdfPageBlock(
                    page = index + 1,
                    total = renderer.pageCount,
                    bitmap = bitmap,
                    ctx = latest.root.context
                )
            )
        }
        val latest = _binding ?: return
        latest.progressPreview.visibility = View.GONE
    }

    private fun renderPdfBitmap(renderer: PdfRenderer, pageIndex: Int, targetWidth: Int): Bitmap {
        return renderer.openPage(pageIndex).use { page ->
            val rawWidth = page.width.coerceAtLeast(1)
            val rawHeight = page.height.coerceAtLeast(1)
            val scale = (targetWidth.toFloat() / rawWidth.toFloat()).coerceIn(0.65f, 1.15f)
            var width = (rawWidth * scale).toInt().coerceAtLeast(1)
            var height = (rawHeight * scale).toInt().coerceAtLeast(1)

            val currentPixels = width.toLong() * height.toLong()
            if (currentPixels > MAX_BITMAP_PIXELS) {
                val ratio = sqrt(MAX_BITMAP_PIXELS.toDouble() / currentPixels.toDouble()).toFloat()
                width = (width * ratio).toInt().coerceAtLeast(1)
                height = (height * ratio).toInt().coerceAtLeast(1)
            }

            val matrix = Matrix().apply {
                postScale(
                    width.toFloat() / rawWidth.toFloat(),
                    height.toFloat() / rawHeight.toFloat()
                )
            }
            // PdfRenderer requires ARGB_8888, otherwise some devices throw
            // "Unsupported pixel format".
            Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bmp ->
                bmp.eraseColor(Color.WHITE)
                page.render(bmp, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            }
        }
    }

    private fun createPdfPageBlock(page: Int, total: Int, bitmap: Bitmap, ctx: android.content.Context): View {
        return LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(6)
            }
            setPadding(0, 0, 0, 0)

            addView(
                TextView(ctx).apply {
                    text = "第 $page / $total 页"
                    setTextColor(ctx.getColor(R.color.textSecondary))
                    textSize = 12f
                }
            )

            addView(
                ImageView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    ).apply {
                        topMargin = dp(4)
                    }
                    adjustViewBounds = true
                    scaleType = ImageView.ScaleType.FIT_CENTER
                    setImageBitmap(bitmap)
                }
            )
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private fun clearRenderedPdfBitmaps() {
        renderedPdfBitmaps.forEach { bitmap ->
            if (!bitmap.isRecycled) {
                bitmap.recycle()
            }
        }
        renderedPdfBitmaps.clear()
    }

    private fun releaseImageBitmap() {
        val bitmap = imageBitmap ?: return
        if (!bitmap.isRecycled) {
            bitmap.recycle()
        }
        imageBitmap = null
    }

    private fun decodeSampledImage(file: File, reqWidth: Int, reqHeight: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val sample = calculateInSampleSize(bounds.outWidth, bounds.outHeight, reqWidth, reqHeight)
        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.RGB_565
        }
        return BitmapFactory.decodeFile(file.absolutePath, options)
    }

    private fun calculateInSampleSize(
        width: Int,
        height: Int,
        reqWidth: Int,
        reqHeight: Int
    ): Int {
        var sampleSize = 1
        if (height <= reqHeight && width <= reqWidth) return sampleSize

        var halfHeight = height / 2
        var halfWidth = width / 2
        while (halfHeight / sampleSize >= reqHeight && halfWidth / sampleSize >= reqWidth) {
            sampleSize *= 2
        }
        return sampleSize.coerceAtLeast(1)
    }

    private fun updateActionButtons(enabled: Boolean) {
        val b = _binding ?: return
        b.buttonPreviewOpen.isEnabled = enabled
        b.buttonPreviewSave.isEnabled = enabled
        val alpha = if (enabled) 1f else 0.5f
        b.buttonPreviewOpen.alpha = alpha
        b.buttonPreviewSave.alpha = alpha
        updateDialogCancelable()
    }

    private fun downloadAndHandle(openAfterDownload: Boolean) {
        actionJob?.cancel()
        val appContext = context?.applicationContext ?: return
        actionJob = lifecycleScope.launch {
            updateActionButtons(enabled = false)
            updateDialogCancelable()
            var body: ResponseBody? = null
            try {
                val downloadedBody = AppGraph.repository.downloadFile(fileId) { call ->
                    activeDownloadCall = call
                }
                body = downloadedBody
                activeActionBody = downloadedBody
                val target = saveToDownloadDir(appContext, fileName, downloadedBody)
                if (openAfterDownload) {
                    val ctx = context ?: return@launch
                    openFileByIntent(ctx, target, fileMimeType)
                } else {
                    toast("已保存到: ${target.absolutePath}")
                }
            } catch (throwable: Throwable) {
                if (!throwable.isCancellationLike()) {
                    val message = if (openAfterDownload) "外部打开失败" else "保存到本地失败"
                    toast(throwable.toUserMessage(message))
                }
            } finally {
                activeActionBody = null
                activeDownloadCall = null
                closeResponseBodyAsync(body)
                updateActionButtons(enabled = true)
                actionJob = null
                updateDialogCancelable()
            }
        }
        updateDialogCancelable()
    }

    private fun updateDialogCancelable() {
        val canCancel = !isClosingDialog &&
            (previewJob?.isActive != true) &&
            (actionJob?.isActive != true)
        isCancelable = canCancel
        dialog?.setCanceledOnTouchOutside(canCancel)
    }

    private suspend fun downloadPreviewToCacheWithRetry(appContext: android.content.Context): PreviewDownloadResult {
        var lastError: Throwable? = null
        for (attempt in 1..MAX_PREVIEW_DOWNLOAD_ATTEMPTS) {
            currentCoroutineContext().ensureActive()
            var body: ResponseBody? = null
            try {
                val downloadedBody = AppGraph.repository.downloadFile(fileId) { call ->
                    activeDownloadCall = call
                }
                body = downloadedBody
                val responseSize = downloadedBody.contentLength().takeIf { it > 0L }
                Log.i(logTag, "download response received contentLength=$responseSize attempt=$attempt")
                if (responseSize != null && responseSize > MAX_INLINE_PREVIEW_BYTES) {
                    Log.w(logTag, "skip inline preview by responseSize=$responseSize threshold=$MAX_INLINE_PREVIEW_BYTES")
                    throw PreviewTooLargeException(responseSize)
                }
                previewDownloadBody = downloadedBody
                val file = saveToCacheDir(appContext, fileName, downloadedBody)
                return PreviewDownloadResult(file = file, responseSize = responseSize)
            } catch (throwable: Throwable) {
                lastError = throwable
                val shouldRetry =
                    attempt < MAX_PREVIEW_DOWNLOAD_ATTEMPTS &&
                        !isClosingDialog &&
                        currentCoroutineContext().isActive &&
                        shouldRetryPreviewDownload(throwable)
                Log.w(logTag, "download preview attempt=$attempt failed retry=$shouldRetry", throwable)
                if (!shouldRetry) {
                    throw throwable
                }
                showLoading("网络波动，正在重试预览（$attempt/$MAX_PREVIEW_DOWNLOAD_ATTEMPTS）...")
                delay(PREVIEW_DOWNLOAD_RETRY_DELAY_MS)
            } finally {
                activeDownloadCall = null
                if (previewDownloadBody === body) {
                    previewDownloadBody = null
                }
                closeResponseBodyAsync(body)
            }
        }
        throw lastError ?: IllegalStateException("预览下载失败")
    }

    private fun shouldRetryPreviewDownload(throwable: Throwable): Boolean {
        if (throwable is CancellationException) return false
        if (throwable is PreviewTooLargeException) return false
        val raw = throwable.message?.lowercase(Locale.getDefault()).orEmpty()
        return raw.contains("stream was reset: cancel") ||
            raw.contains("stream was reset") ||
            raw.contains("connection reset") ||
            raw.contains("unexpected end of stream") ||
            raw.contains("stream closed")
    }

    private fun formatFileSize(bytes: Long): String {
        if (bytes <= 0L) return "0 B"
        val kb = 1024.0
        val mb = kb * 1024.0
        val gb = mb * 1024.0
        return when {
            bytes < kb -> "$bytes B"
            bytes < mb -> String.format(Locale.getDefault(), "%.1f KB", bytes / kb)
            bytes < gb -> String.format(Locale.getDefault(), "%.1f MB", bytes / mb)
            else -> String.format(Locale.getDefault(), "%.2f GB", bytes / gb)
        }
    }

    private suspend fun closeResponseBodyAsync(body: ResponseBody?) {
        if (body == null) return
        withContext(Dispatchers.IO) {
            runCatching { body.close() }
        }
    }

    private fun cancelCallInBackground(call: Call<ResponseBody>?) {
        if (call == null) return
        previewIoScope.launch {
            runCatching { call.cancel() }
        }
    }

    override fun onDismiss(dialog: DialogInterface) {
        cancelPreviewWork()
        super.onDismiss(dialog)
    }

    override fun onCancel(dialog: DialogInterface) {
        cancelPreviewWork()
        super.onCancel(dialog)
    }

    override fun onDestroyView() {
        cancelPreviewWork()
        runCatching { _binding?.videoPreview?.stopPlayback() }
        releaseImageBitmap()
        clearRenderedPdfBitmaps()
        runCatching { pdfRenderer?.close() }
        runCatching { pdfDescriptor?.close() }
        cachedFile = null
        pdfRenderer = null
        pdfDescriptor = null
        _binding = null
        super.onDestroyView()
    }

    private fun detectPreviewType(name: String, mimeType: String?): PreviewType {
        val ext = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
        val mime = mimeType.orEmpty().lowercase(Locale.ROOT)

        if (mime.startsWith("image/") || ext in imageExt) return PreviewType.IMAGE
        if (mime == "application/pdf" || ext == "pdf") return PreviewType.PDF
        if (mime.startsWith("text/") || ext in textExt) return PreviewType.TEXT
        if (mime.startsWith("video/") || mime.startsWith("audio/") || ext in mediaExt) return PreviewType.MEDIA
        return PreviewType.UNSUPPORTED
    }

    private fun toast(message: String) {
        val ctx = context ?: return
        Toast.makeText(ctx, message.fixMojibake(), Toast.LENGTH_SHORT).show()
    }

    companion object {
        private const val ARG_FILE_ID = "arg_file_id"
        private const val ARG_FILE_NAME = "arg_file_name"
        private const val ARG_MIME_TYPE = "arg_mime_type"
        private const val ARG_FILE_SIZE = "arg_file_size"
        private const val MAX_TEXT_LENGTH = 200_000
        private const val MAX_BITMAP_PIXELS = 700_000L
        private const val LARGE_FILE_PREVIEW_HINT_BYTES = 20L * 1024L * 1024L
        private const val MAX_INLINE_PREVIEW_BYTES = 200L * 1024L * 1024L
        private const val MAX_PDF_PAGES_FOR_LARGE_FILE = 24
        private const val MAX_PREVIEW_DOWNLOAD_ATTEMPTS = 3
        private const val PREVIEW_DOWNLOAD_RETRY_DELAY_MS = 450L
        private const val LARGE_PREVIEW_START_DELAY_MS = 1800L
        private val previewIoScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

        private val imageExt = setOf("jpg", "jpeg", "png", "gif", "webp", "bmp")
        private val textExt = setOf(
            "txt", "log", "csv", "json", "xml", "yaml", "yml", "md",
            "java", "kt", "kts", "js", "ts", "css", "html", "htm", "py", "sql"
        )
        private val mediaExt =
            setOf("mp4", "m4v", "webm", "3gp", "mov", "mp3", "wav", "m4a", "aac", "ogg", "flac")

        fun newInstance(item: UserFileItemDto): FilePreviewDialogFragment {
            val id = item.id ?: 0L
            val mime = item.mimeType.fixMojibake().trim().takeIf { it.isNotBlank() }
            return FilePreviewDialogFragment().apply {
                arguments = Bundle().apply {
                    putLong(ARG_FILE_ID, id)
                    putString(ARG_FILE_NAME, item.name.fixMojibake().ifBlank { "preview.bin" })
                    putString(ARG_MIME_TYPE, mime)
                    putLong(ARG_FILE_SIZE, item.fileSize ?: -1L)
                }
            }
        }
    }

    private enum class PreviewType {
        IMAGE,
        PDF,
        TEXT,
        MEDIA,
        UNSUPPORTED
    }

    private data class PreviewDownloadResult(
        val file: File,
        val responseSize: Long?
    )

    private class PreviewTooLargeException(val fileSizeBytes: Long) : RuntimeException()
}
