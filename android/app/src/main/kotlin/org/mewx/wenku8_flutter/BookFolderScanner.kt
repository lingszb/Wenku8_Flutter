package org.mewx.wenku8_flutter

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import org.json.JSONObject
import java.io.File
import java.util.Locale
import java.util.UUID

/** Read-only discovery. Only successfully imported selections are acknowledged. */
internal class BookFolderScanner(private val context: Context) {
    private val preferences = context.getSharedPreferences("book_scan_folders", 0)
    private val resolver = context.contentResolver
    private data class Entry(val uri: Uri, val name: String, val size: Long?, val modified: Long,
        val folder: String, val grant: Uri?) {
        val fingerprint get() = "$size:$modified"
    }
    private val entries = linkedMapOf<String, Entry>()
    private val prepared = mutableSetOf<String>()
    private val supported = setOf("txt", "epub")
    private val tree get() = preferences.getString("tree", null)?.let(Uri::parse)
    private val all get() = preferences.getBoolean("all", false)
    private fun save(edit: android.content.SharedPreferences.Editor) {
        check(edit.commit()) { "扫描设置未保存，请重试" }
    }
    fun canReadAll() = if (Build.VERSION.SDK_INT >= 30) Environment.isExternalStorageManager()
        else context.checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED

    fun info(): Map<String, Any>? {
        val uri = tree
        if (!all && uri == null) return null
        val readable = if (all) canReadAll() else try {
            resolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission } &&
                resolver.query(DocumentsContract.buildDocumentUriUsingTree(uri!!,
                    DocumentsContract.getTreeDocumentId(uri)), arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
                    null, null, null)?.use { it.moveToFirst() } == true
        } catch (_: Exception) { false }
        return mapOf("name" to if (all) "共享存储" else preferences.getString("name", "所选文件夹")!!,
            "automatic" to preferences.getBoolean("automatic", false), "readable" to readable, "all" to all)
    }
    fun formats(): Set<String> = preferences.getStringSet("formats", supported)!!.intersect(supported)
    fun setFormats(extensions: List<String>) {
        val values = extensions.map { it.lowercase(Locale.ROOT) }.toSet()
        require(values.isNotEmpty() && supported.containsAll(values)) { "请选择 TXT 或 EPUB 扫描格式" }
        save(preferences.edit().putStringSet("formats", values)); finish()
    }
    fun setAutomatic(value: Boolean) = save(preferences.edit().putBoolean("automatic", value))

    fun select(uri: Uri, flags: Int): Map<String, Any> {
        require(uri.scheme == "content" && DocumentsContract.isTreeUri(uri) &&
            flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0 &&
            flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0) { "文件提供方未授予长期目录读取权限，请重新选择" }
        resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
            val document = DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
            val name = resolver.query(document, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
                check(it.moveToFirst()) { "无法读取所选文件夹" }; it.getString(0)
            } ?: error("无法读取所选文件夹")
            val old = tree
            save(preferences.edit().putString("tree", uri.toString()).putString("name", name).putBoolean("all", false))
            finish()
            if (old != uri) release(old)
            return info()!!
        } catch (failure: Exception) {
            if (tree != uri) release(uri)
            throw failure
        }
    }
    fun selectAll(): Map<String, Any> {
        check(canReadAll()) { "请先授予共享存储读取权限" }
        val old = tree
        save(preferences.edit().remove("tree").remove("name").putBoolean("all", true))
        finish(); release(old)
        return info()!!
    }
    private fun release(uri: Uri?) {
        if (uri == null || BookTextLinks(context).usesGrant(uri)) return
        try { resolver.releasePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
        catch (_: SecurityException) { /* Already revoked. */ }
    }
    fun disconnect() {
        val old = tree
        save(preferences.edit().remove("tree").remove("name").remove("all").putBoolean("automatic", false))
        finish(); release(old)
    }

    fun scan(): Map<String, Any> {
        finish()
        check(info()?.get("readable") == true) { "扫描位置不可读取，请重新选择文件夹或授予共享存储权限" }
        val previous = JSONObject(preferences.getString("imported", "{}")!!)
        val warnings = linkedSetOf<String>()
        val extensions = formats()
        var visited = 0
        var total = 0
        var unchanged = 0
        fun accept(entry: Entry) {
            if (entry.name.substringAfterLast('.', "").lowercase(Locale.ROOT) !in extensions) return
            total++
            if (entry.size != null && (entry.size <= 0 || entry.size > BookArchiveImport.limit(entry.name))) {
                warnings.add("部分书籍为空或超过导入大小限制，已跳过"); return
            }
            if (entry.modified > 0 && entry.size != null && previous.optString(entry.uri.toString()) == entry.fingerprint) {
                unchanged++; return
            }
            entries[UUID.randomUUID().toString()] = entry
        }
        // Bound directories and unsupported files too, preventing provider cycles / huge trees.
        val maxEntries = 50_000
        if (all) {
            val root = Environment.getExternalStorageDirectory().canonicalFile
            val pending = java.util.ArrayDeque<Pair<File, Int>>()
            pending.add(root to 0)
            while (pending.isNotEmpty() && visited < maxEntries) {
                val (directory, depth) = pending.removeFirst()
                if (depth > 32) { warnings.add("部分目录层级过深，已跳过"); continue }
                val children = directory.listFiles()
                if (children == null) { warnings.add("部分目录无法读取，已跳过"); continue }
                for (file in children) {
                    if (++visited > maxEntries) break
                    if (file.name.startsWith('.') || file == File(root, "Android")) continue
                    try {
                        val canonical = file.canonicalFile
                        if (canonical != file.absoluteFile || !canonical.path.startsWith(root.path + File.separator)) continue
                        if (file.isDirectory) pending.add(file to depth + 1)
                        else if (file.isFile && file.canRead()) accept(Entry(Uri.fromFile(file), file.name,
                            file.length(), file.lastModified(), file.parentFile!!.relativeTo(root).path, null))
                    } catch (_: Exception) { warnings.add("部分文件无法读取，已跳过") }
                }
            }
        } else {
            val grant = tree!!
            data class Folder(val id: String, val path: String, val depth: Int)
            val pending = java.util.ArrayDeque<Folder>()
            val seen = mutableSetOf<String>()
            pending.add(Folder(DocumentsContract.getTreeDocumentId(grant), "", 0))
            val columns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            while (pending.isNotEmpty() && visited < maxEntries) {
                val folder = pending.removeFirst()
                if (!seen.add(folder.id)) continue
                if (folder.depth > 32) { warnings.add("部分目录层级过深，已跳过"); continue }
                try {
                    val children = DocumentsContract.buildChildDocumentsUriUsingTree(grant, folder.id)
                    val cursor = resolver.query(children, columns, null, null, null) ?: error("目录不可读取")
                    cursor.use {
                        while (visited < maxEntries && it.moveToNext()) {
                            visited++
                            val id = it.getString(0) ?: continue
                            val name = it.getString(1) ?: continue
                            if (name.startsWith('.')) continue
                            if (it.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                                pending.add(Folder(id, if (folder.path.isEmpty()) name else "${folder.path}/$name", folder.depth + 1))
                            } else accept(Entry(DocumentsContract.buildDocumentUriUsingTree(grant, id), name,
                                if (it.isNull(3)) null else it.getLong(3), if (it.isNull(4)) 0 else it.getLong(4), folder.path, grant))
                        }
                    }
                } catch (_: Exception) { warnings.add("部分目录无法读取或授权已失效，请检查扫描位置") }
            }
        }
        if (visited >= maxEntries) warnings.add("扫描达到 50000 项上限，请选择更小的文件夹继续")
        return mapOf("books" to entries.map { (token, entry) ->
            mutableMapOf<String, Any>("token" to token, "name" to entry.name, "folder" to entry.folder).apply {
                entry.size?.let { put("size", it) }
            }
        }.sortedBy { it["name"].toString().lowercase(Locale.ROOT) }, "total" to total,
            "unchanged" to unchanged, "warnings" to warnings.toList())
    }

    private fun current(token: String): Entry {
        val entry = entries[token] ?: error("扫描结果已结束，请重新扫描")
        check(info()?.get("readable") == true) { "扫描授权已失效，请重新选择扫描位置" }
        val metadata = if (entry.uri.scheme == "file") {
            val file = File(entry.uri.path!!)
            val root = Environment.getExternalStorageDirectory().canonicalFile
            check(file.canonicalFile == file.absoluteFile && file.canonicalPath.startsWith(root.path + File.separator) && file.isFile) {
                "原文件位置已变化，请重新扫描"
            }
            file.length() to file.lastModified()
        } else resolver.query(entry.uri, arrayOf(DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED), null, null, null)?.use {
            check(it.moveToFirst()) { "原文件已移除，请重新扫描" }
            (if (it.isNull(0)) null else it.getLong(0)) to (if (it.isNull(1)) 0L else it.getLong(1))
        } ?: error("无法读取原文件，请重新扫描")
        check(metadata.first == entry.size && metadata.second == entry.modified) { "原文件已变化，请重新扫描" }
        return entry
    }
    fun stage(token: String, root: File, copy: (Uri, File, Long) -> Unit): Map<String, Any> {
        val entry = current(token)
        check(root.isDirectory || root.mkdirs()) { "无法创建导入目录" }
        val target = File.createTempFile("import-", ".source", root)
        try {
            copy(entry.uri, target, BookArchiveImport.limit(entry.name))
            current(token)
            prepared.add(token)
            return mapOf("name" to entry.name, "path" to target.path)
        } catch (failure: Exception) { target.delete(); throw failure }
    }
    fun link(token: String, links: BookTextLinks): Map<String, Any> {
        val entry = current(token)
        val reference = links.remember(entry.uri, entry.grant)
        prepared.add(token)
        return mapOf("name" to entry.name, "reference" to reference)
    }
    fun markImported(token: String) {
        check(token in prepared) { "书籍尚未读取，不能标记为已导入" }
        val entry = current(token)
        val imported = JSONObject(preferences.getString("imported", "{}")!!)
        // Unknown metadata is never used to suppress future discovery.
        if (entry.size != null && entry.modified > 0) imported.put(entry.uri.toString(), entry.fingerprint)
        while (imported.length() > 20_000) imported.remove(imported.keys().next())
        save(preferences.edit().putString("imported", imported.toString()))
    }
    fun finish() { entries.clear(); prepared.clear() }
}
