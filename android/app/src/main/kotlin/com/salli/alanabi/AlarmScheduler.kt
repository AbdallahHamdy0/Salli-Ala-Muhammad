package com.salli.alanabi

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import kotlin.random.Random

/**
 * - تنبيه «صلِّ على محمد»: AlarmManager.setAlarmClock → أندرويد بيعتبره منبه ساعة،
 *   فبيصحّي الموبايل ويتخطى قيود Doze وتوفير الطاقة (باقي أنواع المنبهات بتتأخر لحد ~10 دقايق).
 *   (ده السبب في ظهور أيقونة منبه صغيرة في شريط الحالة.)
 * - أذكار الصباح والمساء + تذكيرها: نفس النوع (setAlarmClock) علشان توصل في ميعادها على كل الموبايلات.
 * - الأذكار العشوائية: منبه «exact» عادي (الدقة مش مهمة).
 */
object AlarmScheduler {
    const val TYPE_MORNING = "morning"
    const val TYPE_EVENING = "evening"

    private fun am(ctx: Context) = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    private fun salliPi(ctx: Context) = PendingIntent.getBroadcast(
        ctx, 1, Intent(ctx, AlarmReceiver::class.java).setAction(AlarmReceiver.ACTION_SALLI), FLAGS)

    /** منبه «تقريباً دقيق» (من غير أيقونة منبه): بيتخطى Doze لو الإذن متاح، وإلا بيرجع لأقرب بديل. */
    private fun setExact(ctx: Context, at: Long, pi: PendingIntent) {
        val a = am(ctx)
        try {
            when {
                Build.VERSION.SDK_INT >= 31 && !a.canScheduleExactAlarms() ->
                    a.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                Build.VERSION.SDK_INT >= 23 -> a.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                else -> a.setExact(AlarmManager.RTC_WAKEUP, at, pi)
            }
        } catch (_: SecurityException) {
            a.set(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    private fun adhkarPi(ctx: Context) = PendingIntent.getBroadcast(
        ctx, 2, Intent(ctx, AlarmReceiver::class.java).setAction(AlarmReceiver.ACTION_ADHKAR), FLAGS)

    fun scheduleSalli(ctx: Context, mode: ScheduleMode) {
        val p = Store.prefs(ctx)
        val interval = PlaybackPolicy.intervalMillis(p.getInt("intervalMinutes", Store.DEFAULT_INTERVAL_MIN))
        val next = PlaybackPolicy.nextTrigger(mode, p.getLong("nextAt", 0L), System.currentTimeMillis(), interval)
        val a = am(ctx)
        val pi = salliPi(ctx)
        val show = PendingIntent.getActivity(ctx, 3, Intent(ctx, MainActivity::class.java), FLAGS)
        try {
            a.setAlarmClock(AlarmManager.AlarmClockInfo(next, show), pi)
        } catch (_: SecurityException) {
            a.set(AlarmManager.RTC_WAKEUP, next, pi)
        }
        p.edit().putLong("nextAt", next).apply()
    }

    fun cancelSalli(ctx: Context) {
        am(ctx).cancel(salliPi(ctx))
        Store.prefs(ctx).edit().remove("nextAt").apply()
    }

    fun scheduleAdhkar(ctx: Context, mode: ScheduleMode) {
        val p = Store.prefs(ctx)
        val minutes = p.getInt("adhkarInterval", 30)
        val now = System.currentTimeMillis()
        val prev = p.getLong("adhkarNextAt", 0L)
        val next = if (mode == ScheduleMode.ENSURE && prev > now + 500) prev else {
            // «عشوائي» أكتر: ±10 دقايق على الفترات من ساعة فأكتر
            val jitter = if (minutes >= 60) Random.nextLong(-10 * 60_000L, 10 * 60_000L + 1) else 0L
            now + PlaybackPolicy.intervalMillis(minutes) + jitter
        }
        setExact(ctx, next, adhkarPi(ctx))
        p.edit().putLong("adhkarNextAt", next).apply()
    }

    fun cancelAdhkar(ctx: Context) {
        am(ctx).cancel(adhkarPi(ctx))
        Store.prefs(ctx).edit().remove("adhkarNextAt").apply()
    }

    // ---------------- أذكار الصباح والمساء (يومي) ----------------
    private fun dailyPi(ctx: Context, type: String, followUp: Boolean): PendingIntent {
        val code = (if (type == TYPE_MORNING) 11 else 12) + (if (followUp) 10 else 0)
        val action = if (followUp) AlarmReceiver.ACTION_FOLLOWUP else AlarmReceiver.ACTION_DAILY
        val i = Intent(ctx, AlarmReceiver::class.java).setAction(action).putExtra("type", type)
        return PendingIntent.getBroadcast(ctx, code, i, FLAGS)
    }

    /** الضغط على المنبه في ساعة الموبايل بيفتح صفحة الأذكار. */
    private fun dailyShowPi(ctx: Context, type: String): PendingIntent =
        PendingIntent.getActivity(
            ctx, if (type == TYPE_MORNING) 41 else 42,
            Intent(ctx, MainActivity::class.java).putExtra("adhkarType", type), FLAGS
        )

    /** منبه «ساعة» (setAlarmClock): أضمن نوع، بيصحّي الموبايل ويعدّي Doze وتوفير الطاقة. */
    private fun setClock(ctx: Context, at: Long, pi: PendingIntent, show: PendingIntent) {
        try {
            am(ctx).setAlarmClock(AlarmManager.AlarmClockInfo(at, show), pi)
        } catch (_: SecurityException) {
            setExact(ctx, at, pi)
        }
    }

    /** يجدول أقرب ميعاد (النهاردة لو لسه جاي، وإلا بكره) للنوع ده. */
    fun scheduleDaily(ctx: Context, type: String) {
        val p = Store.prefs(ctx)
        val hour = if (type == TYPE_MORNING) p.getInt("mH", 7) else p.getInt("eH", 19)
        val minute = if (type == TYPE_MORNING) p.getInt("mM", 30) else p.getInt("eM", 0)
        val at = PlaybackPolicy.nextDaily(System.currentTimeMillis(), hour, minute)
        setClock(ctx, at, dailyPi(ctx, type, false), dailyShowPi(ctx, type))
        Log.i("SalliDaily", "scheduled $type at ${java.util.Date(at)}")
    }

    fun scheduleDailyAll(ctx: Context) {
        scheduleDaily(ctx, TYPE_MORNING)
        scheduleDaily(ctx, TYPE_EVENING)
    }

    fun cancelDaily(ctx: Context) {
        for (t in listOf(TYPE_MORNING, TYPE_EVENING)) {
            am(ctx).cancel(dailyPi(ctx, t, false))
            am(ctx).cancel(dailyPi(ctx, t, true))
        }
    }

    /** تذكير واحد بعد دقايق (kDailyFollowUpMinutes) لو المستخدم ما فتحش الأذكار. 0 = بدون. */
    fun scheduleFollowUp(ctx: Context, type: String) {
        val minutes = Store.prefs(ctx).getInt("dailyFollowUp", 30)
        if (minutes <= 0) return
        val at = System.currentTimeMillis() + minutes * 60_000L
        setClock(ctx, at, dailyPi(ctx, type, true), dailyShowPi(ctx, type))
        Log.i("SalliDaily", "follow-up for $type in $minutes min")
    }

    fun cancelFollowUp(ctx: Context, type: String) {
        am(ctx).cancel(dailyPi(ctx, type, true))
    }
}
