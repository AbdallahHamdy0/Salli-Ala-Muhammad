package com.salli.alanabi

import android.content.Context

object Store {
    const val PREFS = "salli_prefs"

    /** الفترة الافتراضية للتذكير الصوتي (بالدقايق) لو المستخدم ما اختارش. */
    const val DEFAULT_INTERVAL_MIN = 15
    fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * القيم الافتراضية: التذكير الصوتي، الأذكار العشوائية، وأذكار الصباح والمساء كلها «مفعّلة».
     * بتتطبّق بس على اللي المستخدم ما اختارش فيه قبل كده (اختياره الأول بيفضل زي ما هو).
     */
    fun applyDefaults(ctx: Context) {
        val p = prefs(ctx)
        val e = p.edit()
        for (k in listOf("enabled", "adhkarEnabled", "dailyEnabled")) {
            if (!p.contains(k)) e.putBoolean(k, true)
        }
        e.apply()
    }

    /** تاريخ النهاردة بتوقيت الجهاز (yyyy-MM-dd). */
    fun today(): String = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
}
