package com.nlabs.smartmoney

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.nlabs.smartmoney/image_sync"
        private const val PERMISSION_REQUEST_CODE = 4201
        private const val RELATIVE_PICTURES_DIR = "Pictures/SmartMoney"
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureStoragePermission" -> handleEnsurePermission(result)
                    "listFolderImages" -> {
                        val folder = call.argument<String>("relativePath") ?: RELATIVE_PICTURES_DIR
                        Thread {
                            try {
                                val items = queryFolderImages(folder)
                                runOnUiThread { result.success(items) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("LIST_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }
                    "exportImageToPublicFolder" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val fileName = call.argument<String>("fileName")
                        val relativePath = call.argument<String>("relativePath") ?: RELATIVE_PICTURES_DIR
                        if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "sourcePath and fileName required", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val status = exportImage(sourcePath, fileName, relativePath)
                                runOnUiThread { result.success(status) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("EXPORT_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }
                    "copyPublicImageToLocal" -> {
                        val uriStr = call.argument<String>("uri") ?: ""
                        val pathStr = call.argument<String>("path") ?: ""
                        val destPath = call.argument<String>("destPath")
                        if (destPath.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "destPath required", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val copied = copyToLocal(uriStr, pathStr, destPath)
                                runOnUiThread { result.success(copied) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("COPY_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requiredPermissions(): Array<String> {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> {
                arrayOf(Manifest.permission.READ_MEDIA_IMAGES)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> {
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
            else -> {
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                )
            }
        }
    }

    private fun hasAllPermissions(perms: Array<String>): Boolean {
        return perms.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun handleEnsurePermission(result: MethodChannel.Result) {
        val perms = requiredPermissions()
        if (hasAllPermissions(perms)) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("PERMISSION_BUSY", "Permission request already in progress", null)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, perms, PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun isImageName(name: String): Boolean {
        val lower = name.lowercase()
        return lower.endsWith(".jpg") ||
            lower.endsWith(".jpeg") ||
            lower.endsWith(".png") ||
            lower.endsWith(".webp") ||
            lower.endsWith(".heic")
    }

    private fun mimeTypeFor(fileName: String): String {
        val lower = fileName.lowercase()
        return when {
            lower.endsWith(".png") -> "image/png"
            lower.endsWith(".webp") -> "image/webp"
            lower.endsWith(".heic") -> "image/heic"
            else -> "image/jpeg"
        }
    }

    private fun queryFolderImages(relativePath: String): List<Map<String, String>> {
        val byName = linkedMapOf<String, Map<String, String>>()

        // 1. MediaStore query (works cleanly with READ_MEDIA_IMAGES across apps on Android 10+)
        val projection = mutableListOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            projection.add(MediaStore.Images.Media.RELATIVE_PATH)
        } else {
            @Suppress("DEPRECATION")
            projection.add(MediaStore.Images.Media.DATA)
        }

        val selection: String
        val selectionArgs: Array<String>
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val cleanRel = relativePath.trimEnd('/')
            selection = "${MediaStore.Images.Media.RELATIVE_PATH} = ? OR ${MediaStore.Images.Media.RELATIVE_PATH} = ?"
            selectionArgs = arrayOf("$cleanRel/", cleanRel)
        } else {
            @Suppress("DEPRECATION")
            selection = "${MediaStore.Images.Media.DATA} LIKE ?"
            selectionArgs = arrayOf("%/${relativePath.trimEnd('/')}/%")
        }

        contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection.toTypedArray(),
            selection,
            selectionArgs,
            null
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val dataCol = cursor.getColumnIndex(MediaStore.Images.Media.DATA)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val name = cursor.getString(nameCol) ?: continue
                if (!isImageName(name)) continue
                val uri = ContentUris.withAppendedId(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    id
                ).toString()
                val filePath = if (dataCol >= 0) cursor.getString(dataCol) ?: "" else ""
                byName.putIfAbsent(
                    name,
                    mapOf("name" to name, "uri" to uri, "path" to filePath)
                )
            }
        }

        // 2. Direct filesystem scan fallback (catches unindexed files when accessible)
        @Suppress("DEPRECATION")
        val picturesRoot = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        val subFolderName = relativePath.removePrefix("Pictures/").trim('/')
        val dir = if (subFolderName.isEmpty()) picturesRoot else File(picturesRoot, subFolderName)
        if (dir.exists() && dir.isDirectory) {
            dir.listFiles()?.forEach { f ->
                if (f.isFile && isImageName(f.name) && !byName.containsKey(f.name)) {
                    byName[f.name] = mapOf(
                        "name" to f.name,
                        "uri" to "",
                        "path" to f.absolutePath
                    )
                }
            }
        }

        return byName.values.toList()
    }

    private fun exportImage(sourcePath: String, fileName: String, relativePath: String): String {
        val srcFile = File(sourcePath)
        if (!srcFile.exists()) return "missing"

        // Check existing files in target folder to avoid duplicates
        val existingNames = queryFolderImages(relativePath).map { it["name"] }.toSet()
        if (existingNames.contains(fileName)) {
            return "skipped"
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val cleanRel = relativePath.trimEnd('/')
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, mimeTypeFor(fileName))
                put(MediaStore.Images.Media.RELATIVE_PATH, "$cleanRel/")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }

            val uri = contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values
            ) ?: throw IllegalStateException("Gagal membuat entry MediaStore untuk $fileName")

            try {
                contentResolver.openOutputStream(uri)?.use { outStream ->
                    FileInputStream(srcFile).use { inStream ->
                        inStream.copyTo(outStream)
                    }
                } ?: throw IllegalStateException("Gagal membuka stream tulis untuk $fileName")

                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                return "exported"
            } catch (e: Exception) {
                contentResolver.delete(uri, null, null)
                throw e
            }
        } else {
            @Suppress("DEPRECATION")
            val picturesRoot = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val subFolderName = relativePath.removePrefix("Pictures/").trim('/')
            val dir = if (subFolderName.isEmpty()) picturesRoot else File(picturesRoot, subFolderName)
            if (!dir.exists()) {
                dir.mkdirs()
            }
            val targetFile = File(dir, fileName)
            if (targetFile.exists()) return "skipped"
            FileInputStream(srcFile).use { inStream ->
                FileOutputStream(targetFile).use { outStream ->
                    inStream.copyTo(outStream)
                }
            }
            MediaScannerConnection.scanFile(this, arrayOf(targetFile.absolutePath), null, null)
            return "exported"
        }
    }

    private fun copyToLocal(uriStr: String, pathStr: String, destPath: String): Boolean {
        val destFile = File(destPath)
        destFile.parentFile?.mkdirs()

        if (uriStr.isNotBlank()) {
            val uri = Uri.parse(uriStr)
            contentResolver.openInputStream(uri)?.use { inStream ->
                FileOutputStream(destFile).use { outStream ->
                    inStream.copyTo(outStream)
                }
                return true
            }
        }

        if (pathStr.isNotBlank()) {
            val srcFile = File(pathStr)
            if (srcFile.exists() && srcFile.isFile) {
                FileInputStream(srcFile).use { inStream ->
                    FileOutputStream(destFile).use { outStream ->
                        inStream.copyTo(outStream)
                    }
                }
                return true
            }
        }

        return false
    }
}
