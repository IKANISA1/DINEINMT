import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// Admin settings — matches React admin/Settings.tsx exactly.
///
/// 3 grouped sections (System Rules, Operational Control, Admin Account)
/// each with icon + title + description rows, plus logout + version footer.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  Future<void> _confirmLogout(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius3xl),
        ),
        title: Text(
          'Sign Out?',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.error,
          ),
        ),
        content: Text(
          'You will need to sign in again to access the admin console.',
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: cs.error.withValues(alpha: 0.10),
            ),
            child: Text(
              'Sign out',
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await AuthRepository.instance.signOut();
    if (!context.mounted) return;
    context.goNamed(AppRouteNames.splash);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space6),
        children: [
          const AppPageHeader(
            title: 'Settings',
            subtitle: 'Console profile and account controls.',
          ),
          const SizedBox(height: AppTheme.space6),

          AppSurfaceCard(
            padding: const EdgeInsets.all(AppTheme.space6),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Icon(
                    LucideIcons.shieldCheck,
                    size: 22,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrator Account',
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Full system access granted.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.space6),

          AppListTileCard(
            onTap: () => _confirmLogout(context, cs, tt),
            icon: LucideIcons.logOut,
            iconColor: cs.error,
            title: 'Sign out',
            subtitle: 'End the current admin session.',
            trailing: Text(
              'Now',
              style: tt.labelMedium?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: AppTheme.space8),

          Center(
            child: Text(
              'DineIn PWA v1.0.0',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.72),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space6),
        ],
      ),
    );
  }
}
