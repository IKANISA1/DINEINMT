import 'package:flutter/material.dart';
import 'package:ui/theme/app_theme.dart';

/// Pre-permission dialog that explains why notifications are beneficial
/// before the native browser/OS permission dialog is triggered.
///
/// This "two-step" approach significantly improves opt-in rates:
/// 1. Show this explainer dialog (in-app UI, dismissible).
/// 2. If user agrees, call the actual system permission request.
/// 3. If user declines, silently skip — never badger again this session.
///
/// This is a bottom sheet widget to be shown BEFORE calling
/// `FirebaseMessaging.instance.requestPermission()`.
class NotificationPrePermission {
  NotificationPrePermission._();

  /// Show the pre-permission dialog and return whether the user
  /// consented to proceed with the system permission request.
  ///
  /// Returns `true` if user tapped "Enable Notifications",
  /// `false` if dismissed or tapped "Not now".
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PrePermissionSheet(),
    );
    return result ?? false;
  }
}

class _PrePermissionSheet extends StatelessWidget {
  const _PrePermissionSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppTheme.space3),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppTheme.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header icon
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active_rounded,
                      color: cs.primary,
                      size: 28,
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.space5),

                // Title
                Center(
                  child: Text(
                    'Stay in the loop',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: AppTheme.space3),

                // Description
                Center(
                  child: Text(
                    'Get instant alerts when new orders come in and '
                    'when guests call for your attention.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: AppTheme.space6),

                // Benefits list
                _BenefitRow(
                  icon: Icons.receipt_long_rounded,
                  text: 'New order notifications in real-time',
                ),
                const SizedBox(height: AppTheme.space3),
                _BenefitRow(
                  icon: Icons.notifications_rounded,
                  text: 'Table call alerts so you never miss a guest',
                ),
                const SizedBox(height: AppTheme.space3),
                _BenefitRow(
                  icon: Icons.volume_off_rounded,
                  text: 'You can turn them off anytime in Settings',
                ),

                const SizedBox(height: AppTheme.space8),

                // Enable button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.space4,
                      ),
                    ),
                    child: Text(
                      'ENABLE NOTIFICATIONS',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),

                // Not now link
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Not now',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// A single benefit row with icon + text.
class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm + 4),
          ),
          child: Icon(icon, size: 16, color: cs.primary),
        ),
        const SizedBox(width: AppTheme.space3),
        Expanded(
          child: Text(
            text,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
