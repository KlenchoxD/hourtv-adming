package com.example.mi_app

import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.ead.lib.moongetter.MoonFactory
import com.ead.lib.moongetter.MoonGetter
import com.ead.lib.moongetter.client.cookie.managment.MoonCookie
import com.ead.lib.moongetter.client.ktor.KtorMoonClient
import com.ead.lib.moongetter.client.models.Configuration
import com.ead.lib.moongetter.client.trust.manager.MoonTrust
import com.ead.lib.moongetter.models.builder.Engine
import com.ead.lib.moongetter.server.bundle.serverBundle
import io.flutter.plugin.common.MethodChannel
import io.ktor.client.engine.okhttp.OkHttp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import java.io.IOException
import java.util.concurrent.TimeUnit

/** Resolves recognized provider pages to a direct URL; HourTV owns playback. */
class MoonGetterResolver {
    private val main = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var requestGeneration = 0
    private var pendingResult: MethodChannel.Result? = null
    private var pendingRequestId: Long? = null
    private var pendingJob: Job? = null
    private var disposed = false
    private var initialized = false

    fun resolve(rawUrl: String, requestId: Long, result: MethodChannel.Result) {
        cancelPending()
        if (disposed) {
            result.success(failed())
            return
        }

        val uri = Uri.parse(rawUrl)
        if (uri.scheme != "https" || uri.host.isNullOrBlank() || uri.userInfo != null) {
            result.success(unsupported())
            return
        }

        val generation = requestGeneration
        pendingResult = result
        pendingRequestId = requestId
        pendingJob = scope.launch {
            val response = try {
                resolveRecognized(rawUrl)
            } catch (_: CancellationException) {
                return@launch
            } catch (error: Exception) {
                val retryable = error.isTransientNetworkFailure()
                android.util.Log.w(
                    "HourTvResolver",
                    "moongetter_failed reason=${if (retryable) "network" else "resolver"} " +
                        "type=${error.javaClass.simpleName}",
                )
                failed(retryable)
            }
            main.post {
                if (generation != requestGeneration || disposed) return@post
                pendingResult = null
                pendingRequestId = null
                pendingJob = null
                result.success(response)
            }
        }
    }

    private suspend fun resolveRecognized(rawUrl: String): Map<String, Any?> {
        initializeMoonGetter()
        val provider = MoonGetter.identifier(rawUrl) ?: run {
            val host = Uri.parse(rawUrl).host.orEmpty()
            android.util.Log.i(
                "HourTvResolver",
                "moongetter_unsupported reason=provider_not_registered host=$host",
            )
            return unsupported()
        }
        android.util.Log.i("HourTvResolver", "moongetter_start provider=$provider")

        // The bundle's network fallback is not used for unknown hosts: identifier
        // is checked first. Network work is bounded and cancellation-aware.
        val server = try {
            withTimeout(8_500L) { MoonGetter.getOrNull(rawUrl) }
        } catch (_: TimeoutCancellationException) {
            android.util.Log.w(
                "HourTvResolver",
                "moongetter_failed provider=$provider reason=timeout",
            )
            return failed(retryable = true)
        } ?: run {
            android.util.Log.i(
                "HourTvResolver",
                "moongetter_failed provider=$provider reason=no_media_source",
            )
            return failed()
        }
        val selected = server.videos.asSequence()
            .filter { it.request.method.equals("GET", ignoreCase = true) }
            .mapNotNull { video ->
                val candidate = Uri.parse(video.request.url)
                if (candidate.scheme != "https" || candidate.host.isNullOrBlank() ||
                    candidate.userInfo != null) {
                    null
                } else {
                    val headers = safeHeaders(video.request.headers.orEmpty())
                    Triple(video, candidate, headers)
                }
            }
            .maxByOrNull { (video, _, _) -> qualityRank(video.quality) }
            ?: run {
                android.util.Log.i(
                    "HourTvResolver",
                    "moongetter_failed provider=$provider reason=no_playable_variant",
                )
                return failed()
            }

        val (video, mediaUri, headers) = selected
        android.util.Log.i(
            "HourTvResolver",
            "moongetter_resolved provider=$provider format=${formatHint(mediaUri)}",
        )
        return mapOf(
            "status" to "resolved",
            "url" to mediaUri.toString(),
            "headers" to headers,
            "formatHint" to formatHint(mediaUri),
            "quality" to video.quality,
            "subtitles" to emptyList<Map<String, Any>>(),
        )
    }

    @Synchronized
    private fun initializeMoonGetter() {
        if (initialized) return

        val timeoutMillis = 8_000L
        val client = KtorMoonClient(
            engineFactory = OkHttp,
            cookieManagement = MoonCookie.Management.newEmptyFactory(),
            trustManager = MoonTrust.Manager.newEmptyFactory(),
            engineConfigBuilder = {
                config {
                    callTimeout(9, TimeUnit.SECONDS)
                    connectTimeout(4, TimeUnit.SECONDS)
                    readTimeout(7, TimeUnit.SECONDS)
                }
            },
        )
        val config = MoonFactory.Builder()
            .setClient(client)
            .setTimeout(timeoutMillis)
            .apply {
                // MoonGetter alpha02 defaults to disabling TLS validation. Force
                // normal platform certificate checks before it initializes Ktor.
                configData = Configuration.Data(
                    timeout = timeoutMillis,
                    disableSSLValidation = false,
                )
            }
        val factory = config.setEngine(Engine.Builder().onCore(serverBundle).build())
        MoonGetter.start(factory)
        initialized = true
    }

    fun cancel(requestId: Long) {
        if (pendingRequestId == requestId) cancelPending()
    }

    private fun cancelPending() {
        requestGeneration++
        pendingJob?.cancel()
        pendingJob = null
        val previous = pendingResult
        pendingResult = null
        pendingRequestId = null
        previous?.success(mapOf("status" to "cancelled"))
    }

    fun dispose() {
        if (disposed) return
        cancelPending()
        disposed = true
        scope.cancel()
    }

    private fun safeHeaders(raw: Map<String, String>): Map<String, String> {
        val allowed = setOf("user-agent", "referer", "origin", "accept")
        return raw.entries.asSequence()
            .filter { (key, value) ->
                key.lowercase() in allowed && key.length <= 64 && value.length <= 8_192 &&
                    !key.contains('\r') && !key.contains('\n') &&
                    !value.contains('\r') && !value.contains('\n')
            }
            .associate { (key, value) -> key to value }
    }

    private fun Throwable.isTransientNetworkFailure(): Boolean {
        var current: Throwable? = this
        val visited = mutableSetOf<Throwable>()
        while (current != null && visited.add(current)) {
            if (current is IOException || current is TimeoutCancellationException) {
                return true
            }
            current = current.cause
        }
        return false
    }

    private fun qualityRank(quality: String?): Int {
        val value = quality.orEmpty().lowercase()
        if ("4k" in value || "2160" in value) return 2160
        return Regex("(\\d{3,4})").find(value)?.groupValues?.getOrNull(1)?.toIntOrNull() ?: 0
    }

    private fun formatHint(uri: Uri): String? = when {
        uri.path.orEmpty().lowercase().endsWith(".m3u8") -> "hls"
        uri.path.orEmpty().lowercase().endsWith(".mpd") -> "dash"
        else -> null
    }

    private fun unsupported() = mapOf("status" to "unsupported")
    private fun failed(retryable: Boolean = false) = mapOf(
        "status" to "failed",
        "retryable" to retryable,
    )

}
