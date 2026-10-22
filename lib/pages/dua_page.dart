import 'package:flutter/material.dart';
import '../data/duas.dart';
import '../services/share_helper.dart';
import '../theme.dart';
import '../widgets/simple_scaffold.dart';

/// كارت واحد فيه كل الأدعية (بتتكتب في lib/data/duas.dart).
class DuaPage extends StatelessWidget {
  const DuaPage({super.key});

  String get _all => kDuas.join('\n\n');

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      title: 'صدقة جارية على روح أمي',
      child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 34, 22, 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0B4A43), Color(0xFF042B28)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(90), topRight: Radius.circular(90),
                    bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30),
                  ),
                  border: Border.all(color: AppColors.goldSoft, width: 1.4),
                  boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .15), blurRadius: 26)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.favorite_rounded, color: AppColors.gold, size: 34),
                  const SizedBox(height: 10),
                  Text(kDuaPageIntro,
                      textAlign: TextAlign.center, style: uiStyle(15, color: AppColors.goldSoft, w: FontWeight.w700)),
                  for (final d in kDuas) ...[
                    const SizedBox(height: 14),
                    _divider(),
                    const SizedBox(height: 14),
                    Text(d, textAlign: TextAlign.center, style: quranStyle(22)),
                  ],
                  const SizedBox(height: 14),
                  _divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton.icon(
                      onPressed: () => copyText(context, _all),
                      icon: const Icon(Icons.copy_rounded, color: AppColors.gold, size: 20),
                      label: Text('نسخ', style: uiStyle(14, color: AppColors.gold)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => shareText(context, _all),
                      icon: const Icon(Icons.share_rounded, color: AppColors.gold, size: 20),
                      label: Text('مشاركة', style: uiStyle(14, color: AppColors.gold)),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
      ),
    );
  }

  Widget _divider() => Row(children: [
        Expanded(child: Container(height: 1, color: AppColors.goldSoft.withValues(alpha: .6))),
        const SizedBox(width: 8),
        Transform.rotate(angle: .785, child: Container(width: 9, height: 9, color: AppColors.gold)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppColors.goldSoft.withValues(alpha: .6))),
      ]);
}
