import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/infrastructure/support_contact_service.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class GuestSettingsScreen extends ConsumerWidget {
  const GuestSettingsScreen({super.key});

  Future<void> _launchExternal(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open that link.')));
  }

  void _showAboutSheet(BuildContext context, CountryConfig config) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final countryName = config.country.label;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.all(AppTheme.space4),
        child: GuestSurfaceCard(
          padding: const EdgeInsets.all(AppTheme.space6),
          borderRadius: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(
                size: 56,
                borderRadius: 16,
                fontSize: 32,
                shadowBlur: 20,
                shadowOpacity: 0.25,
              ),
              const SizedBox(height: AppTheme.space4),
              Text('Version 1.0.0', style: tt.bodySmall),
              const SizedBox(height: AppTheme.space5),
              Text(
                'DINEIN is a dine-in ordering experience built for table-side speed and clarity.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.84),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              Wrap(
                spacing: AppTheme.space3,
                runSpacing: AppTheme.space3,
                alignment: WrapAlignment.center,
                children: [
                  GuestMetaPill(
                    icon: LucideIcons.mapPin,
                    label: countryName,
                    emphasized: true,
                  ),
                  const GuestMetaPill(
                    icon: LucideIcons.utensils,
                    label: 'Dine-in',
                  ),
                  const GuestMetaPill(
                    icon: LucideIcons.qrCode,
                    label: 'QR entry',
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space5),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDataSheet(BuildContext context, CountryConfig config) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeleteDataSheet(
        onConfirm: (reason) {
          Navigator.of(context).pop();
          final encodedReason = Uri.encodeComponent(reason);
          final uri = Uri.parse(
            'mailto:info@ikanisa.com'
            '?subject=DineIn%20Data%20Deletion%20Request'
            '&body=I%20would%20like%20to%20request%20deletion%20of%20all%20'
            'my%20personal%20data%20associated%20with%20the%20DineIn%20app.'
            '%0A%0AReason:%20$encodedReason',
          );
          _launchExternal(context, uri);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(countryConfigProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space6,
        AppTheme.space6,
        AppTheme.space6,
        120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeaderCard(
            welcomeMessage: config.welcomeMessage,
            countryLabel: config.country.label,
          ),
          const SizedBox(height: AppTheme.space5),
          const GuestSectionHeader(
            title: 'Quick actions',
            subtitle: 'Your most-used guest tools.',
          ),
          const SizedBox(height: AppTheme.space4),
          _SettingsTile(
            icon: LucideIcons.history,
            title: 'Order history',
            subtitle: 'Recent orders',
            onTap: () => context.goNamed(AppRouteNames.orderHistory),
          ),
          const SizedBox(height: AppTheme.space5),
          const GuestSectionHeader(
            title: 'Support and privacy',
            subtitle: 'Help, policies, and account actions.',
          ),
          const SizedBox(height: AppTheme.space4),
          _SettingsTile(
            icon: LucideIcons.messageSquare,
            title: 'Get in Touch',
            onTap: () => SupportContactService.contactSupport(context),
          ),
          const SizedBox(height: AppTheme.space3),
          _SettingsTile(
            icon: LucideIcons.info,
            title: 'About DineIn',
            onTap: () => _showAboutSheet(context, config),
          ),
          const SizedBox(height: AppTheme.space3),
          _SettingsTile(
            icon: LucideIcons.shield,
            title: 'Privacy Policy',
            onTap: () =>
                _launchExternal(context, Uri.parse(config.privacyPolicyUrl)),
          ),
          const SizedBox(height: AppTheme.space3),
          _SettingsTile(
            icon: LucideIcons.trash2,
            title: 'Delete my data',
            subtitle: 'Send a deletion request',
            onTap: () => _showDeleteDataSheet(context, config),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final String welcomeMessage;
  final String countryLabel;

  const _ProfileHeaderCard({
    required this.welcomeMessage,
    required this.countryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GuestHeroCard(
      eyebrow: 'Guest',
      title: 'Settings',
      subtitle: welcomeMessage,
      trailing: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          LucideIcons.user,
          size: 22,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      footer: Wrap(
        spacing: AppTheme.space3,
        runSpacing: AppTheme.space3,
        children: [
          GuestMetaPill(icon: LucideIcons.mapPin, label: countryLabel),
          const GuestMetaPill(icon: LucideIcons.utensils, label: 'Dine-in'),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppListTileCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

class _DeleteDataSheet extends StatefulWidget {
  final ValueChanged<String> onConfirm;

  const _DeleteDataSheet({required this.onConfirm});

  @override
  State<_DeleteDataSheet> createState() => _DeleteDataSheetState();
}

class _DeleteDataSheetState extends State<_DeleteDataSheet> {
  static const _reasons = [
    'I no longer use the app',
    'Privacy concerns',
    'Too many notifications',
    'Switching to another service',
    'Other',
  ];

  int _selectedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.all(AppTheme.space4),
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  LucideIcons.alertTriangle,
                  size: 22,
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete My Data',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This action cannot be undone',
                      style: tt.bodySmall?.copyWith(
                        color: Colors.red.shade300,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            'We\'ll send a data deletion request on your behalf. '
            'All your personal data, order history, and preferences will be permanently removed.',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            'Reason',
            style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.space3),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_reasons.length, (index) {
              final isSelected = _selectedIndex == index;
              return Semantics(
                label: _reasons[index],
                selected: isSelected,
                button: true,
                child: InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.red.withValues(alpha: 0.14)
                          : cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      border: Border.all(
                        color: isSelected
                            ? Colors.red.withValues(alpha: 0.42)
                            : cs.outlineVariant.withValues(alpha: 0.72),
                      ),
                    ),
                    child: Text(
                      _reasons[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.red.shade200
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppTheme.space6),
          Row(
            children: [
              Expanded(
                child: PremiumButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: LucideIcons.x,
                  isOutlined: true,
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: PremiumButton(
                  label: 'Confirm',
                  onPressed: _selectedIndex >= 0
                      ? () => widget.onConfirm(_reasons[_selectedIndex])
                      : null,
                  icon: LucideIcons.trash2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
