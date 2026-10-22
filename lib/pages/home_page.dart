import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../data/adhkar.dart';
import '../services/native_bridge.dart';
import '../theme.dart';
import '../widgets/dhikr_card.dart';
import '../widgets/glass_switch.dart';
import '../widgets/scene_background.dart';
import 'daily_adhkar_page.dart';
import 'settings_page.dart';

const Map<int, String> _intervals = {
  5: 'كل 5 دقائق',
  10: 'كل 10 دقائق',
  15: 'كل ربع ساعة',
  30: 'كل نصف ساعة',
  60: 'كل ساعة',
  120: 'كل ساعتين',
  180: 'كل 3 ساعات',
};

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  ReminderConfig _cfg = const ReminderConfig();

  // ---- إعداد الأذونات (مرة واحدة أول تشغيل) ----
  final Set<String> _tried = {};
  bool _setupRunning = false;
  bool _waitingReturn = false; // فتحنا شاشة نظام وبنستنى المستخدم يرجع
  bool _leftApp = false;
  Timer? _setupTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    _setupTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _init() async {
    await _load();
    await _checkDhikr();
    await _checkAdhkarRoute();
    await _maybeSetup();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDhikr();
      _checkAdhkarRoute();
      if (_waitingReturn && _leftApp) {
        _waitingReturn = false;
        _leftApp = false;
        _setupTimer?.cancel();
        _nextSetupStep();
      }
    } else if (_waitingReturn) {
      _leftApp = true;
    }
  }

  // ---------------- التحميل ----------------
  Future<void> _load() async {
    try {
      var c = await NativeBridge.getConfig();
      if (!_intervals.containsKey(c.intervalMinutes)) {
        // فترة قديمة (من التجارب) مش موجودة في القائمة → نرجع للافتراضي
        c = c.copyWith(intervalMinutes: kDefaultIntervalMinutes);
        await NativeBridge.setConfig(c);
      }
      if (mounted) setState(() => _cfg = c);
      await NativeBridge.setAdhkarList(kAdhkar);
      if (await NativeBridge.isAdhkarEnabled()) await NativeBridge.setAdhkar(true, kAdhkarIntervalMinutes);
      // لو غيّرت مواعيد أذكار الصباح/المساء في constants.dart تتطبّق هنا
      if (await NativeBridge.isDailyAdhkarEnabled()) await NativeBridge.setDailyAdhkar(true);
    } catch (_) {}
  }

  /// لو المستخدم فتح التطبيق من إشعار ذكر → نعرض الكارت.
  Future<void> _checkDhikr() async {
    try {
      final d = await NativeBridge.consumeDhikr();
      if (d != null && mounted) showDhikrCard(context, d);
    } catch (_) {}
  }

  /// لو المستخدم فتح التطبيق من إشعار أذكار الصباح/المساء → نفتح صفحة الأذكار.
  Future<void> _checkAdhkarRoute() async {
    try {
      final type = await NativeBridge.consumeAdhkarRoute();
      if (type != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DailyAdhkarPage(initialTab: type == 'evening' ? 1 : 0)),
        );
      }
    } catch (_) {}
  }

  Future<void> _apply(ReminderConfig c) async {
    setState(() => _cfg = c);
    try {
      await NativeBridge.setConfig(c);
    } catch (_) {}
  }

  // ---------------- الأذونات ----------------
  Future<List<String>> _missing() async => [
        if (!await NativeBridge.hasNotificationPermission()) 'notif',
        if (!await NativeBridge.canScheduleExact()) 'exact',
        if (!await NativeBridge.isIgnoringBattery()) 'battery',
      ];

  Future<void> _maybeSetup() async {
    try {
      if (await NativeBridge.isSetupDone()) return;
      if ((await _missing()).isEmpty) return NativeBridge.setSetupDone();
      if (!mounted) return;
      await _showSetupIntro();
      _setupRunning = true;
      await _nextSetupStep();
    } catch (_) {}
  }

  /// بيطلب أول إذن ناقص، ولما المستخدم يرجع من شاشة النظام بيكمل اللي بعده.
  Future<void> _nextSetupStep() async {
    if (!_setupRunning) return;
    try {
      for (final step in await _missing()) {
        if (!_tried.add(step)) continue; // كل إذن بنطلبه مرة واحدة بس
        _waitingReturn = true;
        _leftApp = false;
        _setupTimer?.cancel();
        // لو شاشة النظام ما ظهرتش (مثلاً الإذن مرفوض نهائياً) نكمل برضه
        _setupTimer = Timer(const Duration(seconds: 3), () {
          if (_waitingReturn && !_leftApp) {
            _waitingReturn = false;
            _nextSetupStep();
          }
        });
        switch (step) {
          case 'notif':
            await NativeBridge.requestNotificationPermission();
          case 'exact':
            await NativeBridge.openExactAlarmSettings();
          default:
            await NativeBridge.requestIgnoreBattery();
        }
        return;
      }
    } catch (_) {}
    _setupRunning = false;
    try {
      await NativeBridge.setSetupDone();
    } catch (_) {}
  }

  Future<void> _showSetupIntro() => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0B3A34),
            title: Text('تجهيز التطبيق', style: uiStyle(18, w: FontWeight.w700, color: AppColors.gold)),
            content: Text(
              'علشان التذكير يشتغل في ميعاده حتى والموبايل مقفول، محتاجين نسمح بـ:\n\n'
              '• الإشعارات\n• المنبهات الدقيقة\n• استثناء التطبيق من توفير البطارية\n\n'
              'هتظهرلك كل شاشة بالترتيب، وبتتطلب مرة واحدة بس.',
              style: uiStyle(15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('متابعة', style: uiStyle(16, color: AppColors.gold, w: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );

  // ---------------- الواجهة ----------------
  @override
  Widget build(BuildContext context) {
    final on = _cfg.enabled;
    return Scaffold(
      body: Stack(children: [
        SceneCanvas(
          childrenBuilder: (s) => [
            _verse(s),
            _reminderCard(s),
            _smallCard(s,
                left: 214,
                title: 'التفعيل عند',
                sub: 'فتح الشاشة',
                icon: Icons.phone_android_rounded,
                value: _cfg.onUnlock,
                onTap: () => _apply(_cfg.copyWith(onUnlock: !_cfg.onUnlock))),
            _smallCard(s,
                left: 522,
                title: 'التفعيل في',
                sub: 'الوضع الصامت',
                icon: Icons.volume_off_outlined,
                value: _cfg.playInSilent,
                onTap: () => _apply(_cfg.copyWith(playInSilent: !_cfg.playInSilent))),
            _bellButton(s, on),
            _statusLabel(s, on),
          ],
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
              child: IconButton(
                tooltip: 'الإعدادات',
                icon: const Icon(Icons.settings_outlined, color: AppColors.gold, size: 32),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ---------- الآية داخل القوس ----------
  Widget _verse(double s) => Stack(children: [
        Positioned(
          left: 250 * s, top: 250 * s, width: 524 * s, height: 340 * s,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final l in const [
                'إِنَّ اللَّهَ وَمَلَائِكَتَهُ',
                'يُصَلُّونَ عَلَى النَّبِيِّ',
                'يَا أَيُّهَا الَّذِينَ آمَنُوا صَلُّوا عَلَيْهِ',
                'وَسَلِّمُوا تَسْلِيمًا',
              ])
                Text(l, textAlign: TextAlign.center, style: quranStyle(54 * s)),
            ]),
          ),
        ),
        Positioned(
          left: 370 * s, top: 610 * s, width: 285 * s, height: 24 * s,
          child: Row(children: [
            Expanded(child: Container(height: 1, color: AppColors.goldSoft.withValues(alpha: .7))),
            SizedBox(width: 6 * s),
            Transform.rotate(angle: .785, child: Container(width: 14 * s, height: 14 * s, color: AppColors.gold)),
            SizedBox(width: 6 * s),
            Expanded(child: Container(height: 1, color: AppColors.goldSoft.withValues(alpha: .7))),
          ]),
        ),
        Positioned(
          left: 300 * s, top: 632 * s, width: 424 * s, height: 40 * s,
          child: Center(child: Text('الأحزاب - 56', style: uiStyle(30 * s, color: AppColors.goldSoft))),
        ),
      ]);

  // ---------- كارت التذكير الصوتي ----------
  Widget _reminderCard(double s) => Positioned(
        left: 214 * s, top: 845 * s, width: 596 * s, height: 178 * s,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('التذكير الصوتي', style: uiStyle(math.max(13.0, 34 * s), w: FontWeight.w600)),
            SizedBox(width: 12 * s),
            Icon(Icons.notifications_rounded, color: AppColors.gold, size: 40 * s),
          ]),
          SizedBox(height: 14 * s),
          PopupMenuButton<int>(
            color: const Color(0xFF0B3A34),
            offset: Offset(0, 60 * s),
            onSelected: (v) => _apply(_cfg.copyWith(intervalMinutes: v)),
            itemBuilder: (_) => [
              for (final e in _intervals.entries)
                PopupMenuItem<int>(
                  value: e.key,
                  child: Text(e.value,
                      style: uiStyle(16, color: e.key == _cfg.intervalMinutes ? AppColors.gold : AppColors.cream)),
                ),
            ],
            child: Container(
              width: 500 * s, height: math.max(40.0, 72 * s),
              padding: EdgeInsets.symmetric(horizontal: 28 * s),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(60 * s),
                color: const Color(0x2214564A),
                border: Border.all(color: const Color(0x8845A58E), width: 1.2),
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(children: [
                  Icon(Icons.schedule_rounded, color: AppColors.gold, size: 40 * s),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(_intervals[_cfg.intervalMinutes] ?? '',
                            textDirection: TextDirection.rtl, style: uiStyle(math.max(12.0, 32 * s))),
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.gold, size: 44 * s),
                ]),
              ),
            ),
          ),
        ]),
          ),
        ),
      );

  // ---------- الكروت الصغيرة ----------
  Widget _smallCard(double s,
      {required double left,
      required String title,
      required String sub,
      required IconData icon,
      required bool value,
      required VoidCallback onTap}) {
    return Positioned(
      left: left * s, top: 1052 * s, width: 288 * s, height: 142 * s,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 8 * s),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: uiStyle(math.max(12.0, 28 * s), w: FontWeight.w600)),
                  Text(sub, style: uiStyle(math.max(11.0, 24 * s), color: AppColors.cream.withValues(alpha: .8))),
                ]),
                SizedBox(width: 14 * s),
                Icon(icon, color: AppColors.gold, size: 52 * s),
              ]),
              SizedBox(height: 10 * s),
              GlassSwitch(value: value, width: 92 * s, height: 48 * s),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------- زرار الجرس الرئيسي (فوق الحلقة الذهبية في الخلفية: مركزها 510،1322 ونص قطرها ~96) ----------
  Widget _bellButton(double s, bool on) => Positioned(
        left: (510 - 96) * s, top: (1322 - 96) * s, width: 192 * s, height: 192 * s,
        child: GestureDetector(
          onTap: () => _apply(_cfg.copyWith(enabled: !_cfg.enabled)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? Colors.transparent : const Color(0xB3021F1C),
            ),
            child: Icon(
              on ? Icons.notifications_none_rounded : Icons.notifications_off_outlined,
              size: 86 * s,
              color: on ? AppColors.gold : AppColors.goldSoft.withValues(alpha: .6),
            ),
          ),
        ),
      );

  // ---------- الحالة تحت الحلقة (الحلقة بتنتهي عند y≈1418 فبنبدأ من 1440 علشان ما تتراكبش) ----------
  Widget _statusLabel(double s, bool on) => Positioned(
        left: 300 * s, top: 1440 * s, width: 424 * s, height: 50 * s,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 44 * s, height: 1.2, color: AppColors.goldSoft),
            SizedBox(width: 24 * s),
            Text(on ? 'التذكير مفعل' : 'التذكير معطل',
                style: uiStyle(34 * s, color: on ? AppColors.gold : AppColors.goldSoft.withValues(alpha: .6), w: FontWeight.w600)),
            SizedBox(width: 24 * s),
            Container(width: 44 * s, height: 1.2, color: AppColors.goldSoft),
          ]),
        ),
      );
}
