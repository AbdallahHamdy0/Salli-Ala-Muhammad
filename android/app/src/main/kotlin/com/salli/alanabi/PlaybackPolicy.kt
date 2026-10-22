package com.salli.alanabi

enum class ScheduleMode { RESET, ADVANCE, ENSURE }

/** منطق القرارات (بدون أي اعتماد على أندرويد). */
object PlaybackPolicy {
    const val DEBOUNCE_MS = 3000L

    /** لو "التفعيل في الوضع الصامت" مفعّل يشتغل دايماً، لو مقفول يشتغل بس في الوضع العادي ومن غير DND. */
    fun shouldPlay(playInSilent: Boolean, ringerNormal: Boolean, dndOff: Boolean): Boolean =
        playInSilent || (ringerNormal && dndOff)

    fun isDebounced(now: Long, lastPlayAt: Long): Boolean =
        lastPlayAt != 0L && now - lastPlayAt < DEBOUNCE_MS

    fun intervalMillis(minutes: Int): Long = minutes.coerceAtLeast(1) * 60_000L

    fun shouldReschedule(oldEnabled: Boolean, newEnabled: Boolean, oldInterval: Int, newInterval: Int): Boolean =
        newEnabled && (!oldEnabled || oldInterval != newInterval)

    /**
     * RESET   : من الآن + الفترة.
     * ADVANCE : من الموعد السابق + الفترة (بدون تراكم تأخير)، وبيتخطى المواعيد الفايتة.
     * ENSURE  : يحافظ على الموعد الحالي لو لسه جاي، وإلا من الآن + الفترة.
     */
    fun nextTrigger(mode: ScheduleMode, prevNext: Long, now: Long, interval: Long): Long = when (mode) {
        ScheduleMode.RESET -> now + interval
        ScheduleMode.ADVANCE -> {
            if (prevNext <= 0L) now + interval
            else {
                var n = prevNext + interval
                if (n <= now + 500) n += ((now + 500 - n) / interval + 1) * interval
                n
            }
        }
        ScheduleMode.ENSURE -> if (prevNext > now + 500) prevNext else now + interval
    }

    /**
     * أقرب ميعاد يومي (ساعة:دقيقة) بعد [now] بتوقيت [tz]. لو الميعاد فات النهاردة → بكره.
     * GregorianCalendar بالذات (مش Calendar.getInstance) علشان تقويم لغة الجهاز ما يغيّرش الحساب.
     */
    fun nextDaily(now: Long, hour: Int, minute: Int, tz: java.util.TimeZone = java.util.TimeZone.getDefault()): Long {
        val c = java.util.GregorianCalendar(tz)
        c.timeInMillis = now
        c.set(java.util.Calendar.HOUR_OF_DAY, hour.coerceIn(0, 23))
        c.set(java.util.Calendar.MINUTE, minute.coerceIn(0, 59))
        c.set(java.util.Calendar.SECOND, 0)
        c.set(java.util.Calendar.MILLISECOND, 0)
        if (c.timeInMillis <= now + 1000) c.add(java.util.Calendar.DAY_OF_YEAR, 1)
        return c.timeInMillis
    }
}
