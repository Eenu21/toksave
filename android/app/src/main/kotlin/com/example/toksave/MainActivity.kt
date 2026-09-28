package com.example.toksave

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val galleryChannel = "toksave/gallery"
    private val ioExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, galleryChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveMedia" -> {
                        val filePath = call.argument<String>("filePath")
                        val displayName = call.argument<String>("displayName")
                        val isAudio = call.argument<Boolean>("isAudio") ?: false
                        if (filePath == null || displayName == null) {
                            result.error("INVALID_ARGUMENT", "A media path and file name are required.", null)
                            return@setMethodCallHandler
                        }

                        executeGalleryOperation(result, "GALLERY_SAVE_FAILED") {
                            saveMediaToGallery(filePath, displayName, isAudio)
                        }
                    }
                    "deleteVideo" -> {
                        val contentUri = call.argument<String>("contentUri")
                        if (contentUri == null) {
                            result.error("INVALID_ARGUMENT", "A gallery URI is required.", null)
                            return@setMethodCallHandler
                        }

                        executeGalleryOperation(result, "GALLERY_DELETE_FAILED") {
                            contentResolver.delete(android.net.Uri.parse(contentUri), null, null)
                            null
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun executeGalleryOperation(
        result: MethodChannel.Result,
        errorCode: String,
        operation: () -> Any?,
    ) {
        ioExecutor.execute {
            try {
                val value = operation()
                runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                runOnUiThread { result.error(errorCode, error.message, null) }
            }
        }
    }

    private fun saveMediaToGallery(filePath: String, displayName: String, isAudio: Boolean): String {
        check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            "Saving videos to Gallery requires Android 10 or newer."
        }

        val source = File(filePath)
        check(source.isFile) { "The downloaded video file could not be found." }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, if (isAudio) "audio/mpeg" else "video/mp4")
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                if (isAudio) "${Environment.DIRECTORY_MUSIC}/TokSave"
                else "${Environment.DIRECTORY_MOVIES}/TokSave",
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = if (isAudio) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val uri = contentResolver.insert(collection, values)
            ?: error("Android could not create a Gallery entry for this video.")

        try {
            val output = contentResolver.openOutputStream(uri)
                ?: error("Android could not open the Gallery entry for writing.")
            source.inputStream().use { input ->
                output.use { input.copyTo(it) }
            }
            val publishedValues = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            check(contentResolver.update(uri, publishedValues, null, null) == 1) {
                "Android could not publish the video to Gallery."
            }
            return uri.toString()
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }
}
