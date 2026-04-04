import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/services/venue_repository.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// Admin venue activation/status management screen.
/// Matches React Activation.tsx — status toggles, venue info, danger zone.
/// Wired to Supabase via VenueRepository.
class AdminActivationScreen extends ConsumerStatefulWidget {
  final String venueId;

  const AdminActivationScreen({super.key, required this.venueId});

  @override
  ConsumerState<AdminActivationScreen> createState() =>
      _AdminActivationScreenState();
}

class _AdminActivationScreenState extends ConsumerState<AdminActivationScreen> {
  String _status = 'active'; // active, maintenance, suspended
  bool _orderingEnabled = false;
  bool _isLoading = false;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Load initial status from venue data
    final venueAsync = ref.watch(venueByIdProvider(widget.venueId));
    if (!_initialized) {
      venueAsync.whenData((venue) {
        if (venue != null && !_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _status = venue.status.dbValue;
                _orderingEnabled = venue.orderingEnabled;
              });
            }
          });
        }
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.space6),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Header ───
                  _buildHeader(context, cs, tt),
                  const SizedBox(height: AppTheme.space10),

                  // ─── Venue Info Card ───
                  _buildVenueCard(cs, tt, venueAsync)
                      .animate(delay: 100.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: AppTheme.space10),

                  // ─── Operational State ───
                  _buildStatusSection(cs, tt)
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: AppTheme.space10),

                  // ─── Danger Zone ───
                  _buildDangerZone(cs, tt)
                      .animate(delay: 300.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: AppTheme.space24),
                ],
              ),
            ),
          ),

          // ─── Loading Overlay ───
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: cs.scrim.withValues(alpha: 0.30),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.space8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                      boxShadow: AppTheme.clayShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          'Saving venue policy…',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isLoading || newStatus == _status) return;

    setState(() => _isLoading = true);
    try {
      await VenueRepository.instance.updateVenueStatus(
        widget.venueId,
        newStatus,
      );
      ref.invalidate(allVenuesProvider);
      ref.invalidate(venueByIdProvider(widget.venueId));
      if (mounted) {
        setState(() {
          _status = newStatus;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.toUpperCase()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _updateOrderingEnabled(bool enabled) async {
    if (_isLoading || enabled == _orderingEnabled) return;

    setState(() => _isLoading = true);
    try {
      await VenueRepository.instance.updateVenueOrderingEnabled(
        widget.venueId,
        enabled,
      );
      ref.invalidate(allVenuesProvider);
      ref.invalidate(venueByIdProvider(widget.venueId));
      if (mounted) {
        setState(() {
          _orderingEnabled = enabled;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Guest ordering enabled for this venue'
                  : 'Guest ordering disabled for this venue',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update guest ordering: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteVenue() async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius3xl),
        ),
        title: Text(
          'Delete Venue?',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: cs.error,
          ),
        ),
        content: Text(
          'This venue will be removed from the platform. '
          'This action cannot be easily undone.',
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'DELETE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await VenueRepository.instance.deleteVenue(widget.venueId);
      ref.invalidate(allVenuesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venue deleted successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete venue: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PressableScale(
          onTap: () => context.pop(),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.10),
              ),
              boxShadow: AppTheme.clayShadow,
            ),
            child: Icon(
              LucideIcons.chevronLeft,
              size: 24,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Row(
          children: [
            Icon(LucideIcons.power, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'ACTIVATION CONTROLS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: cs.primary.withValues(alpha: 0.70),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space3),
        Text(
          'Manage Status',
          style: tt.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: AppTheme.space2),
        Text(
          'Control the operational state and visibility of this venue on the platform.',
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVenueCard(
    ColorScheme cs,
    TextTheme tt,
    AsyncValue<dynamic> venueAsync,
  ) {
    final venue = venueAsync.asData?.value;
    final venueName = venue?.name ?? 'Venue #${widget.venueId}';
    final venueLoc = venue?.address ?? '';

    return ClayCard(
      padding: const EdgeInsets.all(AppTheme.space6),
      child: Row(
        children: [
          // Venue image placeholder
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              boxShadow: AppTheme.clayShadow,
            ),
            child: Icon(
              LucideIcons.store,
              size: 32,
              color: cs.onSurfaceVariant.withValues(alpha: 0.30),
            ),
          ),
          const SizedBox(width: AppTheme.space5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venueName,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      LucideIcons.mapPin,
                      size: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        venueLoc.isNotEmpty ? venueLoc : 'VENUE DETAILS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
          child: Text(
            'Operational State',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space5),
        ClayCard(
          padding: const EdgeInsets.all(AppTheme.space6),
          child: Column(
            children: [
              // Current status display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT STATUS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StatusDot(status: _status),
                          const SizedBox(width: 12),
                          Text(
                            _status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              color: _statusColor(cs),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space8),

              // Status toggle buttons
              _StatusButton(
                label: 'Activate Venue',
                subtitle: 'Visible to guests • Ordering depends on validation',
                icon: LucideIcons.play,
                isSelected: _status == 'active',
                selectedColor: AppColors.secondary,
                onTap: () => _updateStatus('active'),
              ),
              const SizedBox(height: AppTheme.space4),
              _StatusButton(
                label: 'Maintenance Mode',
                subtitle: 'Visible as unavailable • Ordering disabled',
                icon: LucideIcons.clock,
                isSelected: _status == 'maintenance',
                selectedColor: AppColors.warning,
                onTap: () => _updateStatus('maintenance'),
              ),
              const SizedBox(height: AppTheme.space4),
              _StatusButton(
                label: 'Suspend Venue',
                subtitle: 'Hidden from all guests',
                icon: LucideIcons.pause,
                isSelected: _status == 'suspended',
                selectedColor: AppColors.error,
                onTap: () => _updateStatus('suspended'),
              ),
              const SizedBox(height: AppTheme.space6),
              Container(
                padding: const EdgeInsets.all(AppTheme.space5),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Guest Ordering Validation',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _orderingEnabled
                                ? 'Validated venues can accept guest orders.'
                                : 'Guests can browse this venue, but ordering stays unavailable.',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Switch(
                      value: _orderingEnabled,
                      onChanged: _updateOrderingEnabled,
                      activeThumbColor: AppColors.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
          child: Text(
            'Danger Zone',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: cs.error,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space5),
        PressableScale(
          onTap: _deleteVenue,
          child: Container(
            padding: const EdgeInsets.all(AppTheme.space6),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radius3xl),
              border: Border.all(color: cs.error.withValues(alpha: 0.10)),
              boxShadow: AppTheme.clayShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Icon(LucideIcons.trash2, size: 28, color: cs.error),
                ),
                const SizedBox(width: AppTheme.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete Venue',
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: cs.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'IRREVERSIBLE ACTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: cs.error,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 24,
                    color: cs.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(ColorScheme cs) {
    switch (_status) {
      case 'active':
        return AppColors.secondary;
      case 'suspended':
        return cs.error;
      case 'maintenance':
        return AppColors.warning;
      default:
        return cs.onSurface;
    }
  }
}

/// Animated status indicator dot.
class _StatusDot extends StatelessWidget {
  final String status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppColors.secondary,
      'suspended' => Theme.of(context).colorScheme.error,
      'maintenance' => AppColors.warning,
      _ => Theme.of(context).colorScheme.onSurface,
    };

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.50), blurRadius: 16),
        ],
      ),
    );
  }
}

/// Individual status toggle button matching React's design.
class _StatusButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final textColor = isSelected
        ? selectedColor
        : cs.onSurface.withValues(alpha: 0.40);

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.10)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : cs.outlineVariant.withValues(alpha: 0.10),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.10),
                    blurRadius: 32,
                  ),
                ]
              : AppTheme.clayShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.20)
                    : cs.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(icon, size: 24, color: textColor),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: textColor.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(LucideIcons.checkCircle2, size: 24, color: selectedColor),
          ],
        ),
      ),
    );
  }
}
