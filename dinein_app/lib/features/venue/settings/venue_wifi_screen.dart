import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/venue_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// WiFi Settings — full-page screen for managing venue WiFi credentials.
///
/// Layout: Header → SSID field → Password field (with toggle) →
///         Security dropdown → Info note → Floating SAVE button.
class VenueWifiScreen extends ConsumerStatefulWidget {
  const VenueWifiScreen({super.key});

  @override
  ConsumerState<VenueWifiScreen> createState() => _VenueWifiScreenState();
}

class _VenueWifiScreenState extends ConsumerState<VenueWifiScreen> {
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _saving = false;
  bool _obscurePass = true;
  String _security = 'WPA';
  String? _seededId;

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _seed(Venue venue) {
    if (_seededId == venue.id) return;
    _seededId = venue.id;
    _ssidCtrl.text = venue.wifiSsid ?? '';
    _passCtrl.text = venue.wifiPassword ?? '';
    _security = venue.wifiSecurity ?? 'WPA';
  }

  Future<void> _save(Venue venue) async {
    if (_ssidCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network name is required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await VenueRepository.instance.updateVenue(venue.id, {
        'wifi_ssid': _ssidCtrl.text.trim(),
        'wifi_password': _passCtrl.text.trim(),
        'wifi_security': _security,
      });
      ref.invalidate(currentVenueProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WiFi settings saved.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save WiFi settings.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearWifi(Venue venue) async {
    setState(() => _saving = true);
    try {
      await VenueRepository.instance.updateVenue(venue.id, {
        'wifi_ssid': null,
        'wifi_password': null,
        'wifi_security': null,
      });
      ref.invalidate(currentVenueProvider);
      if (!mounted) return;
      _ssidCtrl.clear();
      _passCtrl.clear();
      _security = 'WPA';
      _seededId = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WiFi removed.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove WiFi.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
            child: SkeletonLoader(width: double.infinity, height: 200)),
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
          _seed(venue);
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.space6, AppTheme.space6, AppTheme.space6, 120),
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
                                color:
                                    Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Icon(LucideIcons.chevronLeft,
                              size: 18, color: cs.onSurface),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WiFi Sharing',
                              style: tt.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                          Text('VENUE CONFIGURATION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: cs.onSurfaceVariant,
                              )),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space6),

                  // ─── WiFi Icon Hero ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primary.withValues(alpha: 0.12),
                          cs.primary.withValues(alpha: 0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: cs.primary.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.wifi,
                              size: 28, color: cs.primary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          venue.hasWifi ? 'SHARING ENABLED' : 'NOT CONFIGURED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: venue.hasWifi
                                ? AppColors.success
                                : cs.onSurfaceVariant.withValues(alpha: 0.50),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: AppTheme.space6),

                  // ─── SSID Field ───
                  _WifiField(
                    icon: LucideIcons.wifi,
                    label: 'NETWORK NAME (SSID)',
                    controller: _ssidCtrl,
                    hint: 'MyVenueWiFi',
                  ),

                  // ─── Password Field with Toggle ───
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space3),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                        boxShadow: AppTheme.clayShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.lock, size: 13,
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.70)),
                              const SizedBox(width: 8),
                              Text('PASSWORD',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.70),
                                  )),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              suffixIcon: PressableScale(
                                onTap: () => setState(
                                    () => _obscurePass = !_obscurePass),
                                child: Icon(
                                  _obscurePass
                                      ? LucideIcons.eyeOff
                                      : LucideIcons.eye,
                                  size: 18,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              suffixIconConstraints: const BoxConstraints(
                                  minHeight: 24, minWidth: 24),
                            ),
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── Security Type ───
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space3),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                        boxShadow: AppTheme.clayShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.shieldCheck, size: 13,
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.70)),
                              const SizedBox(width: 8),
                              Text('SECURITY TYPE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.70),
                                  )),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButton<String>(
                            value: _security,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            dropdownColor: cs.surfaceContainerHigh,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'WPA',
                                  child: Text('WPA / WPA2 / WPA3')),
                              DropdownMenuItem(
                                  value: 'WEP', child: Text('WEP')),
                              DropdownMenuItem(
                                  value: 'Open',
                                  child: Text('Open (No Password)')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _security = v);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── Info Note ───
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.info,
                            size: 16,
                            color: cs.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Guests will see a WiFi icon on your venue page. They can tap to copy the password or scan a QR code to connect instantly.',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
                  const SizedBox(height: AppTheme.space4),

                  // ─── Remove WiFi (if exists) ───
                  if (venue.hasWifi)
                    PressableScale(
                      onTap: _saving ? null : () => _clearWifi(venue),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: cs.error.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.trash2,
                                size: 14, color: cs.error),
                            const SizedBox(width: 8),
                            Text('REMOVE WIFI',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: cs.error,
                                )),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // ─── Floating Save Button ───
              Positioned(
                bottom: 100,
                left: AppTheme.space6,
                right: AppTheme.space6,
                child: PressableScale(
                  onTap: _saving ? null : () => _save(venue),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.30),
                          AppColors.secondary.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color:
                              AppColors.secondary.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_saving)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onSurface,
                            ),
                          )
                        else
                          Icon(LucideIcons.save, size: 16,
                              color: cs.onSurface),
                        const SizedBox(width: 10),
                        Text('SAVE WIFI',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: cs.onSurface,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Private Widgets ───

class _WifiField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String hint;

  const _WifiField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: AppTheme.clayShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13,
                    color: AppColors.secondary.withValues(alpha: 0.70)),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: AppColors.secondary.withValues(alpha: 0.70),
                    )),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: InputDecoration.collapsed(hintText: hint),
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
