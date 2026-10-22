import 'package:flutter/material.dart';
import '../services/share_helper.dart';
import '../theme.dart';

/// كارت ذكر على شكل القوس الذهبي (نفس هوية التصميم).
Future<void> showDhikrCard(BuildContext context, String text) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogCtx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF0B4A43), Color(0xFF042B28)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(120), topRight: Radius.circular(120),
              bottomLeft: Radius.circular(34), bottomRight: Radius.circular(34),
            ),
            border: Border.all(color: AppColors.goldSoft, width: 1.4),
            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .18), blurRadius: 30)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('ذكر', style: uiStyle(14, color: AppColors.goldSoft, w: FontWeight.w700)),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: quranStyle(28)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Expanded(child: Container(height: 1, color: AppColors.goldSoft.withValues(alpha: .6))),
              const SizedBox(width: 8),
              Transform.rotate(angle: .785, child: Container(width: 9, height: 9, color: AppColors.gold)),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 1, color: AppColors.goldSoft.withValues(alpha: .6))),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton.icon(
                onPressed: () => shareText(dialogCtx, text),
                icon: const Icon(Icons.share_rounded, color: AppColors.gold, size: 20),
                label: Text('مشاركة', style: uiStyle(14, color: AppColors.gold)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('تقبّل الله', style: uiStyle(14, color: AppColors.cream)),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}
