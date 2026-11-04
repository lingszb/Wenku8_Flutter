package org.mewx.wenku8_flutter

import android.content.Context
import java.io.File
import java.util.Locale

/** The snapshot has no document converters. Keep native TXT/EPUB imports and
 * their existing size limits; unsupported formats fail before any conversion. */
internal class BookArchiveImport(private val root: File) {
    var documents: BookMarkupImport? = null

    fun prepare(name: String, source: File): List<Map<String, Any>> {
        require(supported(name)) { "当前源码版本仅支持 TXT、EPUB 导入" }
        require(source.isFile && source.length() in 1..limit(name)) { "书籍为空或超过大小限制" }
        return listOf(mapOf("name" to name, "path" to source.path))
    }

    fun prepare(name: String, source: BookDocumentInput): List<Map<String, Any>> {
        require(supported(name)) { "当前源码版本仅支持 TXT、EPUB 导入" }
        require(source.length() in 1..limit(name)) { "书籍为空或超过大小限制" }
        check(root.isDirectory || root.mkdirs()) { "无法创建导入目录" }
        val output = File.createTempFile("linked-", ".${extension(name)}", root)
        try {
            source.inputStream().use { input ->
                output.outputStream().use { out ->
                    val buffer = ByteArray(65536)
                    var count = 0L
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        count += read
                        require(count <= limit(name)) { "书籍超过大小限制" }
                        out.write(buffer, 0, read)
                    }
                    require(count > 0) { "书籍为空" }
                }
            }
            return prepare(name, output)
        } catch (error: Exception) {
            output.delete()
            throw error
        }
    }

    companion object {
        const val MAX_ARCHIVE = 512L * 1024 * 1024
        private fun extension(name: String) = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
        fun supported(name: String) = extension(name) in setOf("txt", "epub")
        fun limit(name: String) = if (extension(name) == "txt") 128L * 1024 * 1024 else MAX_ARCHIVE
    }
}

internal class BookMarkupImport(root: File, readPdf: (String, File) -> String)

internal class BookPdfImport(context: Context, root: File) {
    fun read(name: String, source: File): String =
        throw UnsupportedOperationException("当前源码版本暂不支持 PDF 转换")
}
