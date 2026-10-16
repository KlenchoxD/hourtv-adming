package com.example.mi_app

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

/** Own bridge: metadata-only extraction, off the UI thread, no remote service. */
class YtDlpResolver(context: Context) {
    private val context = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var generation = 0
    private var pending: MethodChannel.Result? = null
    private var pendingRequestId: Long? = null

    fun resolve(url: String, requestId: Long, result: MethodChannel.Result) {
        cancelPending()
        val token = generation
        pending = result
        pendingRequestId = requestId
        main.postDelayed({ if (token == generation) cancelPending() }, 30000)
        executor.execute {
            val value = try {
                if (!Python.isStarted()) Python.start(AndroidPlatform(context))
                val raw = Python.getInstance().getModule("hourtv_extractor")
                    .callAttr("resolve", url).toString()
                if (raw == "null") null else {
                    val data = JSONObject(raw)
                    val headers = safeHeaders(data.optJSONObject("headers"))
                    val formatHint = data.optString("formatHint").takeIf {
                        it == "hls" || it == "dash" || it == "ss"
                    }
                    val subtitles = safeSubtitles(data.optJSONArray("subtitles"))
                    mapOf(
                        "url" to data.getString("url"),
                        "headers" to headers,
                        "formatHint" to formatHint,
                        "subtitles" to subtitles,
                    )
                }
            } catch (_: Exception) { null }
            main.post {
                if (token != generation) return@post
                main.removeCallbacksAndMessages(null)
                pending = null
                pendingRequestId = null
                result.success(value)
            }
        }
    }

    fun cancel(requestId: Long) {
        if (pendingRequestId == requestId) cancelPending()
    }

    private fun cancelPending() {
        generation++
        main.removeCallbacksAndMessages(null)
        val previous = pending
        pending = null
        pendingRequestId = null
        previous?.success(null)
    }

    fun dispose() {
        cancelPending()
        executor.shutdownNow()
    }

    private fun safeHeaders(raw: JSONObject?): Map<String, String> {
        if (raw == null) return emptyMap()
        val allowed = setOf("user-agent", "referer", "origin", "accept")
        val result = mutableMapOf<String, String>()
        val keys = raw.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = raw.optString(key, "")
            if (key.lowercase() in allowed && !value.contains('\r') && !value.contains('\n')) {
                result[key] = value
            }
        }
        return result
    }

    private fun safeSubtitles(raw: org.json.JSONArray?): List<Map<String, Any>> {
        if (raw == null) return emptyList()
        val tracks = mutableListOf<Map<String, Any>>()
        for (index in 0 until minOf(raw.length(), 12)) {
            val track = raw.optJSONObject(index) ?: continue
            val uri = Uri.parse(track.optString("url", ""))
            if (uri.scheme != "https" || uri.host.isNullOrBlank() || uri.userInfo != null) continue
            val language = track.optString("language", "")
            if (!Regex("^[A-Za-z0-9_-]{1,32}$").matches(language)) continue
            val format = track.optString("ext", "").lowercase()
            if (format !in setOf("vtt", "srt", "ass")) continue
            tracks.add(
                mapOf(
                    "url" to uri.toString(),
                    "language" to language,
                    "ext" to format,
                    "headers" to safeHeaders(track.optJSONObject("headers")),
                    "isDefault" to track.optBoolean("isDefault", false),
                ),
            )
        }
        return tracks
    }
}
