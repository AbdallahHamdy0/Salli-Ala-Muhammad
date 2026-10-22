import 'package:flutter/material.dart';
import '../constants.dart';
import '../data/adhkar.dart';
import '../services/native_bridge.dart';
import '../services/share_helper.dart';
import '../widgets/glass_switch.dart';
import '../widgets/simple_scaffold.dart';
import 'daily_adhkar_page.dart';
import 'dua_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _adhkarOn = false;

  @override
  void initState() {
    super.initState();
    NativeBridge.isAdhkarEnabled().then((v) {
      if (mounted) setState(() => _adhkarOn = v);
    }).catchError((_) {});
  }

  String get _intervalLabel => switch (kAdhkarIntervalMinutes) {
        30 => 'كل نصف ساعة',
        60 => 'كل ساعة',
        final m => 'كل $m دقيقة',
      };

  Future<void> _toggleAdhkar() async {
    final v = !_adhkarOn;
    setState(() => _adhkarOn = v);
    try {
      if (v) await NativeBridge.requestNotificationPermission();
      await NativeBridge.setAdhkarList(kAdhkar);
      await NativeBridge.setAdhkar(v, kAdhkarIntervalMinutes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      title: 'الإعدادات',
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 12),
        GlassTile(
          icon: Icons.favorite_rounded,
          title: 'صدقة جارية على روح أمي',
          subtitle: 'أدعية للقراءة والمشاركة',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DuaPage())),
        ),
        GlassTile(
          icon: Icons.auto_awesome_rounded,
          title: 'أذكار على مدار اليوم',
          subtitle: 'إشعار بذكر عشوائي $_intervalLabel',
          onTap: _toggleAdhkar,
          trailing: GlassSwitch(value: _adhkarOn, width: 52, height: 30),
        ),
        GlassTile(
          icon: Icons.wb_twilight_rounded,
          title: 'أذكار الصباح والمساء',
          subtitle: 'بعدّاد لكل ذكر + تنبيه يومي',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyAdhkarPage())),
        ),
        GlassTile(
          icon: Icons.share_rounded,
          title: 'مشاركة التطبيق',
          subtitle: 'ابعت رابط التطبيق لأهلك وأصحابك',
          onTap: () => shareText(context, kAppLink, appendLink: false), // اللينك بس
        ),
      ]),
    );
  }
}
