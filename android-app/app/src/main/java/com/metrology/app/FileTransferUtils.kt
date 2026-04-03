package com.metrology.app

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.webkit.MimeTypeMap
import android.widget.Toast
import androidx.core.content.FileProvider
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import okhttp3.ResponseBody
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

suspend fun saveToDownloadDir(
    context: Context,
    targetName: String,
    body: ResponseBody
): File = withContext(Dispatchers.IO) {
    val downloadDir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
        ?: context.filesDir
    if (!downloadDir.exists()) {
        downloadDir.mkdirs()
    }
    val targetFile = uniqueFile(downloadDir, sanitizeFilename(targetName))
    writeResponseBodyToFile(body, targetFile)
}

suspend fun saveToCacheDir(
    context: Context,
    targetName: String,
    body: ResponseBody
): File = withContext(Dispatchers.IO) {
    val cacheDir = File(context.cacheDir, "file_preview_cache")
    if (!cacheDir.exists()) {
        cacheDir.mkdirs()
    }
    val targetFile = uniqueFile(cacheDir, sanitizeFilename(targetName))
    writeResponseBodyToFile(body, targetFile)
}

suspend fun copyFileToDownloadDir(
    context: Context,
    targetName: String,
    sourceFile: File
): File = withContext(Dispatchers.IO) {
    val downloadDir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
        ?: context.filesDir
    if (!downloadDir.exists()) {
        downloadDir.mkdirs()
    }
    val targetFile = uniqueFile(downloadDir, sanitizeFilename(targetName))
    val jobContext = currentCoroutineContext()
    try {
        sourceFile.inputStream().use { input ->
            FileOutputStream(targetFile).use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    jobContext.ensureActive()
                    val read = input.read(buffer)
                    if (read <= 0) break
                    output.write(buffer, 0, read)
                }
                output.flush()
            }
        }
        targetFile
    } catch (cancelled: CancellationException) {
        runCatching { targetFile.delete() }
        throw cancelled
    }
}

fun openFileByIntent(
    context: Context,
    file: File,
    mimeType: String? = null
) {
    val uri = FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        file
    )
    val resolvedType = mimeType?.ifBlank { null }
        ?: guessMimeType(file.name)
        ?: "application/octet-stream"

    val intent = Intent(Intent.ACTION_VIEW).apply {
        setDataAndType(uri, resolvedType)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    try {
        context.startActivity(Intent.createChooser(intent, "打开文件"))
    } catch (_: ActivityNotFoundException) {
        Toast.makeText(context, "没有可用应用打开该文件", Toast.LENGTH_SHORT).show()
    }
}
private fun sanitizeFilename(raw: String): String {
    val cleaned = raw.trim()
        .replace(Regex("[\\\\/:*?\"<>|]"), "_")
        .replace(Regex("\\s+"), " ")
    return cleaned.ifBlank { "download.bin" }
}

private fun uniqueFile(dir: File, name: String): File {
    val dot = name.lastIndexOf('.')
    val base = if (dot > 0) name.substring(0, dot) else name
    val ext = if (dot > 0) name.substring(dot) else ""
    var index = 0
    var file = File(dir, name)
    while (file.exists()) {
        index += 1
        file = File(dir, "$base-$index$ext")
    }
    return file
}

private fun guessMimeType(name: String): String? {
    val ext = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
    if (ext.isBlank()) return null
    return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
}

private suspend fun writeResponseBodyToFile(
    body: ResponseBody,
    targetFile: File
): File = withContext(Dispatchers.IO) {
    val context = currentCoroutineContext()
    try {
        body.byteStream().use { input ->
            FileOutputStream(targetFile).use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    context.ensureActive()
                    val read = input.read(buffer)
                    if (read <= 0) break
                    output.write(buffer, 0, read)
                }
                output.flush()
            }
        }
        targetFile
    } catch (cancelled: CancellationException) {
        runCatching { targetFile.delete() }
        throw cancelled
    } finally {
        runCatching { body.close() }
    }
}

