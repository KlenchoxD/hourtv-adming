package com.example.mi_app

import android.app.PictureInPictureParams
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Rational
import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "hourtv/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTv" -> result.success(isTelevision())
                "enterPictureInPicture" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N ||
                        !packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                    ) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val width = (call.argument<Number>("width")?.toInt() ?: 16).coerceAtLeast(1)
                        val height = (call.argument<Number>("height")?.toInt() ?: 9).coerceAtLeast(1)
                        val entered = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(width, height))
                                .build()
                            enterPictureInPictureMode(params)
                        } else {
                            @Suppress("DEPRECATION")
                            enterPictureInPictureMode()
                        }
                        result.success(entered)
                    } catch (error: Exception) {
                        result.error("pip_failed", error.message, null)
                    }
                }
                "openCastSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_CAST_SETTINGS))
                        result.success(true)
                    } catch (castError: Exception) {
                        try {
                            startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                            result.success(true)
                        } catch (wirelessError: Exception) {
                            result.error(
                                "cast_settings_unavailable",
                                wirelessError.message ?: castError.message,
                                null,
                            )
                        }
                    }
                }
                "shareText" -> {
                    val text = call.argument<String>("text")?.trim().orEmpty()
                    if (text.isEmpty()) {
                        result.error("empty_share", "No hay contenido para compartir", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_SUBJECT, call.argument<String>("subject").orEmpty())
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        startActivity(Intent.createChooser(shareIntent, "Compartir con"))
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("share_unavailable", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isTelevision(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        return uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
    }
}
