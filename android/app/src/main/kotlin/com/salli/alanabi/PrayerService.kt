package com.salli.alanabi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder

/**
 * خدمة صغيرة وظيفتها الوحيدة: الاستماع لفتح قفل الشاشة (ACTION_USER_PRESENT) — أندرويد بيشترط إنها تتسجّل من خدمة شغالة.
 * التنبيه الدوري مش بيعدّي عليها خالص (بيروح لـ AlarmReceiver) فمفيش إشعار بيظهر مع كل تنبيه.
 * بتشتغل بس لما «التذكير» + «التفعيل عند فتح الشاشة» الاتنين مفعّلين.
 */
class PrayerService : Service() {

    companion object {
        const val CHANNEL_ID = "salli_service_v2"
        const val NOTIF_ID = 77

        /** بدء الخدمة بأمان (بعض الحالات في الخلفية ممكن أندرويد يرفضها → ما نكراشش). */
        fun start(ctx: Context) {
            try {
                val i = Intent(ctx, PrayerService::class.java)
                if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
            } catch (_: Exception) {}
        }

        fun stop(ctx: Context) {
            try { ctx.stopService(Intent(ctx, PrayerService::class.java)) } catch (_: Exception) {}
        }
    }

    private var unlockReceiver: BroadcastReceiver? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val n = buildNotification()
        if (Build.VERSION.SDK_INT >= 34) startForeground(NOTIF_ID, n, 1 shl 30) // SPECIAL_USE
        else startForeground(NOTIF_ID, n)

        val p = Store.prefs(this)
        if (!p.getBoolean("enabled", false) || !p.getBoolean("onUnlock", true)) {
            unregisterUnlock()
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }
        registerUnlock()
        return START_STICKY
    }

    private fun registerUnlock() {
        if (unlockReceiver != null) return
        unlockReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val p = Store.prefs(this@PrayerService)
                if (!p.getBoolean("enabled", false) || !p.getBoolean("onUnlock", true)) return
                SoundPlayer.play(this@PrayerService)
            }
        }
        registerReceiver(unlockReceiver, IntentFilter(Intent.ACTION_USER_PRESENT))
    }

    private fun unregisterUnlock() {
        unlockReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        unlockReceiver = null
    }

    private fun buildNotification(): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.deleteNotificationChannel("salli_channel") // القناة القديمة
            // MIN = إشعار صامت مصغّر بدون أيقونة في شريط الحالة
            val ch = NotificationChannel(CHANNEL_ID, "التذكير بالصلاة على النبي", NotificationManager.IMPORTANCE_MIN)
            ch.setSound(null, null)
            ch.setShowBadge(false)
            nm.createNotificationChannel(ch)
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        return b.setSmallIcon(R.drawable.ic_stat_salli)
            .setContentTitle("اللهم صلِّ وسلم على نبينا محمد")
            .setContentText("التذكير مفعّل")
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    override fun onDestroy() {
        unregisterUnlock()
        super.onDestroy()
    }
}
