package com.zeroex.oxdl

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.yausername.aria2c.Aria2c
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Bridge between Flutter and yt-dlp + ffmpeg + aria2c (youtubedl-android).
 * Everything runs locally on the device - no server.
 */
class MainActivity : FlutterActivity() {
    private class Active(val title: String) {
        @Volatile var progress = -1f
        @Volatile var eta = 0L
        @Volatile var speed = ""
        @Volatile var processing = false
        @Volatile var thumb: Bitmap? = null
    }

    private val main = Handler(Looper.getMainLooper())
    private val exec = Executors.newCachedThreadPool()
    private var sink: EventChannel.EventSink? = null
    private val active = ConcurrentHashMap<String, Active>()
    private val cancelled = ConcurrentHashMap.newKeySet<String>()
    @Volatile private var ready = false
    @Volatile private var lastNotif = 0L

    // YouTube changes its client rules often. If the default attempt is rejected we retry
    // with other client sets before giving up.
    private val ytAttempts = listOf(
        "youtube:skip=translated_subs",
        "youtube:player_client=tv,mweb;skip=translated_subs",
        "youtube:player_client=web_safari,web_embedded;skip=translated_subs"
    )

    private fun isYoutube(url: String) =
        Regex("(^|//|\\.)(youtube\\.com|youtu\\.be|youtube-nocookie\\.com)").containsMatchIn(url.lowercase())

