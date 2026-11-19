package com.zeroex.oxdl

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/** Keeps downloads alive in the background and shows live status in the notification shade. */
class DownloadForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannels(this)
        val n = build(this, "0XDL", "…", -1, null)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIF_ID, n)
        }
        return START_NOT_STICKY
    }

    companion object {
        const val NOTIF_ID = 9001
        const val CH_PROGRESS = "oxdl_progress"
        const val CH_DONE = "oxdl_done"
        private const val BRAND = 0xFF4AA3E8.toInt()
        @Volatile private var appIcon: Bitmap? = null

        private fun appIcon(ctx: Context): Bitmap? {
            appIcon?.let { return it }
            val b = runCatching {
                BitmapFactory.decodeResource(ctx.resources, R.drawable.notif_app_icon)
            }.getOrNull()
            appIcon = b
            return b
        }

        fun ensureChannels(ctx: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(CH_PROGRESS, "Downloads", NotificationManager.IMPORTANCE_LOW)
            )
            nm.createNotificationChannel(
                NotificationChannel(CH_DONE, "Download results", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }

        private fun openAppIntent(ctx: Context): PendingIntent? {
            val i = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return null
            return PendingIntent.getActivity(
                ctx, 0, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        }

        /** Small icon = app glyph, large icon = video thumbnail (or app icon as fallback). */
        fun build(ctx: Context, title: String, text: String, progress: Int, large: Bitmap?): Notification {
            val b = NotificationCompat.Builder(ctx, CH_PROGRESS)
                .setSmallIcon(R.drawable.ic_stat_download)
                .setColor(BRAND)
                .setLargeIcon(large ?: appIcon(ctx))
                .setContentTitle(title)
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setProgress(100, progress.coerceAtLeast(0), progress < 0)
            openAppIntent(ctx)?.let { b.setContentIntent(it) }
            return b.build()
        }

        fun start(ctx: Context) {
            ContextCompat.startForegroundService(ctx, Intent(ctx, DownloadForegroundService::class.java))
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, DownloadForegroundService::class.java))
        }

        fun update(ctx: Context, title: String, text: String, progress: Int, large: Bitmap?) {
            runCatching {
                NotificationManagerCompat.from(ctx).notify(NOTIF_ID, build(ctx, title, text, progress, large))
            }
        }

        fun done(ctx: Context, id: String, title: String, ok: Boolean, heading: String, large: Bitmap?) {
            runCatching {
                ensureChannels(ctx)
                val b = NotificationCompat.Builder(ctx, CH_DONE)
                    .setSmallIcon(R.drawable.ic_stat_download)
                    .setColor(BRAND)
                    .setLargeIcon(large ?: appIcon(ctx))
                    .setContentTitle(heading)
                    .setContentText(title)
                    .setAutoCancel(true)
                openAppIntent(ctx)?.let { b.setContentIntent(it) }
                NotificationManagerCompat.from(ctx)
                    .notify(10000 + (id.hashCode() and 0x7fffff), b.build())
            }
        }
    }
}
