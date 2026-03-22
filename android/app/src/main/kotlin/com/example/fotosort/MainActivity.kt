package com.example.fotosort

import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.fotosort/files"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "getRootPath" -> {
                        val root = Environment.getExternalStorageDirectory()?.absolutePath
                            ?: "/storage/emulated/0"
                        result.success(root)
                    }

                    "listDirs" -> {
                        val path = call.argument<String>("path")
                        val dir = if (path == null)
                            Environment.getExternalStorageDirectory()
                        else
                            File(path)

                        if (dir == null || !dir.exists()) {
                            result.success(emptyList<Map<String, String>>())
                            return@setMethodCallHandler
                        }

                        val dirs = dir.listFiles()
                            ?.filter { it.isDirectory && !it.name.startsWith(".") }
                            ?.sortedBy { it.name.lowercase() }
                            ?.map { mapOf("name" to it.name, "path" to it.absolutePath) }
                            ?: emptyList()

                        result.success(dirs)
                    }

                    "scanFolder" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.success(emptyList<String>())
                            return@setMethodCallHandler
                        }
                        val dir = File(path)
                        if (!dir.exists() || !dir.isDirectory) {
                            result.success(emptyList<String>())
                            return@setMethodCallHandler
                        }
                        val images = dir.listFiles()
                            ?.filter { f ->
                                f.isFile && f.name.lowercase().let {
                                    it.endsWith(".jpg") || it.endsWith(".jpeg") ||
                                    it.endsWith(".png") || it.endsWith(".webp")
                                }
                            }
                            ?.map { it.absolutePath }
                            ?.sorted()
                            ?: emptyList()
                        result.success(images)
                    }

                    "moveFile" -> {
                        val src     = call.argument<String>("src")
                        val destDir = call.argument<String>("destDir")
                        if (src == null || destDir == null) {
                            result.error("NULL_ARGS", "src or destDir is null", null)
                            return@setMethodCallHandler
                        }
                        thread {
                            try {
                                val srcFile    = File(src)
                                val destFolder = File(destDir)
                                if (!destFolder.exists()) destFolder.mkdirs()
                                val destFile = File(destFolder, srcFile.name)
                                if (!srcFile.renameTo(destFile)) {
                                    srcFile.copyTo(destFile, overwrite = true)
                                    srcFile.delete()
                                }
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("MOVE_ERROR", e.message, null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
