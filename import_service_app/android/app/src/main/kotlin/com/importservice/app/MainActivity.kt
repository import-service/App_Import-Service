package com.importservice.app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Общий [MainActivity] для server и store.
 *
 * Установка APK с нашего сервера (PackageInstaller / Intent) — только в
 * [ApkInstallSupport] flavor `server`. В `store` — no-op (Play / RuStore).
 */
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
                    result.success(ApkInstallSupport.canRequestPackageInstalls(this))
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
                    Thread {
                        try {
                            ApkInstallSupport.installApk(this, path)
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("INSTALL", e.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
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
