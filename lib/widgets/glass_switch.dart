import 'package:flutter/material.dart';
import '../theme.dart';

/// مفتاح تبديل مخصص بنفس شكل التصميم (أخضر مع زرار أبيض دائري).
class GlassSwitch extends StatelessWidget {
  final bool value;
  final double width;
  final double height;
  const GlassSwitch({super.key, required this.value, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final pad = height * 0.1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: width,
      height: height,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        color: value ? AppColors.green : const Color(0x33FFFFFF),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: height - pad * 2,
          height: height - pad * 2,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}
