import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

Future<void> copyQrLink(
  BuildContext context, {
  required Uri uri,
  required String feedbackMessage,
}) async {
  await Clipboard.setData(ClipboardData(text: uri.toString()));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(feedbackMessage)));
}

Future<void> openQrLink(
  BuildContext context, {
  required Uri uri,
  required String label,
}) async {
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !context.mounted) return;
  } catch (_) {
    if (!context.mounted) return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Unable to open $label.')));
}

Future<void> shareQrPoster(
  BuildContext context, {
  required GlobalKey boundaryKey,
  required String fileName,
  required String subject,
  String failureMessage = 'Could not export the QR poster.',
}) async {
  try {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Missing QR poster boundary.');
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Could not encode the QR poster image.');
    }

    final bytes = byteData.buffer.asUint8List();
    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
        subject: subject,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}

void showBrandedQrSheet({
  required BuildContext context,
  required String title,
  required Uri uri,
  String? helperText,
  String? shareFileName,
  String? shareSubject,
  String? copyFeedbackMessage,
  String? openLabel,
}) {
  final boundaryKey = GlobalKey();
  final safeTitle = title.trim().isEmpty ? 'qr' : title.trim();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      final tt = Theme.of(sheetContext).textTheme;

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.space4,
            AppTheme.space4,
            AppTheme.space4,
            MediaQuery.of(sheetContext).viewInsets.bottom + AppTheme.space4,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.space6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppTheme.space4),
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    title,
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (helperText != null && helperText.trim().isNotEmpty) ...[
                    const SizedBox(height: AppTheme.space2),
                    Text(
                      helperText.trim(),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppTheme.space5),
                  RepaintBoundary(
                    key: boundaryKey,
                    child: BrandedQrPoster(uri: uri),
                  ),
                  const SizedBox(height: AppTheme.space5),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.space4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: SelectableText(
                      uri.toString(),
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space5),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stackActions = constraints.maxWidth < 520;
                      final shareAction = PremiumButton(
                        label: 'SHARE QR',
                        icon: LucideIcons.share2,
                        onPressed: () => shareQrPoster(
                          sheetContext,
                          boundaryKey: boundaryKey,
                          fileName:
                              shareFileName ??
                              '${_sanitizeFileName(safeTitle)}_qr.png',
                          subject: shareSubject ?? '$safeTitle QR',
                        ),
                      );
                      final copyAction = PremiumButton(
                        label: 'COPY URL',
                        icon: LucideIcons.copy,
                        isOutlined: true,
                        onPressed: () => copyQrLink(
                          sheetContext,
                          uri: uri,
                          feedbackMessage:
                              copyFeedbackMessage ?? '$safeTitle link copied.',
                        ),
                      );
                      final openAction = PremiumButton(
                        label: 'OPEN URL',
                        icon: LucideIcons.externalLink,
                        isOutlined: true,
                        onPressed: () => openQrLink(
                          sheetContext,
                          uri: uri,
                          label: openLabel ?? safeTitle,
                        ),
                      );

                      if (stackActions) {
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: shareAction,
                            ),
                            const SizedBox(height: AppTheme.space3),
                            SizedBox(width: double.infinity, child: copyAction),
                            const SizedBox(height: AppTheme.space3),
                            SizedBox(width: double.infinity, child: openAction),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: shareAction),
                          const SizedBox(width: AppTheme.space3),
                          Expanded(child: copyAction),
                          const SizedBox(width: AppTheme.space3),
                          Expanded(child: openAction),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class BrandedQrPoster extends StatelessWidget {
  final Uri uri;
  final String title;
  final bool compact;

  const BrandedQrPoster({
    super.key,
    required this.uri,
    this.title = 'SCAN TO ORDER',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final outerPadding = compact ? 16.0 : 22.0;
    final innerPadding = compact ? 14.0 : 18.0;
    final radius = compact ? 28.0 : 34.0;
    final titleStyle = (compact ? tt.labelSmall : tt.titleSmall)?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: compact ? 2.0 : 2.8,
      color: cs.onSurface,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(outerPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F8),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFD9E3DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: compact ? 18 : 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _QrAccent(cs: cs, compact: compact),
              const SizedBox(width: AppTheme.space3),
              Flexible(
                child: Text(
                  title,
                  style: titleStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              _QrAccent(cs: cs, compact: compact),
            ],
          ),
          SizedBox(height: compact ? 14 : 18),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(innerPadding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(compact ? 24 : 28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: compact ? 14 : 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: QrImageView(
                data: uri.toString(),
                version: QrVersions.auto,
                gapless: true,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: cs.primary,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: cs.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrAccent extends StatelessWidget {
  final ColorScheme cs;
  final bool compact;

  const _QrAccent({required this.cs, required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 10.0 : 12.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(compact ? 3 : 4),
      ),
    );
  }
}

String _sanitizeFileName(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final trimmed = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
  return trimmed.isEmpty ? 'qr' : trimmed;
}
