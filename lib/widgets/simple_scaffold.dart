import 'package:flutter/material.dart';
import '../theme.dart';

class GradientScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const GradientScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.gold),
          title: Text(title, style: uiStyle(20, color: AppColors.gold, w: FontWeight.w700)),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF0A4A44), Color(0xFF042B28), AppColors.deep],
            ),
          ),
          child: SafeArea(child: child),
        ),
      );
}

class GlassTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  const GlassTile({super.key, required this.icon, required this.title, this.subtitle, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x5545A58E)),
              ),
              child: Row(children: [
                Icon(icon, color: AppColors.gold, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: uiStyle(17, w: FontWeight.w700)),
                    if (subtitle != null) Text(subtitle!, style: uiStyle(13, color: Colors.white60)),
                  ]),
                ),
                trailing ?? const Icon(Icons.chevron_left_rounded, color: AppColors.goldSoft),
              ]),
            ),
          ),
        ),
      );
}
