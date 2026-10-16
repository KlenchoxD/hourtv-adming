package com.example.mi_app

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Dialog
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebChromeClient
import android.webkit.ConsoleMessage
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Button
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.common.MethodChannel

/** Loads the provider's normal page; never substitutes for the native player. */
class ProviderStreamResolver(private val activity: Activity) {
    private val main = Handler(Looper.getMainLooper())
    private var view: WebView? = null
    private var pending: MethodChannel.Result? = null
    private var pendingRequestId: Long? = null
    private var timeout: Runnable? = null
    private var verification: Dialog? = null

    @SuppressLint("SetJavaScriptEnabled")
    fun resolve(url: String, requestId: Long, result: MethodChannel.Result) {
        val uri = Uri.parse(url)
        if (uri.scheme != "https" || uri.host != "byseraguci.com" ||
            !uri.path.orEmpty().startsWith("/e/") || uri.userInfo != null) {
            result.success(null)
            return
        }
        finish(null)
        pending = result
        pendingRequestId = requestId
        android.util.Log.i("HourTvResolver", "provider_start")
        try {
            val web = WebView(activity)
            view = web
            web.measure(
                View.MeasureSpec.makeMeasureSpec(1280, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(720, View.MeasureSpec.EXACTLY),
            )
            web.layout(0, 0, 1280, 720)
            web.webChromeClient = object : WebChromeClient() {
                override fun onConsoleMessage(message: ConsoleMessage): Boolean {
                    if (message.message().startsWith("hourtv_unresolved_media")) {
                        // Never leave playback running in the verification view.
                        finish(null)
                        return true
                    }
                    if (message.message().startsWith("hourtv_verification_required")) {
                        showVerification(web)
                        return true
                    }
                    if (message.messageLevel() == ConsoleMessage.MessageLevel.ERROR) {
                        val summary = message.message()
                            .replace(Regex("https?://\\S+"), "[url]").take(160)
                        android.util.Log.i("HourTvResolver", "provider_script_error $summary")
                    }
                    return true
                }
            }
            web.settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                allowFileAccess = false
                allowContentAccess = false
                // Playback was explicitly requested in HourTV. Destroy this
                // resolver as soon as the initial media request is observed.
                mediaPlaybackRequiresUserGesture = false
                setSupportMultipleWindows(false)
            }
            if (!WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
                finish(null)
                return
            }
            // Keep the provider's real parent/frame messaging intact. Only the
            // normal media Play control is activated, within the known origin.
            WebViewCompat.addDocumentStartJavaScript(web, """
                (function () {
                  let prompted = false;
                  document.addEventListener('playing', event => {
                    if (event.target instanceof HTMLMediaElement) {
                      event.target.pause();
                      console.error('hourtv_unresolved_media');
                    }
                  }, true);
                  function start(attempt) {
                  const needsVerification = (document.body?.innerText || '')
                      .includes('verificar que eres humano');
                  if (needsVerification) {
                    if (!prompted) {
                      prompted = true;
                      console.error('hourtv_verification_required');
                    }
                  } else {
                    const play = document.querySelector(
                      '.jw-icon-display[aria-label="Play"]'
                    );
                    if (play) {
                      console.error('hourtv_play_requested');
                      play.click();
                      return;
                    }
                  }
                  if (attempt < 480) {
                    setTimeout(() => start(attempt + 1), 250);
                  } else {
                    console.error('hourtv_play_missing ' +
                      (document.body?.innerText || '').slice(0, 120));
                  }
                  }
                  start(0);
                })();
            """.trimIndent(), setOf("https://n1mwq.org"))
            web.webViewClient = object : WebViewClient() {
                override fun onPageFinished(webView: WebView, pageUrl: String) {
                    if (view !== webView) return
                    val page = Uri.parse(pageUrl)
                    android.util.Log.i("HourTvResolver", "provider_page host=${page.host}")
                }

                override fun shouldInterceptRequest(
                    webView: WebView, request: WebResourceRequest,
                ): WebResourceResponse? {
                    val target = request.url
                    val path = target.path.orEmpty().lowercase()
                    // Observe actual media requests, not blob URLs or page names.
                    if (request.method == "GET" && target.scheme == "https" &&
                        target.userInfo == null &&
                        (path.endsWith(".m3u8") || path.endsWith(".mpd") ||
                            (path.endsWith(".mp4") && !request.isForMainFrame &&
                                request.requestHeaders.keys.any { it.equals("Range", true) }))) {
                        val headers = request.requestHeaders.filterKeys {
                            it.equals("Referer", true) || it.equals("Origin", true) ||
                                it.equals("User-Agent", true)
                        }.toMutableMap()
                        main.post {
                            if (view !== webView) return@post
                            android.util.Log.i("HourTvResolver", "provider_media_found")
                            CookieManager.getInstance().getCookie(target.toString())
                                ?.takeIf { it.isNotBlank() }?.let { headers["Cookie"] = it }
                            finish(mapOf("url" to target.toString(), "headers" to headers))
                        }
                    }
                    return null
                }

                override fun shouldOverrideUrlLoading(
                    webView: WebView, request: WebResourceRequest,
                ): Boolean = request.url.scheme != "https"
            }
            timeout = Runnable {
                android.util.Log.i("HourTvResolver", "provider_timeout")
                finish(null)
            }.also { main.postDelayed(it, 20000) }
            web.loadUrl(url)
        } catch (_: Exception) {
            finish(null)
        }
    }

    fun cancel(requestId: Long) {
        if (pendingRequestId == requestId) finish(null)
    }

    private fun finish(value: Map<String, Any>?) {
        main.removeCallbacksAndMessages(null)
        timeout?.let { main.removeCallbacks(it) }
        timeout = null
        val result = pending
        pending = null
        pendingRequestId = null
        val old = view
        view = null
        verification?.setOnCancelListener(null)
        verification?.dismiss()
        verification = null
        (old?.parent as? ViewGroup)?.removeView(old)
        old?.stopLoading()
        old?.destroy()
        result?.success(value)
    }

    private fun showVerification(web: WebView) {
        if (view !== web || pending == null || verification != null || activity.isFinishing) return
        timeout?.let { main.removeCallbacks(it) }
        val panel = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.BLACK)
            setPadding(20, 20, 20, 20)
        }
        panel.addView(TextView(activity).apply {
            text = "Verificación del servidor\nCompleta la verificación. El video se abrirá en el reproductor de HourTV."
            setTextColor(Color.WHITE)
            textSize = 17f
            setPadding(12, 12, 12, 20)
        })
        panel.addView(web, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f,
        ))
        panel.addView(Button(activity).apply {
            text = "Cancelar"
            setOnClickListener { finish(null) }
        })
        val dialog = Dialog(activity)
        verification = dialog
        dialog.setContentView(panel)
        dialog.setOnCancelListener { finish(null) }
        dialog.show()
        dialog.window?.setLayout(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
        )
        timeout = Runnable { finish(null) }.also { main.postDelayed(it, 120000) }
        android.util.Log.i("HourTvResolver", "provider_verification_shown")
    }

    fun dispose() = finish(null)
}
