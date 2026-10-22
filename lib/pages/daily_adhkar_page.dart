import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../data/azkar_daily.dart';
import '../services/native_bridge.dart';
import '../theme.dart';
import '../widgets/glass_switch.dart';
import '../widgets/simple_scaffold.dart';

/// أذكار الصباح والمساء: كل ذكر ليه عدّاد (بيقل مع كل ضغطة) وسهم لإعادته.
/// تقدّمك بيتحفظ لنفس اليوم، وبيبدأ من جديد تلقائياً في اليوم التالي.
class DailyAdhkarPage extends StatefulWidget {
  /// 0 = الصباح، 1 = المساء، وبدون تحديد: حسب الوقت (قبل 3 العصر = صباح).
  final int? initialTab;
  const DailyAdhkarPage({super.key, this.initialTab});

  @override
  State<DailyAdhkarPage> createState() => _DailyAdhkarPageState();
}

class _DailyAdhkarPageState extends State<DailyAdhkarPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs;
  bool _reminder = false;
  bool _notifOk = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotifications();
    final start = widget.initialTab ?? (DateTime.now().hour < 15 ? 0 : 1);
    _tabs = TabController(length: 2, vsync: this, initialIndex: start);
    NativeBridge.isDailyAdhkarEnabled().then((v) {
      if (mounted) setState(() => _reminder = v);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    super.dispose();
  }

  // بعد الرجوع من إعدادات الموبايل نعيد الفحص
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    try {
      final ok = await NativeBridge.notificationsEnabled();
      if (mounted) setState(() => _notifOk = ok);
    } catch (_) {}
  }

  Future<void> _toggleReminder() async {
    final v = !_reminder;
    setState(() => _reminder = v);
    try {
      if (v) await NativeBridge.requestNotificationPermission();
      await NativeBridge.setDailyAdhkar(v);
    } catch (_) {}
  }

  String get _reminderSubtitle {
    final base = 'الصباح ${formatClock(kMorningHour, kMorningMinute)} • المساء ${formatClock(kEveningHour, kEveningMinute)}';
    return kDailyFollowUpMinutes > 0 ? '$base • وتذكير بعد $kDailyFollowUpMinutes دقيقة' : base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A4A44),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text('أذكار الصباح والمساء', style: uiStyle(20, color: AppColors.gold, w: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white60,
          dividerColor: Colors.transparent,
          labelStyle: uiStyle(16, w: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.wb_sunny_rounded), text: 'أذكار الصباح'),
            Tab(icon: Icon(Icons.nights_stay_rounded), text: 'أذكار المساء'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A4A44), Color(0xFF042B28), AppColors.deep],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GlassTile(
                icon: Icons.notifications_active_rounded,
                title: 'تنبيه يومي بالأذكار',
                subtitle: _reminderSubtitle,
                onTap: _toggleReminder,
                trailing: GlassSwitch(value: _reminder, width: 52, height: 30),
              ),
            ),
            if (!_notifOk)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                decoration: BoxDecoration(
                  color: const Color(0x22FFB74D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: .6)),
                ),
                child: Row(children: [
                  const Icon(Icons.notifications_off_rounded, color: Colors.orangeAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('الإشعارات مقفولة للتطبيق من إعدادات الموبايل، فالتنبيهات مش هتظهر.',
                        style: uiStyle(13, color: Colors.orangeAccent)),
                  ),
                  TextButton(
                    onPressed: () => NativeBridge.openNotificationSettings(),
                    child: Text('فتح الإعدادات', style: uiStyle(13, color: AppColors.gold, w: FontWeight.w700)),
                  ),
                ]),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _AdhkarList(type: 'morning', items: kMorningAdhkar),
                  _AdhkarList(type: 'evening', items: kEveningAdhkar),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AdhkarList extends StatefulWidget {
  final String type;
  final List<DailyDhikr> items;
  const _AdhkarList({required this.type, required this.items});

  @override
  State<_AdhkarList> createState() => _AdhkarListState();
}

