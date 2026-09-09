package com.perol.pixez.plugin

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.media.app.NotificationCompat.MediaStyle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class NovelTtsNowPlayingPlugin {
    companion object {
        private const val CHANNEL = "com.perol.dev/novel_tts"
        const val NOTIFICATION_CHANNEL = "pixez_novel_tts"
        const val NOTIFICATION_ID = 42101
        private const val ACTION_PLAY = "com.perol.pixez.tts.PLAY"
        private const val ACTION_PAUSE = "com.perol.pixez.tts.PAUSE"
        private const val ACTION_NEXT = "com.perol.pixez.tts.NEXT"
        private const val ACTION_PREV = "com.perol.pixez.tts.PREV"
        private const val ACTION_STOP = "com.perol.pixez.tts.STOP"

        /// 44 byte wav header plus one second of 8 kHz 16 bit mono silence.
        private const val EXPECTED_SILENCE_BYTES = 44L + 8000L * 2L

        @Volatile
        var foregroundNotification: Notification? = null

        fun bindChannel(context: Context, flutterEngine: FlutterEngine) {
            val plugin = NovelTtsNowPlayingPlugin()
            plugin.attach(context.applicationContext, flutterEngine)
            instance = plugin
        }

        @Volatile
        private var instance: NovelTtsNowPlayingPlugin? = null

        fun dispatch(action: String?) {
            val method = when (action) {
                ACTION_PLAY -> "play"
                ACTION_PAUSE -> "pause"
                ACTION_NEXT -> "next"
                ACTION_PREV -> "previous"
                ACTION_STOP -> "stop"
                else -> return
            }
            instance?.emit(method)
        }
    }

    private var appContext: Context? = null
    private var channel: MethodChannel? = null
    private var mediaSession: MediaSessionCompat? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var keepAlivePlayer: MediaPlayer? = null

    fun attach(context: Context, flutterEngine: FlutterEngine) {
        appContext = context
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            when (call.method) {
                "start" -> {
                    start(args)
                    result.success(null)
                }

                "update" -> {
                    update(args)
                    result.success(null)
                }

                "keepAlive" -> {
                    keepAlive()
                    result.success(null)
                }

                "endKeepAlive" -> {
                    endKeepAlive()
                    result.success(null)
                }

                "beginBackgroundTask", "endBackgroundTask" -> result.success(null)

                "stop" -> {
                    stop()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun start(args: Map<*, *>) {
        val context = appContext ?: return
        ensureChannel(context)
        registerReceiver(context)
        if (mediaSession == null) {
            mediaSession = MediaSessionCompat(context, "pixez.novel.tts").apply {
                setCallback(object : MediaSessionCompat.Callback() {
                    override fun onPlay() = emit("play")
                    override fun onPause() = emit("pause")
                    override fun onSkipToNext() = emit("next")
                    override fun onSkipToPrevious() = emit("previous")
                    override fun onStop() = emit("stop")
                })
                isActive = true
            }
        }
        update(args)
        keepAlive()
    }

    private fun keepAlive() {
        val context = appContext ?: return
        acquireLocks(context)
        startSilentPlayer(context)
        val intent = Intent(context, NovelTtsPlaybackService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (_: Exception) {
        }
    }

    private fun endKeepAlive() {
        val context = appContext ?: return
        try {
            keepAlivePlayer?.stop()
            keepAlivePlayer?.release()
        } catch (_: Exception) {
        }
        keepAlivePlayer = null
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
            if (wifiLock?.isHeld == true) {
                wifiLock?.release()
            }
        } catch (_: Exception) {
        }
        try {
            context.stopService(Intent(context, NovelTtsPlaybackService::class.java))
        } catch (_: Exception) {
        }
    }

    private fun update(args: Map<*, *>) {
        val context = appContext ?: return
        val session = mediaSession ?: return
        val title = args["title"] as? String ?: ""
        val artist = args["artist"] as? String ?: ""
        val subtitle = args["subtitle"] as? String ?: ""
        val isPlaying = args["isPlaying"] as? Boolean ?: false
        val durationMs = (args["durationMs"] as? Number)?.toLong() ?: 0L
        val positionMs = (args["positionMs"] as? Number)?.toLong() ?: 0L
        session.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, subtitle.ifEmpty { title })
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist.ifEmpty { title })
                .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, title)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
                .build()
        )
        val state = if (isPlaying) {
            PlaybackStateCompat.STATE_PLAYING
        } else {
            PlaybackStateCompat.STATE_PAUSED
        }
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackStateCompat.ACTION_STOP
                )
                .setState(state, positionMs, if (isPlaying) 1f else 0f)
                .build()
        )
        showNotification(context, session, title, artist, subtitle, isPlaying)
    }

    private fun stop() {
        val context = appContext ?: return
        endKeepAlive()
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
        foregroundNotification = null
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun showNotification(
        context: Context,
        session: MediaSessionCompat,
        title: String,
        artist: String,
        subtitle: String,
        isPlaying: Boolean,
    ) {
        // getLaunchIntentForPackage is declared nullable, and PendingIntent
        // rejects a null intent, so the notification goes out without a tap
        // target rather than taking the process down.
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = launch?.let {
            PendingIntent.getActivity(
                context,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
            )
        }
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(subtitle.ifEmpty { title })
            .setContentText(if (artist.isEmpty()) title else "$title · $artist")
            .setContentIntent(contentIntent)
            .setOngoing(isPlaying)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setStyle(
                MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .addAction(android.R.drawable.ic_media_previous, "Prev", action(context, ACTION_PREV, 1))
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "Pause" else "Play",
                action(context, if (isPlaying) ACTION_PAUSE else ACTION_PLAY, 2),
            )
            .addAction(android.R.drawable.ic_media_next, "Next", action(context, ACTION_NEXT, 3))
            .build()
        foregroundNotification = notification
        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
    }

    private fun acquireLocks(context: Context) {
        // Both casts and both acquires are best effort: a device that refuses a
        // lock should still read the chapter.
        try {
            val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (wakeLock == null && power != null) {
                wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "pixez:novel_tts").apply {
                    setReferenceCounted(false)
                }
            }
            if (wakeLock?.isHeld != true) {
                wakeLock?.acquire(6 * 60 * 60 * 1000L)
            }
        } catch (_: Exception) {
        }
        try {
            val wifi = context.applicationContext
                .getSystemService(Context.WIFI_SERVICE) as? WifiManager
            if (wifiLock == null && wifi != null) {
                @Suppress("DEPRECATION")
                wifiLock = wifi.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "pixez:novel_tts").apply {
                    setReferenceCounted(false)
                }
            }
            if (wifiLock?.isHeld != true) {
                wifiLock?.acquire()
            }
        } catch (_: Exception) {
        }
    }

    private fun startSilentPlayer(context: Context) {
        val existing = keepAlivePlayer
        if (existing != null) {
            // A player that errored out throws from start() instead of playing.
            try {
                existing.start()
                return
            } catch (_: Exception) {
                try {
                    existing.release()
                } catch (_: Exception) {
                }
                keepAlivePlayer = null
            }
        }
        val file = silenceFile(context) ?: return
        val player = MediaPlayer()
        try {
            player.setDataSource(file.absolutePath)
            player.isLooping = true
            player.setVolume(0.01f, 0.01f)
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            player.prepare()
            player.start()
            keepAlivePlayer = player
        } catch (_: Exception) {
            // prepare() throws IOException on a truncated file and
            // IllegalStateException on a bad state. Reading a chapter without
            // the keep-alive tone is a far better outcome than dying here.
            try {
                player.release()
            } catch (_: Exception) {
            }
            keepAlivePlayer = null
            file.delete()
        }
    }

    /// The tone is written through a temp file: a half-written wav left behind
    /// by a kill would otherwise exist(), fail prepare(), and keep failing.
    private fun silenceFile(context: Context): File? {
        val file = File(context.cacheDir, "novel_tts_silence.wav")
        if (file.length() == EXPECTED_SILENCE_BYTES) {
            return file
        }
        return try {
            val temp = File.createTempFile("novel_tts_silence", ".wav", context.cacheDir)
            temp.writeBytes(silenceWav())
            file.delete()
            if (temp.renameTo(file)) file else temp
        } catch (_: Exception) {
            null
        }
    }

    private fun silenceWav(): ByteArray {
        val sampleRate = 8000
        val dataSize = sampleRate * 2
        val buffer = ByteBuffer.allocate(44 + dataSize).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put("RIFF".toByteArray())
        buffer.putInt(36 + dataSize)
        buffer.put("WAVE".toByteArray())
        buffer.put("fmt ".toByteArray())
        buffer.putInt(16)
        buffer.putShort(1)
        buffer.putShort(1)
        buffer.putInt(sampleRate)
        buffer.putInt(sampleRate * 2)
        buffer.putShort(2)
        buffer.putShort(16)
        buffer.put("data".toByteArray())
        buffer.putInt(dataSize)
        buffer.put(ByteArray(dataSize))
        return buffer.array()
    }

    private fun action(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(action).setPackage(context.packageName)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
        )
    }

    private var receiverRegistered = false

    private fun registerReceiver(context: Context) {
        if (receiverRegistered) {
            return
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_PLAY)
            addAction(ACTION_PAUSE)
            addAction(ACTION_NEXT)
            addAction(ACTION_PREV)
            addAction(ACTION_STOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(NovelTtsRemoteReceiver(), filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(NovelTtsRemoteReceiver(), filter)
        }
        receiverRegistered = true
    }

    private fun emit(method: String) {
        channel?.invokeMethod(method, null)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL,
                "Novel TTS",
                NotificationManager.IMPORTANCE_LOW,
            )
        )
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }
}

class NovelTtsRemoteReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        NovelTtsNowPlayingPlugin.dispatch(intent?.action)
    }
}
