package com.salli.alanabi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray

/** إشعار ذكر عشوائي (بدون صوت، بيظهر فوق الشاشة وبيفتح كارت جوه التطبيق لما تضغط عليه). */
object AdhkarNotifier {
    private const val CHANNEL = "salli_adhkar"
    private const val ID = 78
    private val fallback = listOf("أَسْتَغْفِرُ اللَّهَ", "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ سُبْحَانَ اللَّهِ الْعَظِيمِ")

    fun pick(ctx: Context): String {
        val raw = Store.prefs(ctx).getString("adhkarList", null)
        val list = try {
            val a = JSONArray(raw ?: "[]")
            List(a.length()) { a.getString(it) }.filter { it.isNotBlank() }
        } catch (_: Exception) { emptyList() }
        return (if (list.isEmpty()) fallback else list).random()
    }

    fun show(ctx: Context, text: String = pick(ctx)) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            val ch = NotificationChannel(CHANNEL, "أذكار", NotificationManager.IMPORTANCE_HIGH)
            ch.setSound(null, null)
            ch.enableVibration(false)
            nm.createNotificationChannel(ch)
        }
        val open = PendingIntent.getActivity(
            ctx, text.hashCode(),
            Intent(ctx, MainActivity::class.java).putExtra("dhikr", text)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CHANNEL) else Notification.Builder(ctx)
        if (Build.VERSION.SDK_INT < 26) b.setPriority(Notification.PRIORITY_HIGH)
        val n = b.setSmallIcon(R.drawable.ic_stat_salli)
            .setContentTitle("ذكر")
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try { nm.notify(ID, n) } catch (_: Exception) {}
    }
}
