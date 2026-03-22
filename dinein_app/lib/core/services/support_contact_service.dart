import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/country_runtime.dart';

class SupportContactService {
  SupportContactService._();

  static String get defaultWhatsAppNumber =>
      CountryRuntime.config.supportWhatsApp;

  static Future<void> contactSupport(
    BuildContext context, {
    String? whatsAppNumber,
  }) async {
    final resolvedWhatsAppNumber = whatsAppNumber ?? defaultWhatsAppNumber;
    final appUri = Uri.parse('whatsapp://send?phone=$resolvedWhatsAppNumber');
    final webUri = Uri.parse('https://wa.me/$resolvedWhatsAppNumber');

    try {
      final launched = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }

    try {
      final launched = await launchUrl(
        webUri,
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