class _AdhkarListState extends State<_AdhkarList> {
  late List<int> _left = [for (final d in widget.items) d.count];
  bool _readSent = false;

  String get _key => 'ui_adhkar_${widget.type}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    try {
      final raw = await NativeBridge.getPref(_key);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final r = (m['r'] as List).cast<int>();
      if (m['d'] != _today() || r.length != widget.items.length) return; // يوم جديد → من الأول
      for (var i = 0; i < r.length; i++) {
        if (r[i] < 0 || r[i] > widget.items[i].count) return;
      }
      if (mounted) setState(() => _left = List<int>.of(r));
    } catch (_) {}
  }

  void _save() => NativeBridge.setPref(_key, jsonEncode({'d': _today(), 'r': _left})).catchError((_) {});

  void _tap(int i) {
    if (_left[i] <= 0) return;
    if (!_readSent) {
      // أول ضغطة = بدأ يقرأ فعلاً: نلغي إشعار/تذكير النهاردة (فتح الصفحة لوحده ما بيحسبش)
      _readSent = true;
      NativeBridge.markSessionSeen(widget.type).catchError((_) {});
    }
    setState(() => _left[i]--);
    if (_left[i] == 0) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    _save();
  }

  void _reset(int i) {
    setState(() => _left[i] = widget.items[i].count);
    HapticFeedback.lightImpact();
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    final done = _left.where((x) => x == 0).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(children: [
          Text(done == n ? 'تقبّل الله طاعتك' : 'تم $done من $n',
              style: uiStyle(14, color: done == n ? AppColors.green : AppColors.goldSoft, w: FontWeight.w700)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: n == 0 ? 0 : done / n,
                minHeight: 6,
                backgroundColor: const Color(0x22FFFFFF),
                color: done == n ? AppColors.green : AppColors.gold,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        for (var i = 0; i < n; i++)
          _DhikrCard(
            key: ValueKey('${widget.type}_$i'),
            id: '${widget.type}_$i',
            item: widget.items[i],
            left: _left[i],
            onTap: () => _tap(i),
            onReset: () => _reset(i),
          ),
      ],
    );
  }
}

String _times(int n) {
  if (n == 1) return 'مرة واحدة';
  if (n == 2) return 'مرتان';
  return n <= 10 ? '$n مرات' : '$n مرة';
}

class _DhikrCard extends StatelessWidget {
  final String id;
  final DailyDhikr item;
  final int left;
  final VoidCallback onTap;
  final VoidCallback onReset;
  const _DhikrCard({super.key, required this.id, required this.item, required this.left, required this.onTap, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final done = left == 0;
    return Opacity(
      opacity: done ? .6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: done ? AppColors.green.withValues(alpha: .6) : const Color(0x66E6BE6E)),
        ),
        child: Column(children: [
          if (item.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(item.title!, style: uiStyle(14, color: AppColors.goldSoft, w: FontWeight.w700)),
            ),
          Text(item.text, textAlign: TextAlign.center, style: quranStyle(item.text.length > 220 ? 18 : 21)),
          const SizedBox(height: 10),
          Text(_times(item.count), style: uiStyle(13, color: Colors.white60)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _CounterButton(key: ValueKey('counter_$id'), left: left, onTap: onTap),
            const SizedBox(width: 16),
            IconButton(
              key: ValueKey('reset_$id'),
              tooltip: 'إعادة العداد',
              onPressed: onReset,
              icon: const Icon(Icons.replay_rounded, color: AppColors.gold, size: 28),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final int left;
  final VoidCallback onTap;
  const _CounterButton({super.key, required this.left, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = left == 0;
    return Semantics(
      button: true,
      label: done ? 'تم' : 'العدّاد، المتبقي $left',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.green.withValues(alpha: .2) : const Color(0x22E6BE6E),
            border: Border.all(color: done ? AppColors.green : AppColors.gold, width: 2),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, color: AppColors.green, size: 34)
                : FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('$left', style: uiStyle(26, color: AppColors.gold, w: FontWeight.w700)),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
