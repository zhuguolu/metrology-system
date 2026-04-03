package com.metrology.app

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.metrology.app.databinding.ItemWebdavFileBinding
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class WebDavFileAdapter(
    private val onOpen: (WebDavFileDto) -> Unit
) : RecyclerView.Adapter<WebDavFileAdapter.WebDavFileViewHolder>() {
    private val items = mutableListOf<WebDavFileDto>()
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault())

    fun submitList(data: List<WebDavFileDto>) {
        items.clear()
        items.addAll(data)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): WebDavFileViewHolder {
        val binding = ItemWebdavFileBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return WebDavFileViewHolder(binding, onOpen, dateFormat)
    }

    override fun onBindViewHolder(holder: WebDavFileViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    class WebDavFileViewHolder(
        private val binding: ItemWebdavFileBinding,
        private val onOpen: (WebDavFileDto) -> Unit,
        private val dateFormat: SimpleDateFormat
    ) : RecyclerView.ViewHolder(binding.root) {
        fun bind(item: WebDavFileDto) {
            val isDirectory = item.isDirectory == true
            binding.txtWebDavIcon.text = if (isDirectory) "夹" else "网"
            binding.txtWebDavName.text = item.name.fixMojibakeOrDash()
            val time = item.modified?.let { dateFormat.format(Date(it)) }.fixMojibakeOrDash()
            val sizeText = if (isDirectory) "目录" else formatSize(item.size ?: 0L)
            binding.txtWebDavMeta.text = "$sizeText   修改: $time"
            binding.buttonOpenWebDavFile.text = if (isDirectory) "进入" else "下载"
            binding.buttonOpenWebDavFile.setOnClickListener { onOpen(item) }
            binding.root.setOnClickListener { onOpen(item) }
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
}
