import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:db_pkg/models/models.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/services/venue_repository.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// WiFi Settings — full-page screen for managing venue WiFi credentials.
///
/// Layout: Header → Network configuration card → fixed SAVE button.
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

  String get _securityLabel {
    switch (_security) {
      case 'WEP':
        return 'WEP';
      case 'Open':
        return 'Open Network';
      case 'WPA':
      default:
        return 'WPA/WPA2/WPA3';
    }
  }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('WiFi settings saved.')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('WiFi removed.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not remove WiFi.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venueAsync = ref.watch(currentVenueProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
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
              subtitle: 'No venue linked to this account.',
            );
          }
          _seed(venue);
          return SafeArea(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space6,
                    AppTheme.space6,
                    AppTheme.space6,
                    220,
                  ),
                  children: [
                    Row(
                      children: [
                        PressableScale(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusXl,
                              ),
                              border: Border.all(color: AppColors.white5),
                            ),
                            child: Icon(
                              LucideIcons.chevronLeft,
                              size: 24,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wifi Sharing',
                              style: tt.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: AppTheme.space1),
                            Text(
                              'VENUE MANAGEMENT',
                              style: tt.labelSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.2,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space6),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space6),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(color: AppColors.white5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.36),
                            blurRadius: 32,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.wifi,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppTheme.space3),
                              Text(
                                'NETWORK CONFIGURATION',
                                style: tt.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.9,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space6),
                          _WifiField(
                            label: 'NETWORK NAME (SSID)',
                            controller: _ssidCtrl,
                            hint: 'e.g. Lumina_Guest_Wifi',
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppTheme.space5),
                          _WifiField(
                            label: 'PASSWORD',
                            controller: _passCtrl,
                            hint: 'Network Password',
                            obscureText: _obscurePass,
                            onChanged: (_) => setState(() {}),
                            trailing: _passCtrl.text.trim().isEmpty
                                ? null
                                : PressableScale(
                                    onTap: () => setState(
                                      () => _obscurePass = !_obscurePass,
                                    ),
                                    child: Icon(
                                      _obscurePass
                                          ? LucideIcons.eyeOff
                                          : LucideIcons.eye,
                                      size: 18,
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: AppTheme.space5),
                          _WifiDropdownField(
                            label: 'SECURITY TYPE',
                            value: _security,
                            displayValue: _securityLabel,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _security = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: AppTheme.space6,
                  right: AppTheme.space6,
                  bottom: bottomInset + AppTheme.space6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (venue.hasWifi) ...[
                        TextButton(
                          onPressed: _saving ? null : () => _clearWifi(venue),
                          child: Text(
                            'CLEAR SAVED WIFI',
                            style: tt.labelSmall?.copyWith(
                              color: cs.error.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.space3),
                      ],
                      PressableScale(
                        onTap: _saving ? null : () => _save(venue),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius3xl,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.18,
                                ),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_saving)
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              else
                                Icon(
                                  LucideIcons.save,
                                  size: 16,
                                  color: AppColors.onPrimary,
                                ),
                              const SizedBox(width: AppTheme.space3),
                              Text(
                                'SAVE WIFI SETTINGS',
                                style: tt.labelLarge?.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Private Widgets ───

class _WifiField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;

  const _WifiField({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.trailing,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: cs.onSurfaceVariant.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppColors.white5),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: tt.titleMedium?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.42),
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space5,
                vertical: 20,
              ),
              suffixIcon: trailing == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: AppTheme.space4),
                      child: trailing,
                    ),
              suffixIconConstraints: const BoxConstraints(
                minHeight: 24,
                minWidth: 24,
              ),
            ),
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _WifiDropdownField extends StatelessWidget {
  final String label;
  final String value;
  final String displayValue;
  final ValueChanged<String?> onChanged;

  const _WifiDropdownField({
    required this.label,
    required this.value,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: cs.onSurfaceVariant.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space5),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppColors.white5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(
                LucideIcons.chevronDown,
                size: 18,
                color: AppColors.primary,
              ),
              dropdownColor: cs.surfaceContainerHigh,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              items: const [
                DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2/WPA3')),
                DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                DropdownMenuItem(value: 'Open', child: Text('Open Network')),
              ],
              onChanged: onChanged,
              selectedItemBuilder: (context) => [
                Text(displayValue),
                Text(displayValue),
                Text(displayValue),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
