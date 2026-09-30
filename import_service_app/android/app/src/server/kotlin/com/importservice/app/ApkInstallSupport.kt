package com.importservice.app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.os.Build
import java.io.File

/**
 * Server-flavor: установка APK с нашего API через PackageInstaller.
 * Не попадает в store AAB (отдельный source set) — иначе Play: Intent Redirection.
 */
object ApkInstallSupport {
    @Volatile
    private var receiverRegistered = false

    private val installStatusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val status = intent.getIntExtra(
                PackageInstaller.EXTRA_STATUS,
                PackageInstaller.STATUS_FAILURE,
            )
            if (status != PackageInstaller.STATUS_PENDING_USER_ACTION) return
            val confirm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_INTENT)
            } ?: return
            // Только системный диалог подтверждения установки нашего пакета.
            if (confirm.`package` != null && confirm.`package` != context.packageName) {
                return
            }
            confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(confirm)
        }
    }

    fun canRequestPackageInstalls(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    fun installApk(context: Context, path: String) {
        val file = File(path)
        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("APK not found: $path")
        }
        ensureInstallReceiver(context)
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        )
        params.setSize(file.length())
        params.setAppPackageName(context.packageName)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED)
        }
        val sessionId = installer.createSession(params)
        val session = installer.openSession(sessionId)
        try {
            file.inputStream().use { input ->
                session.openWrite("base.apk", 0, file.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }
            val callback = Intent("${context.packageName}.INSTALL_APK_STATUS")
                .setPackage(context.packageName)
            val pendingFlags =
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            val pending = PendingIntent.getBroadcast(
                context,
                sessionId,
                callback,
                pendingFlags,
            )
            session.commit(pending.intentSender)
        } catch (e: Exception) {
            session.abandon()
            throw e
        } finally {
            session.close()
        }
    }

    private fun ensureInstallReceiver(context: Context) {
        if (receiverRegistered) return
        synchronized(this) {
            if (receiverRegistered) return
            val filter = IntentFilter("${context.packageName}.INSTALL_APK_STATUS")
            val appCtx = context.applicationContext
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                appCtx.registerReceiver(
                    installStatusReceiver,
                    filter,
                    Context.RECEIVER_NOT_EXPORTED,
                )
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                appCtx.registerReceiver(installStatusReceiver, filter)
            }
            receiverRegistered = true
        }
    }
}
