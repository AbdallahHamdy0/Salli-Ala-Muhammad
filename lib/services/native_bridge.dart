import 'package:flutter/services.dart';
import '../constants.dart';

class ReminderConfig {
  final bool enabled;
  final int intervalMinutes;
  final bool onUnlock;
  final bool playInSilent;

  const ReminderConfig({
    this.enabled = false,
    this.intervalMinutes = kDefaultIntervalMinutes,
    this.onUnlock = true,
    this.playInSilent = true,
  });

  ReminderConfig copyWith({bool? enabled, int? intervalMinutes, bool? onUnlock, bool? playInSilent}) =>
      ReminderConfig(
        enabled: enabled ?? this.enabled,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        onUnlock: onUnlock ?? this.onUnlock,
        playInSilent: playInSilent ?? this.playInSilent,
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'intervalMinutes': intervalMinutes,
        'onUnlock': onUnlock,
        'playInSilent': playInSilent,
      };

  factory ReminderConfig.fromMap(Map m) => ReminderConfig(
        enabled: m['enabled'] as bool? ?? false,
        intervalMinutes: m['intervalMinutes'] as int? ?? kDefaultIntervalMinutes,
        onUnlock: m['onUnlock'] as bool? ?? true,
        playInSilent: m['playInSilent'] as bool? ?? true,
      );
}

class NativeBridge {
  static const _ch = MethodChannel('salli/native');

  // ---- التذكير ----
  static Future<ReminderConfig> getConfig() async {
    final m = await _ch.invokeMethod<Map>('getConfig');
    return m == null ? const ReminderConfig() : ReminderConfig.fromMap(m);
  }

  static Future<void> setConfig(ReminderConfig c) => _ch.invokeMethod('setConfig', c.toMap());

  // ---- الأذكار ----
  static Future<void> setAdhkarList(List<String> l) => _ch.invokeMethod('setAdhkarList', {'list': l});
  static Future<bool> isAdhkarEnabled() async => (await _ch.invokeMethod<bool>('isAdhkarEnabled')) ?? false;
  static Future<void> setAdhkar(bool enabled, int minutes) =>
      _ch.invokeMethod('setAdhkar', {'enabled': enabled, 'intervalMinutes': minutes});
  static Future<String?> consumeDhikr() => _ch.invokeMethod<String>('consumeDhikr');

  // ---- أذكار الصباح والمساء ----
  static Future<bool> isDailyAdhkarEnabled() async =>
      (await _ch.invokeMethod<bool>('isDailyAdhkarEnabled')) ?? false;
  static Future<void> setDailyAdhkar(bool enabled) => _ch.invokeMethod('setDailyAdhkar', {
        'enabled': enabled,
        'morningHour': kMorningHour,
        'morningMinute': kMorningMinute,
        'eveningHour': kEveningHour,
        'eveningMinute': kEveningMinute,
        'followUpMinutes': kDailyFollowUpMinutes,
      });
  /// 'morning' / 'evening' لو التطبيق اتفتح من إشعار الأذكار.
  static Future<String?> consumeAdhkarRoute() => _ch.invokeMethod<String>('consumeAdhkarRoute');
  /// المستخدم فتح الأذكار → نلغي الإشعار وتذكير المتابعة.
  static Future<void> markSessionSeen(String type) => _ch.invokeMethod('markSessionSeen', {'type': type});

  // ---- تخزين بسيط (مفاتيح بتبدأ بـ ui_) ----
  static Future<String?> getPref(String key) => _ch.invokeMethod<String>('getPref', {'key': key});
  static Future<void> setPref(String key, String value) => _ch.invokeMethod('setPref', {'key': key, 'value': value});

  // ---- المشاركة ----
  static Future<void> shareText(String text) => _ch.invokeMethod('shareText', {'text': text});

  // ---- الأذونات (بتتطلب مرة واحدة أول تشغيل) ----
  static Future<bool> hasNotificationPermission() async =>
      (await _ch.invokeMethod<bool>('hasNotificationPermission')) ?? true;
  /// الإشعارات شغالة للتطبيق (الإذن + إعدادات النظام)؟
  static Future<bool> notificationsEnabled() async => (await _ch.invokeMethod<bool>('notificationsEnabled')) ?? true;
  static Future<void> openNotificationSettings() => _ch.invokeMethod('openNotificationSettings');
  static Future<void> requestNotificationPermission() => _ch.invokeMethod('requestNotificationPermission');
  static Future<bool> canScheduleExact() async => (await _ch.invokeMethod<bool>('canScheduleExact')) ?? true;
  static Future<void> openExactAlarmSettings() => _ch.invokeMethod('openExactAlarmSettings');
  static Future<bool> isIgnoringBattery() async => (await _ch.invokeMethod<bool>('isIgnoringBattery')) ?? true;
  static Future<void> requestIgnoreBattery() => _ch.invokeMethod('requestIgnoreBattery');
  static Future<bool> isSetupDone() async => (await _ch.invokeMethod<bool>('isSetupDone')) ?? true;
  static Future<void> setSetupDone() => _ch.invokeMethod('setSetupDone');
}
