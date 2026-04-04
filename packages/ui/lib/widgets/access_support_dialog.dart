import 'package:flutter/material.dart';

import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'otp_widgets.dart';

Future<void> showAccessSupportDialog(
  BuildContext context, {
  required String title,
  required String message,
  String ctaLabel = 'Contact Support',
  String closeLabel = 'Close',
  bool showWhatsAppBadge = false,
  VoidCallback? onContactSupport,
}) {
  final tt = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          side: BorderSide(color: AppColors.white5),
        ),
        titlePadding: const EdgeInsets.fromLTRB(
          AppTheme.space6,
          AppTheme.space6,
          AppTheme.space6,
          AppTheme.space2,
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          AppTheme.space6,
          0,
          AppTheme.space6,
          AppTheme.space6,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppTheme.space4,
          0,
          AppTheme.space4,
          AppTheme.space4,
        ),
        title: Row(
          children: [
            if (showWhatsAppBadge) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Center(
                  child: WhatsAppIcon(color: AppColors.secondary),
                ),
              ),
              const SizedBox(width: AppTheme.space3),
            ],
            Expanded(
              child: Text(
                title,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(closeLabel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onContactSupport?.call();
            },
            child: Text(ctaLabel),
          ),
        ],
      );
    },
  );
}
