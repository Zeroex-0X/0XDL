package com.zeroex.oxdl

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Runs about every 12 hours (only while the Notifications switch is on).
 * Looks at the latest GitHub release and posts a notification when a newer version exists.
 */
class UpdateCheckWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {

    override fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences("oxdl_update", Context.MODE_PRIVATE)
        val repo = prefs.getString("repo", "") ?: ""
        val current = prefs.getString("version", "0.0.0") ?: "0.0.0"
        if (repo.isEmpty()) return Result.success()
        try {
            val conn = URL("https://api.github.com/repos/$repo/releases/latest")
                .openConnection() as HttpURLConnection
            conn.setRequestProperty("User-Agent", "0XDL")
            conn.setRequestProperty("Accept", "application/vnd.github+json")
            conn.connectTimeout = 10000
            conn.readTimeout = 10000
            if (conn.responseCode != 200) return Result.success()
            val json = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            val tag = json.optString("tag_name").trimStart('v', 'V')
            if (tag.isNotEmpty() && isNewer(tag, current) &&
                prefs.getString("notified", "") != tag && prefs.getString("skipped", "") != tag) {
                notifyUpdate(
                    prefs.getString("title", "Update available") ?: "Update available",
                    (prefs.getString("body", "0XDL %s is ready to install") ?: "%s").replace("%s", tag)
                )
                prefs.edit().putString("notified", tag).apply()
            }
        } catch (_: Throwable) {
        }
        return Result.success()
    }

    private fun isNewer(latest: String, current: String): Boolean {
        fun parse(v: String) = v.split('.', '-', '+').map { it.toIntOrNull() ?: 0 }
        val a = parse(latest)
        val b = parse(current)
        for (i in 0 until 3) {
            val x = a.getOrElse(i) { 0 }
            val y = b.getOrElse(i) { 0 }
            if (x != y) return x > y
        }
        return false
    }

    private fun notifyUpdate(title: String, text: String) {
        val ctx = applicationContext
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel("oxdl_updates", "App updates", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        val pi = launch?.let {
            PendingIntent.getActivity(ctx, 1, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        val b = NotificationCompat.Builder(ctx, "oxdl_updates")
            .setSmallIcon(R.drawable.ic_stat_download)
            .setColor(0xFF4AA3E8.toInt())
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
        if (pi != null) b.setContentIntent(pi)
        runCatching { NotificationManagerCompat.from(ctx).notify(9100, b.build()) }
    }
}
