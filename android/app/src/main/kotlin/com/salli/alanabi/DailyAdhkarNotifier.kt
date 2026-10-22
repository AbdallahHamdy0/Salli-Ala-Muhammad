package com.salli.alanabi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/** إشعار أذكار الصباح / المساء (بصوت الإشعارات الافتراضي). الضغط عليه بيفتح صفحة الأذكار. */
object DailyAdhkarNotifier {
    private const val CHANNEL = "salli_daily_adhkar"

    /** رقم واحد لكل نوع (80 صباح / 81 مساء): تذكير المتابعة بيحل مكان الإشعار الأصلي (إشعار واحد بس). */
    private fun id(type: String) = if (type == AlarmScheduler.TYPE_MORNING) 80 else 81

    fun show(ctx: Context, type: String, followUp: Boolean) {
        val morning = type == AlarmScheduler.TYPE_MORNING
        val title = if (morning) "أذكار الصباح" else "أذكار المساء"
        val body = when {
            followUp && morning -> "تذكير: لسه ما قرأت أذكار الصباح"
            followUp -> "تذكير: لسه ما قرأت أذكار المساء"
            morning -> "حان وقت أذكار الصباح، اضغط للقراءة"
            else -> "حان وقت أذكار المساء، اضغط للقراءة"
        }
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "أذكار الصباح والمساء", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val open = Intent(ctx, MainActivity::class.java)
            .putExtra("adhkarType", type)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pi = PendingIntent.getActivity(
            ctx, if (morning) 31 else 32, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CHANNEL) else Notification.Builder(ctx)
        b.setSmallIcon(R.drawable.ic_stat_salli)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setContentIntent(pi)
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT < 26) b.setDefaults(Notification.DEFAULT_SOUND)
        try { nm.notify(id(type), b.build()) } catch (_: SecurityException) {}
    }

    /** لما المستخدم يفتح الأذكار: نشيل الإشعار. */
    fun cancel(ctx: Context, type: String) {
        try {
            (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id(type))
        } catch (_: Exception) {}
    }
}
