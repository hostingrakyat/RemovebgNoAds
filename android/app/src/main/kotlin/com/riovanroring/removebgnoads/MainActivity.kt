package com.riovanroring.removebgnoads

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "removebgnoads/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveImage" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name")
                            ?: "removebg_${System.currentTimeMillis()}"
                        val isPng = call.argument<Boolean>("isPng") ?: true
                        if (bytes == null) {
                            result.error("NO_BYTES", "No image bytes provided", null)
                            return@setMethodCallHandler
                        }
                        try {
                            saveImage(bytes, name, isPng)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveImage(bytes: ByteArray, name: String, isPng: Boolean) {
        val mime = if (isPng) "image/png" else "image/jpeg"
        val ext = if (isPng) "png" else "jpg"
        val fileName = "$name.$ext"
        val resolver = applicationContext.contentResolver

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, mime)
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/RemovebgNoAds")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("Failed to create gallery entry")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw Exception("Failed to open output stream")
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } else {
            // API 24–28: write to public Pictures (needs WRITE_EXTERNAL_STORAGE)
            val picturesDir =
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val appDir = File(picturesDir, "RemovebgNoAds")
            if (!appDir.exists()) appDir.mkdirs()
            val file = File(appDir, fileName)
            FileOutputStream(file).use { it.write(bytes) }
            MediaScannerConnection.scanFile(
                applicationContext, arrayOf(file.absolutePath), arrayOf(mime), null
            )
        }
    }
}
