import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:core_pkg/config/country_runtime.dart';

class SupportContactService {
  SupportContactService._();

  static String get defaultWhatsAppNumber =>
      CountryRuntime.config.supportWhatsApp;
  static String get defaultSupportEmail => CountryRuntime.config.supportEmail;
  static String get defaultVenueAccessWhatsApp =>
      CountryRuntime.config.venueAccessWhatsApp;
  static String get defaultVenueAccessEmail =>
      CountryRuntime.config.venueAccessEmail;

  static Future<void> contactSupport(
    BuildContext context, {
    String? whatsAppNumber,
    String? email,
  }) async {
    final resolvedWhatsAppNumber = whatsAppNumber ?? defaultWhatsAppNumber;
    final resolvedEmail = email ?? defaultSupportEmail;

    if (resolvedWhatsAppNumber.trim().isNotEmpty) {
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
    }

    final subject = Uri.encodeComponent('DINEIN support request');
    final mailUri = Uri.parse('mailto:$resolvedEmail?subject=$subject');

    try {
      final launched = await launchUrl(
        mailUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open a support contact option.')),
    );
  }
}
