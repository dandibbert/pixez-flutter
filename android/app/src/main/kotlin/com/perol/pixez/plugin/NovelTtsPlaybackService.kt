package com.perol.pixez.plugin

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class NovelTtsPlaybackService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NovelTtsNowPlayingPlugin.foregroundNotification
            ?: placeholder()
        // From API 31 startForeground throws when the app is not eligible to
        // start a foreground service, and from API 34 it also throws when the
        // media playback type is not allowed. Neither is catchable at the call
        // site in the plugin, so it has to be handled here or the process dies.
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NovelTtsNowPlayingPlugin.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(NovelTtsNowPlayingPlugin.NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    private fun placeholder(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(
                NotificationChannel(
                    NovelTtsNowPlayingPlugin.NOTIFICATION_CHANNEL,
                    "Novel TTS",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        return NotificationCompat.Builder(this, NovelTtsNowPlayingPlugin.NOTIFICATION_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Novel TTS")
            .setOngoing(true)
            .build()
    }
}
