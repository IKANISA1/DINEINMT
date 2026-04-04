import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:db_pkg/models/models.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/services/venue_notification_repository.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// Venue Notifications settings — full-page screen.
///
/// Layout (matching screenshot):
///   Back + Header → ORDER ALERTS section →
///   "New Order Push" toggle → "WhatsApp Updates" toggle
///
class VenueNotificationsScreen extends ConsumerStatefulWidget {
  const VenueNotificationsScreen({super.key});

  @override
  ConsumerState<VenueNotificationsScreen> createState() =>
      _VenueNotificationsScreenState();
}

class _VenueNotificationsScreenState
    extends ConsumerState<VenueNotificationsScreen> {
  bool _orderPush = true;
  bool _whatsAppUpdates = true;
  bool _isLoadingSettings = false;
  bool _isSavingSettings = false;
  String? _loadedVenueId;

  AuthorizationStatus? _osPushStatus;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: _checkOsNotificationStatus,
    );
    _checkOsNotificationStatus();
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  Future<void> _checkOsNotificationStatus() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (!mounted) return;
      setState(() {
        _osPushStatus = settings.authorizationStatus;
      });
    } catch (_) {
      // Handle missing capabilities quietly.
    }
  }

  Future<void> _loadSettings(String venueId) async {
    if (_isLoadingSettings && _loadedVenueId == venueId) return;
    setState(() {
      _isLoadingSettings = true;
      _loadedVenueId = venueId;
    });

    try {
      final settings = await VenueNotificationRepository.instance.getSettings(
        venueId,
      );
      if (!mounted || _loadedVenueId != venueId) return;
      setState(() {
        _orderPush = settings.orderPushEnabled;
        _whatsAppUpdates = settings.whatsAppUpdatesEnabled;
        _isLoadingSettings = false;
      });
    } catch (_) {
      if (!mounted || _loadedVenueId != venueId) return;
      setState(() {
        _isLoadingSettings = false;
      });
    }
  }

  Future<void> _persistSettings(
    String venueId, {
    required bool orderPushEnabled,
    required bool whatsAppUpdatesEnabled,
  }) async {
    final previousOrderPush = _orderPush;
    final previousWhatsAppUpdates = _whatsAppUpdates;

    setState(() {
      _orderPush = orderPushEnabled;
      _whatsAppUpdates = whatsAppUpdatesEnabled;
      _isSavingSettings = true;
    });

    try {
      final saved = await VenueNotificationRepository.instance.updateSettings(
        venueId,
        VenueNotificationSettings(
          orderPushEnabled: orderPushEnabled,
          whatsAppUpdatesEnabled: whatsAppUpdatesEnabled,
        ),
      );
      if (!mounted) return;
      setState(() {
        _orderPush = saved.orderPushEnabled;
        _whatsAppUpdates = saved.whatsAppUpdatesEnabled;
        _isSavingSettings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _orderPush = previousOrderPush;
        _whatsAppUpdates = previousWhatsAppUpdates;
        _isSavingSettings = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venueAsync = ref.watch(currentVenueProvider);

    return Scaffold(
      body: venueAsync.when(
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 200),
        ),
        error: (_, _) => ErrorState(
          message: 'Could not load venue.',
          onRetry: () => ref.invalidate(currentVenueProvider),
        ),
        data: (venue) {
          if (venue == null) {
            return const EmptyState(
              icon: LucideIcons.store,
              title: 'No venue',
              subtitle: 'Claim a venue first.',
            );
          }

          if (_loadedVenueId != venue.id && !_isLoadingSettings) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                unawaited(_loadSettings(venue.id));
              }
            });
          }

          final canEditToggles = !_isLoadingSettings && !_isSavingSettings;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space6,
              AppTheme.space6,
              AppTheme.space6,
              120,
            ),
            children: [
              // ─── Header ───
              Row(
                children: [
                  PressableScale(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Icon(
                        LucideIcons.chevronLeft,
                        size: 18,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'VENUE MANAGEMENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space8),

              // ─── Section: ORDER ALERTS ───
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'ORDER ALERTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space3),

              // ─── New Order Push ───
              _ToggleTile(
                    icon: LucideIcons.smartphone,
                    iconColor: cs.primary,
                    title: 'New Order Push',
                    subtitle: 'INSTANT MOBILE NOTIFICATIONS',
                    value: _orderPush,
                    onChanged: canEditToggles
                        ? (v) => _persistSettings(
                            venue.id,
                            orderPushEnabled: v,
                            whatsAppUpdatesEnabled: _whatsAppUpdates,
                          )
                        : null,
                  )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0, duration: 300.ms),
              const SizedBox(height: AppTheme.space2),

              if (_orderPush && _osPushStatus == AuthorizationStatus.denied)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: AppTheme.space2),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.error.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.alertTriangle,
                          color: cs.error, size: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Push alerts are disabled in your Device Settings. Please enable them to receive incoming orders.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.error,
                            fontSize: 10,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(
                    begin: -0.1, end: 0, duration: 300.ms),

              // ─── WhatsApp Updates ───
              _ToggleTile(
                    icon: LucideIcons.phone,
                    iconColor: AppColors.secondary,
                    title: 'WhatsApp Updates',
                    subtitle: 'RECEIVE ORDER SUMMARIES',
                    value: _whatsAppUpdates,
                    onChanged: canEditToggles
                        ? (v) => _persistSettings(
                            venue.id,
                            orderPushEnabled: _orderPush,
                            whatsAppUpdatesEnabled: v,
                          )
                        : null,
                  )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 100.ms)
                  .slideY(begin: 0.05, end: 0, duration: 300.ms, delay: 100.ms),
            ],
          );
        },
      ),
    );
  }
}

// ─── Private Widgets ───

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}
