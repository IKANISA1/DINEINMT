import 'package:flutter/material.dart';

import '../../core/services/support_contact_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

Future<void> showAccessSupportDialog(
  BuildContext context, {
  required String title,
  required String message,
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
        title: Text(
          title,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await SupportContactService.contactSupport(context);
            },
            child: const Text('Contact Support'),
          ),
        ],
      );
    },
  );
}
