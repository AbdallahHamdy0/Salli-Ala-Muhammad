package com.salli.alanabi

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * - إعادة التشغيل / تحديث التطبيق: كل المنبهات بتتمسح، فبنجدولها تاني.
 * - تغيير الوقت أو المنطقة الزمنية: أذكار الصباح والمساء بس (لأن ميعادها ساعة محددة).
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val p = Store.prefs(context)
        Log.i("SalliBoot", "received ${intent.action} enabled=${p.getBoolean("enabled", false)} adhkar=${p.getBoolean("adhkarEnabled", false)} daily=${p.getBoolean("dailyEnabled", false)}")

        val fullRestore = intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        if (fullRestore) {
            if (p.getBoolean("enabled", false)) {
                AlarmScheduler.scheduleSalli(context, ScheduleMode.RESET)
                if (p.getBoolean("onUnlock", true)) PrayerService.start(context)
            }
            if (p.getBoolean("adhkarEnabled", false)) AlarmScheduler.scheduleAdhkar(context, ScheduleMode.RESET)
        }
        if (p.getBoolean("dailyEnabled", false)) AlarmScheduler.scheduleDailyAll(context)
    }
}
