package com.importservice.app

import android.content.Context

/**
 * Store (Play / RuStore): самоустановки APK нет — нет PackageInstaller / EXTRA_INTENT
 * (Google Play: Intent Redirection).
 */
object ApkInstallSupport {
    fun canRequestPackageInstalls(context: Context): Boolean = false

    fun installApk(context: Context, path: String) {
        throw UnsupportedOperationException(
            "APK self-install is disabled in store builds",
        )
    }
}
