package com.salli.alanabi

import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock

/**
 * تشغيل الصوت على قناة المنبه (ALARM) → يتخطى الوضع الصامت، ويعدّي «عدم الإزعاج» لو المنبهات مسموحة.
 * بياخد WakeLock أثناء التشغيل علشان الموبايل ما ينامش قبل ما الصوت يخلص (قفل الشاشة / Doze).
 */
object SoundPlayer {
    private const val MAX_MS = 9000L // حد أقصى لعمر الـ receiver
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastPlayAt = 0L
    private var onDone: (() -> Unit)? = null
    private var audio: AudioManager? = null
    private var hasFocus = false
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finish() }

    /** @return true لو الصوت اتشغّل فعلاً. onDone بيتنادى مرة واحدة دايماً. */
    @Suppress("DEPRECATION")
    fun play(ctx: Context, onDone: () -> Unit = {}): Boolean {
        val app = ctx.applicationContext
        val now = SystemClock.elapsedRealtime()
        if (PlaybackPolicy.isDebounced(now, lastPlayAt)) { onDone(); return false }

        val p = Store.prefs(app)
        val am = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val nm = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val ok = PlaybackPolicy.shouldPlay(
            playInSilent = p.getBoolean("playInSilent", true),
            ringerNormal = am.ringerMode == AudioManager.RINGER_MODE_NORMAL,
            dndOff = Build.VERSION.SDK_INT < 23 ||
                nm.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL,
        )
        if (!ok) { onDone(); return false }

        finish() // لو في تشغيل سابق شغال
        lastPlayAt = now
        this.onDone = onDone

        try {
            val pm = app.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "salli:play").apply { acquire(MAX_MS + 2000) }
        } catch (_: Exception) {}

        val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        if (am.getStreamVolume(AudioManager.STREAM_ALARM) == 0) {
            try { am.setStreamVolume(AudioManager.STREAM_ALARM, (max * 0.4).toInt().coerceAtLeast(1), 0) } catch (_: Exception) {}
        }
        audio = am
        try {
            hasFocus = am.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK) ==
                AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } catch (_: Exception) {}

        try {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val mp = MediaPlayer.create(app, R.raw.salli_ala_muhammad, attrs, am.generateAudioSessionId())
            if (mp == null) { finish(); return false }
            player = mp
            mp.setOnCompletionListener { finish() }
            mp.setOnErrorListener { _, _, _ -> finish(); true }
            mp.start()
            handler.postDelayed(timeout, MAX_MS)
        } catch (_: Exception) {
            finish(); return false
        }
        return true
    }

    @Suppress("DEPRECATION")
    private fun finish() {
        handler.removeCallbacks(timeout)
        // نرجّع تركيز الصوت علشان أي موسيقى شغالة ترجع لمستواها الطبيعي
        if (hasFocus) { try { audio?.abandonAudioFocus(null) } catch (_: Exception) {} }
        hasFocus = false
        audio = null
        try { player?.release() } catch (_: Exception) {}
        player = null
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
        wakeLock = null
        val cb = onDone
        onDone = null
        cb?.invoke()
    }
}
