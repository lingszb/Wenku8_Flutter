package org.mewx.wenku8_flutter

import android.content.Context
import android.net.Uri
import java.io.File

/** No traversal or permission grants until the omitted scanner is implemented.
 * Manual TXT/EPUB selection remains available through BookDocuments. */
internal class BookFolderScanner(context: Context) {
    private fun unavailable(): Nothing =
        throw UnsupportedOperationException("当前源码版本暂不支持文件夹扫描，请直接选择 TXT 或 EPUB 文件")
    fun info(): Map<String, Any>? = null
    fun canReadAll() = false
    fun formats(): Set<String> = setOf("txt", "epub")
    fun setFormats(extensions: List<String>): Nothing = unavailable()
    fun setAutomatic(value: Boolean): Nothing = unavailable()
    fun select(uri: Uri, flags: Int): Nothing = unavailable()
    fun selectAll(): Nothing = unavailable()
    fun scan(): Nothing = unavailable()
    fun stage(token: String, root: File, copy: (Uri, File, Long) -> Unit): Nothing = unavailable()
    fun link(token: String, links: BookTextLinks, root: File, copy: (Uri, File, Long) -> Unit): Nothing = unavailable()
    fun markImported(token: String): Nothing = unavailable()
    fun finish() {}
    fun disconnect() {}
}
