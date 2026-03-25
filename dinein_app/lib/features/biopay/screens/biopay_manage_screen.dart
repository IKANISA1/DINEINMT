import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../biopay_providers.dart';
import '../biopay_strings.dart';
import '../models/biopay_models.dart';

/// BioPay profile management screen.
///
/// Requires same-device auth (owner_token) or cross-device recovery
/// (biopay_id + management_code). Shows profile details and offers:
/// - Edit display name
/// - Edit USSD string
/// - Re-enroll face
/// - Delete profile
class BiopayManageScreen extends ConsumerStatefulWidget {
  const BiopayManageScreen({super.key});

  @override
  ConsumerState<BiopayManageScreen> createState() => _BiopayManageScreenState();
}

class _BiopayManageScreenState extends ConsumerState<BiopayManageScreen> {
  ManagedBiopayProfile? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = ref.read(biopayRepositoryProvider);
      final profile = await repository.getManagedProfile();
      if (profile == null) {
        setState(() {
          _isLoading = false;
          _error =
              'No BioPay profile found on this device. '
              'Register first or use your management code to recover.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage BioPay')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(cs, tt)
          : _buildProfile(cs, tt),
    );
  }

  Widget _buildError(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error),
            const SizedBox(height: AppTheme.space4),
            Text(
              _error!,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space6),
            PremiumButton(
              label: 'REGISTER NOW',
              onPressed: () => context.pushNamed(AppRouteNames.biopayRegister),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(ColorScheme cs, TextTheme tt) {
    final profile = _profile!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile summary card
          ClayCard(
            borderRadius: AppTheme.radiusXxl,
            padding: const EdgeInsets.all(AppTheme.space6),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.scanFace,
                    size: 32,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  profile.displayName,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.space2),
                Text(
                  profile.biopayId,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppTheme.space3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space3,
                    vertical: AppTheme.space1,
                  ),
                  decoration: BoxDecoration(
                    color: profile.isActive
                        ? AppColors.secondary.withValues(alpha: 0.12)
                        : AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    profile.isActive ? 'ACTIVE' : profile.status.toUpperCase(),
                    style: tt.labelSmall?.copyWith(
                      color: profile.isActive
                          ? AppColors.secondary
                          : AppColors.error,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03),

          const SizedBox(height: AppTheme.space6),

          // Details
          _DetailRow(
            label: 'Payment String',
            value: profile.ussdString,
            icon: LucideIcons.phone,
          ).animate().fadeIn(delay: 80.ms, duration: 250.ms),

          const SizedBox(height: AppTheme.space3),

          _DetailRow(
            label: 'Registered',
            value: profile.createdAt != null
                ? _formatDate(profile.createdAt!)
                : '—',
            icon: LucideIcons.calendar,
          ).animate().fadeIn(delay: 120.ms, duration: 250.ms),

          const SizedBox(height: AppTheme.space8),

          // Actions
          Text(
            'ACTIONS',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: AppTheme.space4),

          _ActionTile(
            icon: LucideIcons.edit3,
            title: 'Edit Display Name',
            onTap: () => _showEditDialog(
              'Display Name',
              profile.displayName,
              (value) => _updateField('display_name', value),
            ),
          ).animate().fadeIn(delay: 160.ms, duration: 250.ms),

          const SizedBox(height: AppTheme.space3),

          _ActionTile(
            icon: LucideIcons.phone,
            title: 'Edit Payment String',
            onTap: () => _showEditDialog(
              'USSD String',
              profile.ussdString,
              (value) => _updateField('ussd_string', value),
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 250.ms),

          const SizedBox(height: AppTheme.space3),

          _ActionTile(
            icon: LucideIcons.refreshCw,
            title: BiopayStrings.manageReEnroll,
            subtitle: 'Replace your face data with a new capture',
            onTap: _handleReEnroll,
          ).animate().fadeIn(delay: 240.ms, duration: 250.ms),

          const SizedBox(height: AppTheme.space8),

          // Danger zone
          Text(
            'DANGER ZONE',
            style: tt.labelSmall?.copyWith(
              color: AppColors.error.withValues(alpha: 0.7),
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: AppTheme.space4),

          _ActionTile(
            icon: LucideIcons.trash2,
            title: BiopayStrings.manageDelete,
            titleColor: AppColors.error,
            onTap: _handleDelete,
          ).animate().fadeIn(delay: 280.ms, duration: 250.ms),
        ],
      ),
    );
  }

  void _showEditDialog(
    String field,
    String currentValue,
    Function(String) onSave,
  ) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $field'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: field,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final value = controller.text.trim();
              if (value.isNotEmpty && value != currentValue) {
                onSave(value);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateField(String field, String value) async {
    try {
      final localAuth = ref.read(localBiopayAuthProvider).value;
      if (localAuth == null) return;

      final installId = await ref.read(installIdProvider.future);

      await ref
          .read(biopayRepositoryProvider)
          .updateProfile(
            ownerToken: localAuth.ownerToken,
            biopayId: localAuth.biopayId,
            displayName: field == 'display_name' ? value : null,
            ussdString: field == 'ussd_string' ? value : null,
            clientInstallId: installId,
          );
      await ref.read(localBiopayAuthProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        _loadProfile(); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  void _handleReEnroll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-Enroll Face'),
        content: const Text(
          'This will replace your current face data with a new capture. '
          'Your previous owner token will be rotated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pushNamed(AppRouteNames.biopayReEnroll);
            },
            child: const Text('PROCEED'),
          ),
        ],
      ),
    );
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: const Text(
          'This will permanently deactivate your BioPay profile. '
          'Your face data will be removed from the system. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final localAuth = ref.read(localBiopayAuthProvider).value;
                if (localAuth == null) return;

                final installId = await ref.read(installIdProvider.future);

                await ref
                    .read(biopayRepositoryProvider)
                    .deleteProfile(
                      ownerToken: localAuth.ownerToken,
                      biopayId: localAuth.biopayId,
                      clientInstallId: installId,
                    );

                await ref.read(localBiopayAuthProvider.notifier).refresh();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile deleted')),
                  );
                  context.goNamed(AppRouteNames.biopayHome);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Helper widgets ─────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(width: AppTheme.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              Text(value, style: tt.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ClayCard(
      onTap: onTap,
      borderRadius: AppTheme.radiusLg,
      padding: const EdgeInsets.all(AppTheme.space4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: titleColor ?? cs.primary),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 16, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
