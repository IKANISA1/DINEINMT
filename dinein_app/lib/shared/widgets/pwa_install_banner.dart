import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ui/theme/app_theme.dart';

import 'package:dinein_app/core/services/pwa_install_service.dart';

/// A bottom-anchored banner prompting the user to install the PWA.
///
/// This banner only appears after meaningful engagement (order placed,
/// 2+ cart items, or 45s browsing). The key constraint: the browser's
/// `prompt()` API MUST be called from a user gesture (tap/click).
/// So the banner provides a button the user taps, which calls
/// [PwaInstallService.promptFromUserGesture].
class PwaInstallBanner extends StatefulWidget {
  final Widget child;

  const PwaInstallBanner({super.key, required this.child});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    // Check current state
    _visible = PwaInstallService.shouldShowBanner;

    // Listen for future changes
    _subscription = PwaInstallService.bannerStream.listen((show) {
      if (mounted) setState(() => _visible = show);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onInstallTap() {
    // This is called from a tap handler — user gesture requirement satisfied.
    PwaInstallService.promptFromUserGesture();
    setState(() => _visible = false);
  }

  void _onDismiss() {
    PwaInstallService.dismissBanner();
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;

    return Stack(
      children: [
        widget.child,
        // Animated install banner at the bottom
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: 16,
          right: 16,
          // Slide up from below the screen when visible
          bottom: _visible ? 80 : -120,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _visible ? 1.0 : 0.0,
            child: _InstallCard(
              onInstall: _onInstallTap,
              onDismiss: _onDismiss,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstallCard extends StatelessWidget {
  final VoidCallback onInstall;
  final VoidCallback onDismiss;

  const _InstallCard({
    required this.onInstall,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space4),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                LucideIcons.download,
                size: 20,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Install DineIn',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add to your home screen for quick access',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.space2),
            // Dismiss button
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                LucideIcons.x,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              tooltip: 'Dismiss',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),
            const SizedBox(width: 4),
            // Install button — the TAP here is the user gesture
            FilledButton(
              onPressed: onInstall,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Install'),
            ),
          ],
        ),
      ),
    );
  }
}
