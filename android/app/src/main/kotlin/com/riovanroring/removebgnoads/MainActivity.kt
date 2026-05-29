package com.riovanroring.removebgnoads

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.google.android.gms.common.moduleinstall.InstallStatusListener
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenter
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val galleryChannel = "removebgnoads/gallery"
    private val modelChannel = "removebgnoads/model"

    // Model install progress: -1 unknown, 0..100 percent.
    private var installProgress = -1
    private var installFailed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, galleryChannel)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, modelChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isModelAvailable" -> {
                        try {
                            val segmenter = buildSegmenter()
                            ModuleInstall.getClient(this)
                                .areModulesAvailable(segmenter)
                                .addOnSuccessListener { resp ->
                                    result.success(resp.areModulesAvailable())
                                }
                                .addOnFailureListener { result.success(false) }
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "requestInstall" -> {
                        try {
                            installProgress = 0
                            installFailed = false
                            val segmenter = buildSegmenter()
                            val client = ModuleInstall.getClient(this)
                            val listener = object : InstallStatusListener {
                                override fun onInstallStatusUpdated(
                                    update: ModuleInstallStatusUpdate
                                ) {
                                    val info = update.progressInfo
                                    if (info != null && info.totalBytesToDownload > 0) {
                                        installProgress = (100 * info.bytesDownloaded /
                                                info.totalBytesToDownload).toInt()
                                    }
                                    when (update.installState) {
                                        ModuleInstallStatusUpdate.InstallState.STATE_COMPLETED -> {
                                            installProgress = 100
                                            client.unregisterListener(this)
                                        }
                                        ModuleInstallStatusUpdate.InstallState.STATE_FAILED -> {
                                            installFailed = true
                                            client.unregisterListener(this)
                                        }
                                    }
                                }
                            }
                            val request = ModuleInstallRequest.newBuilder()
                                .addApi(segmenter)
                                .setListener(listener)
                                .build()
                            client.installModules(request)
                                .addOnSuccessListener { installProgress = 100 }
                                .addOnFailureListener { installFailed = true }
                            result.success(true)
                        } catch (e: Exception) {
                            installFailed = true
                            result.error("INSTALL_ERR", e.message, null)
                        }
                    }
                    "installProgress" -> result.success(installProgress)
                    "installFailed" -> result.success(installFailed)
                    else -> result.notImplemented()
                }
            }
    }

    private fun buildSegmenter(): SubjectSegmenter {
        val options = SubjectSegmenterOptions.Builder()
            .enableForegroundConfidenceMask()
            .build()
        return SubjectSegmentation.getClient(options)
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
