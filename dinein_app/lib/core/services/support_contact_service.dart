import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportContactService {
  SupportContactService._();

  static const whatsAppNumber = '35699711145';

  static Uri get _appUri => Uri.parse('whatsapp://send?phone=$whatsAppNumber');
  static Uri get _webUri => Uri.parse('https://wa.me/$whatsAppNumber');

  static Future<void> contactSupport(BuildContext context) async {
    try {
      final launched = await launchUrl(
        _appUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }

    try {
      final launched = await launchUrl(
        _webUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open WhatsApp support.')),
    );
  }
}
