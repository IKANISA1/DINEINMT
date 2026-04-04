import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/theme/app_theme.dart';

// Conditional import for platform detection
import 'safari_install_guide_stub.dart'
    if (dart.library.js_interop) 'safari_install_guide_web.dart' as platform;

/// iOS Safari "Add to Home Screen" install guide.
///
/// Since iOS/Safari does not support the `beforeinstallprompt` event,
/// this widget detects iOS + Safari + not-standalone and shows a
/// step-by-step guide in a bottom sheet.
///
/// Rules (per DineIn STARTER RULES §2):
/// - Never shown on first paint.
/// - Only shown after engagement threshold (called externally).
/// - Dismissible, shown max once per session.
/// - Only on iOS Safari when NOT already installed as a PWA.
class SafariInstallGuide {
  SafariInstallGuide._();

  static const _dismissedKey = 'dinein.safari_install_dismissed';
  static bool _shownThisSession = false;

  /// Show the guide if conditions are met:
  /// - Is web platform
  /// - Is iOS Safari
  /// - Not already running as standalone PWA
  /// - Not already dismissed this session
  /// - Not previously dismissed (persisted)
  static Future<void> showIfEligible(BuildContext context) async {
    if (!kIsWeb) return;
    if (_shownThisSession) return;

    // Check if running in standalone mode (already installed)
    if (platform.isStandalone()) return;

    // Only show on iOS Safari
    if (!platform.isIosSafari()) return;

    // Check if user previously dismissed
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_dismissedKey) == true) return;
    } catch (_) {
      // SharedPreferences unavailable — proceed
    }

    _shownThisSession = true;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SafariInstallSheet(),
    );
  }

  /// Mark guide as dismissed persistently.
  static Future<void> _dismiss() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dismissedKey, true);
    } catch (_) {
      // Best-effort
    }
  }
}

/// The bottom sheet content for the iOS install guide.
class _SafariInstallSheet extends StatelessWidget {
  const _SafariInstallSheet();

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
                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Icon(
                        Icons.add_to_home_screen_rounded,
                        color: cs.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add DineIn to Home Screen',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'For the best experience',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.space6),

                // Step 1
                const _StepRow(
                  step: '1',
                  icon: Icons.ios_share_rounded,
                  title: 'Tap the Share button',
                  subtitle: 'Find it at the bottom of your Safari browser',
                ),

                const SizedBox(height: AppTheme.space4),

                // Step 2
                const _StepRow(
                  step: '2',
                  icon: Icons.add_box_outlined,
                  title: 'Tap "Add to Home Screen"',
                  subtitle: 'Scroll down in the share menu to find it',
                ),

                const SizedBox(height: AppTheme.space4),

                // Step 3
                const _StepRow(
                  step: '3',
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Tap "Add"',
                  subtitle:
                      'DineIn will appear on your home screen like a native app',
                ),

                const SizedBox(height: AppTheme.space8),

                // Dismiss button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      SafariInstallGuide._dismiss();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.space4,
                      ),
                    ),
                    child: Text(
                      'GOT IT',
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
                    onPressed: () {
                      SafariInstallGuide._dismiss();
                      Navigator.of(context).pop();
                    },
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

          // Safe area padding for edge-to-edge
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// Individual step row in the install guide.
class _StepRow extends StatelessWidget {
  final String step;
  final IconData icon;
  final String title;
  final String subtitle;

  const _StepRow({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step number badge
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.space3),
        // Icon
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: AppTheme.space3),
        // Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
