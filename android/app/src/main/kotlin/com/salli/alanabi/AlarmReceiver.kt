package com.salli.alanabi

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_SALLI = "com.salli.alanabi.ALARM_SALLI"
        const val ACTION_ADHKAR = "com.salli.alanabi.ALARM_ADHKAR"
        const val ACTION_DAILY = "com.salli.alanabi.ALARM_DAILY"
        const val ACTION_FOLLOWUP = "com.salli.alanabi.ALARM_FOLLOWUP"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val p = Store.prefs(context)
        when (intent.action) {
            ACTION_SALLI -> {
                if (!p.getBoolean("enabled", false)) return
                val scheduledAt = p.getLong("nextAt", 0L)
                Log.i("SalliAlarm", "fired driftMs=${if (scheduledAt > 0) System.currentTimeMillis() - scheduledAt else -1}")
                // أول حاجة: جدول الجاي (علشان السلسلة ما تقطعش حتى لو الصوت فشل)
                AlarmScheduler.scheduleSalli(context, ScheduleMode.ADVANCE)
                val pending = goAsync()
                val finished = AtomicBoolean(false)
                fun finishOnce() {
                    if (finished.compareAndSet(false, true)) {
                        try { pending.finish() } catch (_: Exception) {}
                    }
                }
                try { SoundPlayer.play(context) { finishOnce() } } catch (_: Exception) { finishOnce() }
            }
            ACTION_ADHKAR -> {
                if (!p.getBoolean("adhkarEnabled", false)) return
                AdhkarNotifier.show(context)
                AlarmScheduler.scheduleAdhkar(context, ScheduleMode.RESET)
            }
            ACTION_DAILY -> {
                if (!p.getBoolean("dailyEnabled", false)) return
                val type = intent.getStringExtra("type") ?: return
                Log.i("SalliDaily", "fired type=$type")
                AlarmScheduler.scheduleDaily(context, type) // ميعاد بكره (أول حاجة علشان السلسلة ما تقطعش)
                if (p.getString("seen_$type", "") == Store.today()) return // قراها النهاردة خلاص
                DailyAdhkarNotifier.show(context, type, followUp = false)
                AlarmScheduler.scheduleFollowUp(context, type)
            }
            ACTION_FOLLOWUP -> {
                if (!p.getBoolean("dailyEnabled", false)) return
                val type = intent.getStringExtra("type") ?: return
                if (p.getString("seen_$type", "") == Store.today()) return
                Log.i("SalliDaily", "follow-up type=$type")
                DailyAdhkarNotifier.show(context, type, followUp = true)
            }
        }
    }
}
