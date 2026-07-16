package com.example.mi_app

import android.content.Context
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider
import com.google.android.gms.cast.framework.media.CastMediaOptions
import com.google.android.gms.cast.framework.media.NotificationOptions

class HourTvCastOptionsProvider : OptionsProvider {
    override fun getCastOptions(context: Context): CastOptions {
        val notifications = NotificationOptions.Builder()
            .setTargetActivityClassName(CastExpandedControlsActivity::class.java.name)
            .build()
        val media = CastMediaOptions.Builder()
            .setNotificationOptions(notifications)
            .setExpandedControllerActivityClassName(CastExpandedControlsActivity::class.java.name)
            .build()
        return CastOptions.Builder()
            .setReceiverApplicationId(DEFAULT_RECEIVER_APP_ID)
            .setCastMediaOptions(media)
            .setEnableReconnectionService(true)
            .setResumeSavedSession(true)
            .build()
    }

    override fun getAdditionalSessionProviders(
        context: Context,
    ): MutableList<SessionProvider>? = null

    private companion object {
        const val DEFAULT_RECEIVER_APP_ID = "CC1AD845"
    }
}
