package com.importservice.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "import_service_app/install_source",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallerPackageName" -> {
                    result.success(resolveInstallerPackageName())
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "import_service_app/apk_installer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    result.success(canRequestPackageInstalls())
                }
                "openUnknownAppSettings" -> {
                    try {
                        openUnknownAppSettings()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS", e.message, null)
                    }
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("ARG", "path required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        installApk(path)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openUnknownAppSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val uri = Uri.parse("package:$packageName")
            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, uri)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } else {
            val intent = Intent(Settings.ACTION_SECURITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("APK not found: $path")
        }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.apkprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun resolveInstallerPackageName(): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val info = packageManager.getInstallSourceInfo(packageName)
                info.installingPackageName
                    ?: info.initiatingPackageName
                    ?: @Suppress("DEPRECATION")
                    packageManager.getInstallerPackageName(packageName)
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(packageName)
            }
        } catch (_: Exception) {
            try {
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(packageName)
            } catch (_: Exception) {
                null
            }
        }
    }
}
