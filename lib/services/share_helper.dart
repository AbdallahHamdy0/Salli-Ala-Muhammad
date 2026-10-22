import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import 'native_bridge.dart';
import '../theme.dart';

void _toast(BuildContext context, String m) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m, style: uiStyle(14))));
}

/// بيشارك النص (ومعاه رابط التطبيق في الآخر، إلا لو [appendLink] = false). لو المشاركة فشلت بينسخه.
Future<void> shareText(BuildContext context, String text, {bool appendLink = true}) async {
  final msg = appendLink ? withAppLink(text) : text;
  try {
    await NativeBridge.shareText(msg);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: msg));
    _toast(context, 'تم نسخ النص');
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  _toast(context, 'تم النسخ');
}