    private fun shouldRetry(t: Throwable): Boolean {
        val m = (t.message ?: "").lowercase()
        return listOf("not a bot", "sign in", "403", "forbidden", "no video formats",
            "requested format", "unavailable", "challenge").any { m.contains(it) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "oxdl/progress").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, events: EventChannel.EventSink?) { sink = events }
            override fun onCancel(args: Any?) { sink = null }
        })

        MethodChannel(messenger, "oxdl/ytdlp").setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> exec.execute {
                    try {
                        if (!ready) {
                            YoutubeDL.init(applicationContext)
                            FFmpeg.init(applicationContext)
                            Aria2c.init(applicationContext)
                            ready = true
                        }
                        main.post { result.success(true) }
                    } catch (t: Throwable) {
                        main.post { result.error("INIT_FAIL", t.message, null) }
                    }
                }

                "info" -> {
                    val url = call.argument<String>("url") ?: ""
                    exec.execute {
                        try {
                            val attempts: List<String?> = if (isYoutube(url)) ytAttempts else listOf<String?>(null)
                            var out: String? = null
                            var last: Throwable? = null
                            for (a in attempts) {
                                try {
                                    val req = YoutubeDLRequest(url)
                                    req.addOption("--dump-single-json")
                                    req.addOption("--no-playlist")
                                    req.addOption("--no-warnings")
                                    req.addOption("-R", "1")
                                    req.addOption("--extractor-retries", "1")
                                    req.addOption("--socket-timeout", "12")
                                    if (a != null) req.addOption("--extractor-args", a)
                                    out = YoutubeDL.getInstance().execute(req, null, null).out
                                    break
                                } catch (t: Throwable) {
                                    last = t
                                    if (!shouldRetry(t)) break
                                }
                            }
                            if (out == null) throw (last ?: Exception("No data"))
                            val json = JSONObject(out.substring(out.indexOf('{')))
                            val res = JSONObject()
                            res.put("title", json.optString("title", "video"))
                            res.put("thumbnail", json.optString("thumbnail", ""))
                            res.put("duration", json.optDouble("duration", 0.0))
                            res.put("uploader", json.optString("uploader", ""))
                            res.put("extractor", json.optString("extractor_key", ""))
                            res.put("domain", json.optString("webpage_url_domain", ""))
                            val fm = JSONArray()
                            val src = json.optJSONArray("formats") ?: JSONArray()
                            for (i in 0 until src.length()) {
                                val f = src.getJSONObject(i)
                                val o = JSONObject()
                                o.put("id", f.optString("format_id"))
                                o.put("ext", f.optString("ext"))
                                if (!f.isNull("height")) o.put("h", f.optInt("height"))
                                if (!f.isNull("width")) o.put("w", f.optInt("width"))
                                if (!f.isNull("fps")) o.put("fps", f.optDouble("fps"))
                                if (!f.isNull("tbr")) o.put("tbr", f.optDouble("tbr"))
                                o.put("vc", if (f.isNull("vcodec")) JSONObject.NULL else f.optString("vcodec"))
                                o.put("ac", if (f.isNull("acodec")) JSONObject.NULL else f.optString("acodec"))
                                val size = if (!f.isNull("filesize")) f.optLong("filesize")
                                           else if (!f.isNull("filesize_approx")) f.optLong("filesize_approx") else 0L
                                if (size > 0) o.put("size", size)
                                fm.put(o)
                            }
                            res.put("formats", fm)
                            main.post { result.success(res.toString()) }
                        } catch (t: Throwable) {
                            main.post { result.error("INFO_FAIL", cleanError(t), null) }
                        }
                    }
                }

                "download" -> {
                    val id = call.argument<String>("id") ?: ""
                    val url = call.argument<String>("url") ?: ""
                    val dir = call.argument<String>("dir") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val thumbUrl = call.argument<String>("thumb") ?: ""
                    val notify = call.argument<Boolean>("notify") ?: true
                    val args = call.argument<List<*>>("args") ?: emptyList<Any>()
                    val strings = HashMap<String, String>()
                    (call.argument<Map<*, *>>("strings") ?: emptyMap<Any, Any>())
                        .forEach { (k, v) -> strings[k.toString()] = v.toString() }

                    exec.execute {
                        val state = Active(title)
                        active[id] = state
                        DownloadForegroundService.ensureChannels(applicationContext)
                        runCatching { DownloadForegroundService.start(applicationContext) }
                        pushNotification(strings, force = true)
                        // video thumbnail for the notification (loaded in parallel)
                        if (thumbUrl.isNotEmpty()) {
                            exec.execute {
                                fetchThumb(thumbUrl)?.let {
                                    state.thumb = withBadge(it)
                                    pushNotification(strings, force = true)
                                }
                            }
                        }
                        try {
                            val target = resolveDir(dir)
                            val tmp = File(cacheDir, "ytdl_tmp").apply { mkdirs() }
                            val attempts: List<String?> = if (isYoutube(url)) ytAttempts else listOf<String?>(null)
                            var resp: com.yausername.youtubedl_android.YoutubeDLResponse? = null
                            var last: Throwable? = null
                            for (a in attempts) {
                                try {
                                    val req = YoutubeDLRequest(url)
                                    req.addOption("-P", target.absolutePath)
                                    req.addOption("-P", "temp:" + tmp.absolutePath)
                                    if (a != null) req.addOption("--extractor-args", a)
                                    for (x in args) {
                                        val p = (x as List<*>).map { it.toString() }
                                        if (p.size == 1) req.addOption(p[0]) else req.addOption(p[0], p[1])
                                    }
                                    resp = YoutubeDL.getInstance().execute(req, id) { progress, eta, line ->
                                        state.progress = progress
                                        state.eta = eta
                                        Regex("at\\s+([\\d.]+\\s?[KMG]?i?B/s)").find(line)?.let { state.speed = it.groupValues[1] }
                                        if (line.contains("[Merger]") || line.contains("[ExtractAudio]") ||
                                            line.contains("[VideoRemuxer]") || line.contains("[EmbedThumbnail]") ||
                                            line.contains("[EmbedSubtitle]")) {
                                            state.processing = true
                                            state.speed = ""
                                        }
                                        val m = HashMap<String, Any>()
                                        m["id"] = id
                                        m["progress"] = progress.toDouble()
                                        m["eta"] = eta
                                        m["line"] = line
                                        main.post { sink?.success(m) }
                                        pushNotification(strings, force = false)
                                    }
                                    break
                                } catch (t: Throwable) {
                                    last = t
                                    if (cancelled.contains(id) || state.progress >= 0f || !shouldRetry(t)) break
                                }
                            }
                            if (resp == null) throw (last ?: Exception("Download failed"))
                            val path = resp.out.lines().map { it.trim() }.lastOrNull { it.startsWith("/") } ?: ""
                            // Make the file visible in Gallery / file managers right away
                            scanFile(path)
                            if (notify) DownloadForegroundService.done(
                                applicationContext, id, title, true,
                                strings["done"] ?: "Download complete", state.thumb)
                            main.post { result.success(path) }
                        } catch (t: Throwable) {
                            if (notify && !cancelled.contains(id)) {
                                DownloadForegroundService.done(
                                    applicationContext, id, title, false,
                                    strings["failed"] ?: "Download failed", state.thumb)
                            }
                            main.post { result.error("DL_FAIL", cleanError(t), null) }
                        } finally {
                            active.remove(id)
                            cancelled.remove(id)
                            if (active.isEmpty()) {
                                DownloadForegroundService.stop(applicationContext)
                            } else {
                                pushNotification(strings, force = true)
                            }
                        }
                    }
                }

                "cancel" -> {
                    val id = call.argument<String>("id") ?: ""
                    cancelled.add(id)
                    exec.execute { runCatching { YoutubeDL.destroyProcessById(id) } }
                    result.success(true)
                }

                "update" -> {
                  val channel = call.argument<String>("channel") ?: "nightly"
                  exec.execute {
                    try {
                        val ch = when (channel) {
                            "stable" -> YoutubeDL.UpdateChannel.STABLE
                            "master" -> YoutubeDL.UpdateChannel.MASTER
                            else -> YoutubeDL.UpdateChannel.NIGHTLY
                        }
                        val st = YoutubeDL.getInstance().updateYoutubeDL(
                            appContext = applicationContext,
                            updateChannel = ch
                        )
                        main.post { result.success(st?.name ?: "UNKNOWN") }
                    } catch (t: Throwable) {
                        main.post { result.error("UPDATE_FAIL", cleanError(t), null) }
                    }
                  }
                }

                "version" -> exec.execute {
                    val v = runCatching { YoutubeDL.getInstance().version(applicationContext) }.getOrNull()
                    main.post { result.success(v ?: "") }
                }

                "getBrightness" -> {
                    val b = window.attributes.screenBrightness
                    val v = if (b >= 0f) b else try {
                        android.provider.Settings.System.getInt(
                            contentResolver, android.provider.Settings.System.SCREEN_BRIGHTNESS) / 255f
                    } catch (_: Throwable) { 0.5f }
                    result.success(v.toDouble())
                }

                "setBrightness" -> {
                    val v = (call.argument<Double>("value") ?: -1.0).toFloat()
                    val lp = window.attributes
                    lp.screenBrightness = if (v < 0f)
                        android.view.WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                    else v.coerceIn(0.01f, 1f)
                    window.attributes = lp
                    result.success(true)
                }

                "getVolume" -> {
                    val am = getSystemService(android.content.Context.AUDIO_SERVICE) as AudioManager
                    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
                    result.success(am.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max)
                }

                "setVolume" -> {
                    val am = getSystemService(android.content.Context.AUDIO_SERVICE) as AudioManager
                    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
                    val v = (call.argument<Double>("value") ?: 0.5).coerceIn(0.0, 1.0)
                    am.setStreamVolume(AudioManager.STREAM_MUSIC, Math.round(v * max).toInt(), 0)
                    result.success(true)
                }

                "thumbnail" -> {
                    val path = call.argument<String>("path") ?: ""
                    exec.execute {
                        var out = ""
                        try {
                            val mmr = MediaMetadataRetriever()
                            mmr.setDataSource(path)
                            var bmp: Bitmap? = null
                            val pic = mmr.embeddedPicture
                            if (pic != null) bmp = BitmapFactory.decodeByteArray(pic, 0, pic.size)
                            if (bmp == null) {
                                bmp = mmr.getFrameAtTime(1_000_000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                                    ?: mmr.getFrameAtTime(0)
                            }
                            mmr.release()
                            if (bmp != null) {
                                val w = 480
                                val scaled = if (bmp.width > w)
                                    Bitmap.createScaledBitmap(
                                        bmp, w, (bmp.height * w.toFloat() / bmp.width).toInt().coerceAtLeast(1), true)
                                else bmp
                                val dir = File(filesDir, "thumbs").apply { mkdirs() }
                                val f = File(dir, "t" + Math.abs(path.hashCode()) + ".jpg")
                                f.outputStream().use { scaled.compress(Bitmap.CompressFormat.JPEG, 82, it) }
                                out = f.absolutePath
                            }
                        } catch (_: Throwable) {
                        }
                        main.post { result.success(out) }
                    }
                }

                "downloadApk" -> {
                    val url = call.argument<String>("url") ?: ""
                    val path = call.argument<String>("path") ?: ""
                    val title = call.argument<String>("title") ?: "0XDL"
                    val strings = HashMap<String, String>()
                    (call.argument<Map<*, *>>("strings") ?: emptyMap<Any, Any>())
                        .forEach { (k, v) -> strings[k.toString()] = v.toString() }
                    exec.execute {
                        val key = "__update__"
                        val state = Active(title)
                        active[key] = state
                        DownloadForegroundService.ensureChannels(applicationContext)
                        runCatching { DownloadForegroundService.start(applicationContext) }
                        pushNotification(strings, force = true)
                        try {
                            val file = File(path)
                            file.parentFile?.mkdirs()
                            var attempt = 0
                            var finished = false
                            var last: Throwable? = null
                            while (!finished && attempt < 8) {
                                try {
                                    val have = if (file.exists()) file.length() else 0L
                                    val conn = URL(url).openConnection() as HttpURLConnection
                                    conn.connectTimeout = 15000
                                    conn.readTimeout = 25000
                                    conn.setRequestProperty("User-Agent", "0XDL")
                                    if (have > 0) conn.setRequestProperty("Range", "bytes=$have-")
                                    conn.connect()
                                    val code = conn.responseCode
                                    if (code != 200 && code != 206) throw Exception("HTTP $code")
                                    val append = code == 206
                                    val base = if (append) have else 0L
                                    val len = conn.contentLengthLong
                                    val total = if (len > 0) base + len else -1L
                                    conn.inputStream.use { input ->
                                        java.io.FileOutputStream(file, append).use { out ->
                                            val buf = ByteArray(64 * 1024)
                                            var got = base
                                            while (true) {
                                                val n = input.read(buf)
                                                if (n < 0) break
                                                out.write(buf, 0, n)
                                                got += n
                                                if (total > 0) {
                                                    val pct = got * 100.0 / total
                                                    state.progress = pct.toFloat()
                                                    val m = HashMap<String, Any>()
                                                    m["id"] = key
                                                    m["progress"] = pct
                                                    m["eta"] = 0L
                                                    m["line"] = ""
                                                    main.post { sink?.success(m) }
                                                    pushNotification(strings, force = false)
                                                }
                                            }
                                        }
                                    }
                                    finished = true
                                } catch (t: Throwable) {
                                    last = t
                                    attempt++
                                    Thread.sleep(2000)
                                }
                            }
                            if (!finished) throw (last ?: Exception("Download failed"))
                            main.post { result.success(path) }
                        } catch (t: Throwable) {
                            main.post { result.error("APK_FAIL", cleanError(t), null) }
                        } finally {
                            active.remove(key)
                            if (active.isEmpty()) {
                                DownloadForegroundService.stop(applicationContext)
                            } else {
                                pushNotification(strings, force = true)
                            }
                        }
                    }
                }

                "scan" -> {
                    val paths = (call.argument<List<*>>("paths") ?: emptyList<Any>()).map { it.toString() }
                    paths.forEach { scanFile(it) }
                    result.success(true)
                }

                "abi" -> result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "")

                "scheduleUpdate" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val wm = WorkManager.getInstance(applicationContext)
                    if (!enabled) {
                        wm.cancelUniqueWork("oxdl_update_check")
                    } else {
                        getSharedPreferences("oxdl_update", MODE_PRIVATE).edit()
                            .putString("repo", call.argument<String>("repo") ?: "")
                            .putString("version", call.argument<String>("version") ?: "0.0.0")
                            .putString("title", call.argument<String>("title") ?: "Update available")
                            .putString("body", call.argument<String>("body") ?: "0XDL %s is ready to install")
                            .putString("skipped", call.argument<String>("skipped") ?: "")
                            .apply()
                        val req = PeriodicWorkRequest.Builder(UpdateCheckWorker::class.java, 12, TimeUnit.HOURS)
                            .setConstraints(
                                Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
                            )
                            .build()
                        wm.enqueueUniquePeriodicWork(
                            "oxdl_update_check", ExistingPeriodicWorkPolicy.UPDATE, req)
                    }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Files written straight to /Download by yt-dlp are not in MediaStore, so Gallery and
     * file managers do not show them. Scanning registers them.
     */
    private fun scanFile(path: String) {
        if (path.isEmpty()) return
        val mime: String? = when (path.substringAfterLast('.', "").lowercase()) {
            "mp4", "m4v" -> "video/mp4"
            "mkv" -> "video/x-matroska"
            "webm" -> "video/webm"
            "mov" -> "video/quicktime"
            "mp3" -> "audio/mpeg"
            "m4a" -> "audio/mp4"
            "opus", "ogg" -> "audio/ogg"
            "flac" -> "audio/flac"
            "wav" -> "audio/wav"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            else -> null
        }
        runCatching {
            MediaScannerConnection.scanFile(applicationContext, arrayOf(path), arrayOf<String?>(mime), null)
        }
    }

    private fun fetchThumb(url: String): Bitmap? = try {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 8000
        c.readTimeout = 8000
        val bmp = c.inputStream.use { BitmapFactory.decodeStream(it) }
        if (bmp == null) null else {
            val s = minOf(bmp.width, bmp.height)
            val crop = Bitmap.createBitmap(bmp, (bmp.width - s) / 2, (bmp.height - s) / 2, s, s)
            Bitmap.createScaledBitmap(crop, 256, 256, true)
        }
    } catch (_: Throwable) {
        null
    }

    /** Video thumbnail with the app icon in the bottom-right corner (for notifications). */
    private fun withBadge(base: Bitmap): Bitmap {
        return try {
            val icon = BitmapFactory.decodeResource(resources, R.drawable.notif_app_icon) ?: return base
            val out = base.copy(Bitmap.Config.ARGB_8888, true)
            val canvas = android.graphics.Canvas(out)
            val size = (out.width * 0.44f).toInt()
            val badge = Bitmap.createScaledBitmap(icon, size, size, true)
            val pad = out.width * 0.02f
            val x = out.width - size - pad
            val y = out.height - size - pad
            val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
            paint.color = android.graphics.Color.WHITE
            canvas.drawRoundRect(x - 4f, y - 4f, x + size + 4f, y + size + 4f, 20f, 20f, paint)
            canvas.drawBitmap(badge, x, y, null)
            out
        } catch (_: Throwable) {
            base
        }
    }

    private fun fmtEta(s: Long): String {
        if (s <= 0) return ""
        return "%d:%02d".format(s / 60, s % 60)
    }

    /** Live status in the notification: title, percentage, speed and ETA. */
    private fun pushNotification(strings: Map<String, String>, force: Boolean) {
        val now = System.currentTimeMillis()
        if (!force && now - lastNotif < 1000) return
        lastNotif = now
        val list = active.values.toList()
        if (list.isEmpty()) return
        val title: String
        val text: String
        val pct: Int
        var large: Bitmap? = null
        if (list.size == 1) {
            val a = list[0]
            large = a.thumb
            title = a.title
            pct = if (a.progress >= 0f) a.progress.toInt().coerceIn(0, 100) else -1
            text = if (a.processing) {
                strings["processing"] ?: "Processing…"
            } else {
                listOfNotNull(
                    strings["downloading"] ?: "Downloading",
                    if (pct >= 0) "$pct%" else null,
                    a.speed.ifEmpty { null },
                    fmtEta(a.eta).ifEmpty { null }
                ).joinToString(" · ")
            }
        } else {
            title = (strings["multi"] ?: "%d downloads").replace("%d", list.size.toString())
            val known = list.filter { it.progress >= 0f }
            pct = if (known.isEmpty()) -1 else (known.map { it.progress }.average()).toInt()
            text = list.joinToString(" | ") { it.title }.take(120)
        }
        DownloadForegroundService.update(applicationContext, title, text, pct, large)
    }

    /** Download folder; falls back to app storage if it cannot be written. */
    private fun resolveDir(path: String): File {
        val d = File(path)
        try {
            d.mkdirs()
            if (d.isDirectory && d.canWrite()) return d
        } catch (_: Throwable) {}
        val rel = path.substringAfter("/Download/", "0XDL")
        val fb = File(getExternalFilesDir(null), rel)
        fb.mkdirs()
        return fb
    }

    private fun cleanError(t: Throwable): String {
        val msg = t.message ?: t.toString()
        val line = msg.lines().lastOrNull { it.contains("ERROR", true) } ?: msg.takeLast(300)
        return line.trim()
    }
}
