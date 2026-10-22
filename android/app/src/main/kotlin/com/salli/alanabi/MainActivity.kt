package com.salli.alanabi

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val channel = "salli/native"
    private var pendingDhikr: String? = null
    private var pendingAdhkarRoute: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        Store.applyDefaults(this) // أول تشغيل: كل التنبيهات مفعّلة
        // كل مرة التطبيق يفتح: نتأكد إن المنبهات موجودة (بتتمسح لو التطبيق اتعمله Force Stop)
        val p = Store.prefs(this)
        if (p.getBoolean("enabled", false)) {
            AlarmScheduler.scheduleSalli(this, ScheduleMode.ENSURE)
            syncService(true, p.getBoolean("onUnlock", true))
        }
        if (p.getBoolean("adhkarEnabled", false)) AlarmScheduler.scheduleAdhkar(this, ScheduleMode.ENSURE)
        if (p.getBoolean("dailyEnabled", false)) AlarmScheduler.scheduleDailyAll(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    /** فتح التطبيق من إشعار: ذكر عشوائي (كارت) أو أذكار الصباح/المساء (صفحة). */
    private fun handleIntent(i: Intent?) {
        i?.getStringExtra("dhikr")?.let { pendingDhikr = it }
        i?.getStringExtra("adhkarType")?.let { type ->
            if (type == AlarmScheduler.TYPE_MORNING || type == AlarmScheduler.TYPE_EVENING) {
                pendingAdhkarRoute = type
                markSeen(type)
            }
        }
    }

    /** المستخدم فتح الأذكار: نلغي الإشعار وتذكير المتابعة ونسجّل إنه قراها النهاردة. */
    private fun markSeen(type: String) {
        Store.prefs(this).edit().putString("seen_$type", Store.today()).apply()
        AlarmScheduler.cancelFollowUp(this, type)
        DailyAdhkarNotifier.cancel(this, type)
    }

    private fun syncService(enabled: Boolean, onUnlock: Boolean) {
        if (enabled && onUnlock) PrayerService.start(this) else PrayerService.stop(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            val p = Store.prefs(this)
            when (call.method) {
                // ---------- التذكير ----------
                "getConfig" -> result.success(
                    mapOf(
                        "enabled" to p.getBoolean("enabled", false),
                        "intervalMinutes" to p.getInt("intervalMinutes", Store.DEFAULT_INTERVAL_MIN),
                        "onUnlock" to p.getBoolean("onUnlock", true),
                        "playInSilent" to p.getBoolean("playInSilent", true),
                    )
                )
                "setConfig" -> {
                    val oldEnabled = p.getBoolean("enabled", false)
                    val oldInterval = p.getInt("intervalMinutes", Store.DEFAULT_INTERVAL_MIN)
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val interval = call.argument<Int>("intervalMinutes") ?: Store.DEFAULT_INTERVAL_MIN
                    val onUnlock = call.argument<Boolean>("onUnlock") ?: true
                    p.edit()
                        .putBoolean("enabled", enabled)
                        .putInt("intervalMinutes", interval)
                        .putBoolean("onUnlock", onUnlock)
                        .putBoolean("playInSilent", call.argument<Boolean>("playInSilent") ?: true)
                        .apply()
                    if (enabled) {
                        val mode = if (PlaybackPolicy.shouldReschedule(oldEnabled, enabled, oldInterval, interval))
                            ScheduleMode.RESET else ScheduleMode.ENSURE
                        AlarmScheduler.scheduleSalli(this, mode)
                    } else AlarmScheduler.cancelSalli(this)
                    syncService(enabled, onUnlock)
                    result.success(true)
                }

                // ---------- الأذكار ----------
                "setAdhkarList" -> {
                    val list = call.argument<List<String>>("list") ?: emptyList()
                    p.edit().putString("adhkarList", JSONArray(list).toString()).apply()
                    result.success(true)
                }
                "isAdhkarEnabled" -> result.success(p.getBoolean("adhkarEnabled", false))
                "setAdhkar" -> {
                    val oldEnabled = p.getBoolean("adhkarEnabled", false)
                    val oldInterval = p.getInt("adhkarInterval", 30)
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val interval = call.argument<Int>("intervalMinutes") ?: 30
                    p.edit().putBoolean("adhkarEnabled", enabled).putInt("adhkarInterval", interval).apply()
                    if (enabled) {
                        val mode = if (PlaybackPolicy.shouldReschedule(oldEnabled, enabled, oldInterval, interval))
                            ScheduleMode.RESET else ScheduleMode.ENSURE
                        AlarmScheduler.scheduleAdhkar(this, mode)
                    } else AlarmScheduler.cancelAdhkar(this)
                    result.success(true)
                }
                "consumeDhikr" -> { result.success(pendingDhikr); pendingDhikr = null }

                // ---------- أذكار الصباح والمساء ----------
                "setDailyAdhkar" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    p.edit()
                        .putBoolean("dailyEnabled", enabled)
                        .putInt("mH", call.argument<Int>("morningHour") ?: 7)
                        .putInt("mM", call.argument<Int>("morningMinute") ?: 30)
                        .putInt("eH", call.argument<Int>("eveningHour") ?: 19)
                        .putInt("eM", call.argument<Int>("eveningMinute") ?: 0)
                        .putInt("dailyFollowUp", call.argument<Int>("followUpMinutes") ?: 30)
                        .apply()
                    if (enabled) AlarmScheduler.scheduleDailyAll(this)
                    else {
                        AlarmScheduler.cancelDaily(this)
                        DailyAdhkarNotifier.cancel(this, AlarmScheduler.TYPE_MORNING)
                        DailyAdhkarNotifier.cancel(this, AlarmScheduler.TYPE_EVENING)
                    }
                    result.success(true)
                }
                "isDailyAdhkarEnabled" -> result.success(p.getBoolean("dailyEnabled", false))
                "consumeAdhkarRoute" -> { result.success(pendingAdhkarRoute); pendingAdhkarRoute = null }
                "markSessionSeen" -> {
                    val t = call.argument<String>("type")
                    if (t == AlarmScheduler.TYPE_MORNING || t == AlarmScheduler.TYPE_EVENING) markSeen(t)
                    result.success(true)
                }
                // تخزين بسيط لتقدّم العدّادات (مفاتيح ui_ بس)
                "getPref" -> {
                    val k = call.argument<String>("key") ?: ""
                    result.success(if (k.startsWith("ui_")) p.getString(k, null) else null)
                }
                "setPref" -> {
                    val k = call.argument<String>("key") ?: ""
                    if (k.startsWith("ui_")) p.edit().putString(k, call.argument<String>("value")).apply()
                    result.success(true)
                }

                // ---------- المشاركة ----------
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
                    try {
                        startActivity(Intent.createChooser(send, null))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("share_failed", e.message, null)
                    }
                }

                // ---------- الأذونات ----------
                "hasNotificationPermission" -> result.success(
                    Build.VERSION.SDK_INT < 33 ||
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                )
                "notificationsEnabled" -> {
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val allowed = Build.VERSION.SDK_INT < 33 ||
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                    result.success(allowed && nm.areNotificationsEnabled())
                }
                "openNotificationSettings" -> {
                    openFirst(
                        listOf(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                            appDetails()
                        )
                    )
                    result.success(true)
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100)
                    result.success(true)
                }
                "canScheduleExact" -> {
                    val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    result.success(Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms())
                }
                "openExactAlarmSettings" -> {
                    openFirst(
                        listOf(
                            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")),
                            appDetails()
                        )
                    )
                    result.success(true)
                }
                "isIgnoringBattery" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestIgnoreBattery" -> {
                    openFirst(
                        listOf(
                            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")),
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                            appDetails()
                        )
                    )
                    result.success(true)
                }
                "isSetupDone" -> result.success(p.getBoolean("setupDone", false))
                "setSetupDone" -> { p.edit().putBoolean("setupDone", true).apply(); result.success(true) }

                else -> result.notImplemented()
            }
        }
    }

    private fun appDetails() =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))

    /** يجرّب الـ Intents بالترتيب لحد ما واحد يشتغل (بعض الشركات بتشيل بعض الشاشات). */
    private fun openFirst(intents: List<Intent>) {
        for (i in intents) {
            try { startActivity(i); return } catch (_: Exception) {}
        }
    }
}
