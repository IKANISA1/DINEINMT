import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:db_pkg/models/models.dart';
import 'package:ui/widgets/shared_widgets.dart';

void showVenueWifiSheet(BuildContext ctx, Venue venue) {
  final cs = Theme.of(ctx).colorScheme;
  final tt = Theme.of(ctx).textTheme;
  final ssid = venue.wifiSsid ?? '';
  final password = venue.wifiPassword ?? '';
  final security = venue.wifiSecurity ?? 'WPA';
  final isOpenNetwork = security.trim().toUpperCase() == 'OPEN';
  final hasPassword = password.trim().isNotEmpty;
  final wifiQrData = buildVenueWifiQrData(
    ssid: ssid,
    password: password,
    security: security,
  );

  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(LucideIcons.wifi, size: 22, color: cs.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ssid,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOpenNetwork
                            ? '$security network • no password required'
                            : '$security • Tap below to copy password',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (hasPassword)
              PressableScale(
                semanticLabel: 'Copy WiFi password',
                onTap: () {
                    Clipboard.setData(ClipboardData(text: password));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: const Text('WiFi password copied!'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.copy, size: 18, color: cs.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TAP TO COPY PASSWORD',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '•' * password.length.clamp(6, 20),
                                style: tt.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          LucideIcons.arrowRight,
                          size: 16,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.badgeCheck, size: 18, color: cs.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'This is an open network. Your device can join without a password.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'OR SCAN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: wifiQrData,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: Color(0xFF1A1A2E),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Point your phone camera to connect',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


String buildVenueWifiQrData({
  required String ssid,
  required String password,
  required String security,
}) {
  String escapeWifiValue(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll(':', r'\:');
  }

  final normalizedSecurity = security.trim().toUpperCase();
  final qrSecurity = normalizedSecurity == 'OPEN'
      ? 'nopass'
      : normalizedSecurity;

  final buffer = StringBuffer('WIFI:');
  buffer.write('S:${escapeWifiValue(ssid)};');
  buffer.write('T:$qrSecurity;');
  if (qrSecurity != 'nopass' && password.trim().isNotEmpty) {
    buffer.write('P:${escapeWifiValue(password)};');
  }
  buffer.write(';');
  return buffer.toString();
}

