package com.metrology.app

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.metrology.app.databinding.ItemFileBinding
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class FileAdapter(
    private val onOpen: (UserFileItemDto) -> Unit,
    private val onMore: ((UserFileItemDto) -> Unit)? = null
) : RecyclerView.Adapter<FileAdapter.FileViewHolder>() {
    private val items = mutableListOf<UserFileItemDto>()
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault())

    fun submitList(data: List<UserFileItemDto>) {
        items.clear()
        items.addAll(data)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): FileViewHolder {
        val binding = ItemFileBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return FileViewHolder(binding, onOpen, onMore, dateFormat)
    }

    override fun onBindViewHolder(holder: FileViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    class FileViewHolder(
        private val binding: ItemFileBinding,
        private val onOpen: (UserFileItemDto) -> Unit,
        private val onMore: ((UserFileItemDto) -> Unit)?,
        private val dateFormat: SimpleDateFormat
    ) : RecyclerView.ViewHolder(binding.root) {
        fun bind(item: UserFileItemDto) {
            val isFolder = item.type.equals("FOLDER", true)
            val visual = resolveVisual(item, isFolder)

            binding.imgFileIcon.setImageResource(visual.iconRes)
            binding.txtFileType.text = visual.typeLabel
            binding.txtFileName.text = item.name.fixMojibakeOrDash()

            val sizeText = if (isFolder) "文件夹" else formatSize(item.fileSize ?: 0L)
            val createText = item.createdAt?.let {
                runCatching { dateFormat.format(Date.from(java.time.Instant.parse(it))) }.getOrNull()
            }.fixMojibakeOrDash()
            binding.txtFileMeta.text = "$sizeText   创建: $createText"

            binding.buttonOpenFile.text = if (isFolder) "进入" else "预览"
            binding.buttonOpenFile.setOnClickListener { onOpen(item) }
            binding.root.setOnClickListener { onOpen(item) }
            binding.root.setOnLongClickListener {
                onMore?.invoke(item)
                onMore != null
            }
        }

        private fun resolveVisual(item: UserFileItemDto, isFolder: Boolean): FileVisual {
            if (isFolder) {
                return FileVisual(R.drawable.ic_file_folder, "文件夹")
            }

            val ext = item.name
                .fixMojibake()
                .substringAfterLast('.', "")
                .lowercase(Locale.ROOT)
            val mime = item.mimeType.fixMojibake().lowercase(Locale.ROOT)

            return when {
                ext == "pdf" || mime == "application/pdf" -> FileVisual(R.drawable.ic_file_pdf, "PDF")
                ext in setOf("jpg", "jpeg", "png", "gif", "bmp", "webp", "svg") || mime.startsWith("image/") ->
                    FileVisual(R.drawable.ic_file_image, "图片")

                ext in setOf("doc", "docx", "rtf") -> FileVisual(R.drawable.ic_file_word, "Word")
                ext in setOf("xls", "xlsx", "csv") -> FileVisual(R.drawable.ic_file_excel, "表格")
                ext in setOf("ppt", "pptx") -> FileVisual(R.drawable.ic_file_ppt, "演示")
                ext in setOf("zip", "rar", "7z", "tar", "gz", "bz2") ->
                    FileVisual(R.drawable.ic_file_zip, "压缩")

                ext in setOf("mp4", "mov", "avi", "mkv", "webm", "3gp") || mime.startsWith("video/") ->
                    FileVisual(R.drawable.ic_file_video, "视频")

                ext in setOf("mp3", "wav", "flac", "aac", "m4a", "ogg") || mime.startsWith("audio/") ->
                    FileVisual(R.drawable.ic_file_audio, "音频")

                ext in setOf("txt", "md", "log", "json", "xml", "yaml", "yml", "ini", "conf", "sql", "kt", "java", "js", "ts", "css", "html") || mime.startsWith("text/") ->
                    FileVisual(R.drawable.ic_file_text, "文本")

                else -> FileVisual(R.drawable.ic_file_generic, "文件")
            }
        }

        private fun formatSize(size: Long): String {
            if (size <= 0) return "0 B"
            val kb = 1024.0
            val mb = kb * 1024.0
            val gb = mb * 1024.0
            return when {
                size < kb -> "${size} B"
                size < mb -> String.format(Locale.getDefault(), "%.1f KB", size / kb)
                size < gb -> String.format(Locale.getDefault(), "%.1f MB", size / mb)
                else -> String.format(Locale.getDefault(), "%.2f GB", size / gb)
            }
        }
    }

    private data class FileVisual(
        val iconRes: Int,
        val typeLabel: String
    )
}
