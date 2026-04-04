import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// Admin settings — matches React admin/Settings.tsx exactly.
///
/// 3 grouped sections (System Rules, Operational Control, Admin Account)
/// each with icon + title + description rows, plus logout + version footer.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  Future<void> _showSettingPreview(
    BuildContext context, {
    required String label,
    required String description,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(AppTheme.space4),
        padding: const EdgeInsets.all(AppTheme.space6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(color: AppColors.white5),
          boxShadow: AppTheme.clayShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppTheme.space2),
            Text(
              description,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.space5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space5),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
              ),
              child: Text(
                'This control is queued for a dedicated admin workflow. Use the live Overview, Venues, Menus, and Orders modules for today’s operations.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space5),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Console'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final sections = [
      {
        'title': 'SYSTEM RULES',
        'items': [
          {
            'icon': LucideIcons.shieldCheck,
            'label': 'Security Protocols',
            'desc': 'Manage 2FA and encryption settings',
          },
          {
            'icon': LucideIcons.database,
            'label': 'Data Governance',
            'desc': 'Review data retention and privacy policies',
          },
          {
            'icon': LucideIcons.zap,
            'label': 'Automation Rules',
            'desc': 'Configure parsing and auto-approvals',
          },
        ],
      },
      {
        'title': 'OPERATIONAL CONTROL',
        'items': [
          {
            'icon': LucideIcons.bell,
            'label': 'Global Notifications',
            'desc': 'Manage system-wide alerts and broadcasts',
          },
          {
            'icon': LucideIcons.messageSquare,
            'label': 'Support Queue',
            'desc': 'Access venue and guest support tickets',
          },
          {
            'icon': LucideIcons.globe,
            'label': 'Regional Settings',
            'desc': 'Manage currencies, taxes, and locales',
          },
        ],
      },
      {
        'title': 'ADMIN ACCOUNT',
        'items': [
          {
            'icon': LucideIcons.user,
            'label': 'Profile Settings',
            'desc': 'Update your administrative profile',
          },
          {
            'icon': LucideIcons.lock,
            'label': 'Access Control',
            'desc': 'Manage other admin roles and permissions',
          },
        ],
      },
    ];

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
            'Global operational controls and system configuration.',
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.space12),

          // ─── Sections ───
          ...sections.asMap().entries.map((sEntry) {
            final sIdx = sEntry.key;
            final section = sEntry.value;
            final items = section['items'] as List<Map<String, dynamic>>;
            return Padding(
              padding: EdgeInsets.only(
                bottom: sIdx < sections.length - 1
                    ? AppTheme.space12
                    : AppTheme.space8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      section['title'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  ...items.asMap().entries.map((iEntry) {
                    final iIdx = iEntry.key;
                    final item = iEntry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space3),
                      child: RepaintBoundary(
                        child:
                          PressableScale(
                                onTap: () => _showSettingPreview(
                                  context,
                                  label: item['label'] as String,
                                  description: item['desc'] as String,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(
                                    AppTheme.space5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusXxl,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                    ),
                                    boxShadow: AppTheme.clayShadow,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Icon(
                                          item['icon'] as IconData,
                                          size: 22,
                                          color: cs.primary,
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.space4),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['label'] as String,
                                              style: tt.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item['desc'] as String,
                                              style: tt.bodySmall?.copyWith(
                                                color: cs.onSurfaceVariant,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        LucideIcons.chevronRight,
                                        size: 20,
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.30,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .animate(delay: ((sIdx * 100) + (iIdx * 50)).ms)
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.05, end: 0),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

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
          ),

          const SizedBox(height: AppTheme.space8),

          // ─── Role Switch Footer ───
          const RoleSwitchFooter(currentRole: ActiveRole.admin),

          const SizedBox(height: AppTheme.space12),
        ],
      ),
    );
  }
}
