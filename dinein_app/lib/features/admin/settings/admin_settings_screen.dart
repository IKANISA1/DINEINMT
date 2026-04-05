import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space6),
        children: [
          // ─── Header ───
          Text(
            'Settings',
            style: tt.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Global administrative profile and account controls.',
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.space12),

          // ─── Admin Account Info ───
          Container(
            padding: const EdgeInsets.all(AppTheme.space6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              boxShadow: AppTheme.clayShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Icon(LucideIcons.shieldCheck, size: 28, color: cs.primary),
                ),
                const SizedBox(width: AppTheme.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrator Account',
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
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
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: AppTheme.space12),

          // ─── Logout ───
          PressableScale(
            onTap: () async {
              await AuthRepository.instance.signOut();
              if (!context.mounted) return;
              context.goNamed(AppRouteNames.splash);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space6),
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                border: Border.all(color: cs.error.withValues(alpha: 0.10)),
                boxShadow: AppTheme.clayShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.logOut, size: 20, color: cs.error),
                  const SizedBox(width: AppTheme.space3),
                  Text(
                    'Sign Out of Console',
                    style: tt.titleMedium?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: AppTheme.space8),

          // ─── Footer ───
          Center(
            child: Text(
              'DINEIN PWA v1.0.0-beta',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: cs.onSurfaceVariant.withValues(alpha: 0.30),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space12),
        ],
      ),
    );
  }
}
