import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'pressable_scale.dart';

enum PermissionAccessDialogAction { grantAccess, maybeLater }

class PermissionAccessDialogConfig {
  const PermissionAccessDialogConfig({
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
    this.primaryButtonLabel = 'GRANT ACCESS',
    this.secondaryButtonLabel = 'MAYBE LATER',
  });

  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final String primaryButtonLabel;
  final String secondaryButtonLabel;

  factory PermissionAccessDialogConfig.guestLocation() {
    return const PermissionAccessDialogConfig(
      title: 'LOCATION SHARING',
      message:
          'Allow location access so guests can connect to a venue WiFi network when they choose to join it.',
      icon: LucideIcons.mapPin,
      iconColor: AppColors.secondary,
    );
  }

  factory PermissionAccessDialogConfig.venueCamera() {
    return const PermissionAccessDialogConfig(
      title: 'CAMERA ACCESS',
      message:
          'Capture your printed menu so DineIn can scan it and build your venue menu faster.',
      icon: LucideIcons.camera,
      iconColor: AppColors.primary,
    );
  }

  factory PermissionAccessDialogConfig.biopayCamera() {
    return const PermissionAccessDialogConfig(
      title: 'BIOPAY CAMERA ACCESS',
      message:
          'Allow camera access so BioPay can capture your face and create your Rwanda payment profile for secure matching.',
      icon: LucideIcons.scanFace,
      iconColor: AppColors.primary,
    );
  }

  factory PermissionAccessDialogConfig.venuePhotos() {
    return const PermissionAccessDialogConfig(
      title: 'PHOTO LIBRARY',
      message:
          'Choose menu images from your device so DineIn can import them for venue setup.',
      icon: LucideIcons.image,
      iconColor: AppColors.secondary,
    );
  }
}

class PermissionAccessDialog extends StatelessWidget {
  const PermissionAccessDialog({
    super.key,
    required this.config,
    this.onAction,
    this.closeOnAction = false,
  });

  final PermissionAccessDialogConfig config;
  final ValueChanged<PermissionAccessDialogAction>? onAction;
  final bool closeOnAction;

  static Future<PermissionAccessDialogAction> show(
    BuildContext context, {
    required PermissionAccessDialogConfig config,
  }) async {
    final action =
        await showGeneralDialog<PermissionAccessDialogAction>(
          context: context,
          barrierDismissible: false,
          barrierLabel: config.title,
          barrierColor: Colors.black.withValues(alpha: 0.76),
          pageBuilder: (context, animation, secondaryAnimation) {
            return SafeArea(
              child: Center(
                child: PermissionAccessDialog(
                  config: config,
                  closeOnAction: true,
                ),
              ),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
                child: child,
              ),
            );
          },
        ) ??
        PermissionAccessDialogAction.maybeLater;
    return action;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF15191B),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 42,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Icon(config.icon, size: 34, color: config.iconColor),
                ),
                const SizedBox(height: 22),
                Text(
                  config.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.publicSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  config.message,
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.74),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 26),
                _DialogButton(
                  label: config.primaryButtonLabel,
                  filled: true,
                  closeOnTap: closeOnAction,
                  onTap: () =>
                      _handleAction(PermissionAccessDialogAction.grantAccess),
                ),
                const SizedBox(height: 12),
                _DialogButton(
                  label: config.secondaryButtonLabel,
                  filled: false,
                  closeOnTap: closeOnAction,
                  onTap: () =>
                      _handleAction(PermissionAccessDialogAction.maybeLater),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleAction(PermissionAccessDialogAction action) {
    onAction?.call(action);
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.filled,
    required this.closeOnTap,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final bool closeOnTap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        onTap();
        if (closeOnTap) {
          Navigator.of(context).pop(
            filled
                ? PermissionAccessDialogAction.grantAccess
                : PermissionAccessDialogAction.maybeLater,
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF1E7E72) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: filled
                ? const Color(0xFF1E7E72)
                : Colors.white.withValues(alpha: 0.20),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
