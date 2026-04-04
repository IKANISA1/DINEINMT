import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/services/venue_repository.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// Opening Hours manager — full-page screen.
///
/// Maintenance mode toggle + 7 day rows with open/close times and toggles.
/// Saves to Supabase via [VenueRepository.updateVenue].
class VenueHoursScreen extends ConsumerStatefulWidget {
  const VenueHoursScreen({super.key});

  @override
  ConsumerState<VenueHoursScreen> createState() => _VenueHoursScreenState();
}

class _VenueHoursScreenState extends ConsumerState<VenueHoursScreen> {
  bool _maintenanceMode = false;
  final Map<String, _DayHours> _schedule = {};
  bool _saving = false;
  bool _seeded = false;

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  void _seed(Venue venue) {
    if (_seeded) return;
    _seeded = true;
    _maintenanceMode = venue.status == VenueStatus.maintenance;
    for (final day in _days) {
      final h = venue.openingHours?[day];
      _schedule[day] = _DayHours(
        isOpen: h?.isOpen ?? true,
        open: h?.open ?? '09:00',
        close: h?.close ?? '22:00',
      );
    }
  }

  Future<void> _save(Venue venue) async {
    setState(() => _saving = true);
    try {
      // Build opening_hours JSON
      final hoursJson = <String, dynamic>{};
      for (final day in _days) {
        final d = _schedule[day]!;
        hoursJson[day] = {
          'is_open': d.isOpen,
          'open': d.open,
          'close': d.close,
        };
      }
      await VenueRepository.instance.updateVenue(venue.id, {
        'opening_hours': hoursJson,
        'status': _maintenanceMode ? 'maintenance' : 'active',
      });
      ref.invalidate(currentVenueProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hours updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save hours.')),
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
                          Text('Opening Hours',
                              style: tt.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                          Text('VENUE MANAGEMENT',
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

                  // ─── Maintenance Mode ───
                  PressableScale(
                    onTap: () => setState(
                        () => _maintenanceMode = !_maintenanceMode),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _maintenanceMode
                            ? AppColors.secondary.withValues(alpha: 0.15)
                            : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _maintenanceMode
                              ? AppColors.secondary
                                  .withValues(alpha: 0.30)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                        boxShadow: AppTheme.clayShadow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Maintenance Mode',
                                  style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('CLOSE VENUE TEMPORARILY',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    color: AppColors.secondary,
                                  )),
                            ],
                          ),
                          _MiniToggle(
                            isOn: _maintenanceMode,
                            onTap: () => setState(() =>
                                _maintenanceMode = !_maintenanceMode),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: AppTheme.space4),

                  // ─── Day Schedule ───
                  ..._days.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final day = entry.value;
                    final dh = _schedule[day]!;
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppTheme.space2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.05)),
                          boxShadow: AppTheme.clayShadow,
                        ),
                        child: Row(
                          children: [
                            // Day name
                            Expanded(
                              child: Text(day,
                                  style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700)),
                            ),
                            // Time range chip
                            PressableScale(
                              onTap: () => _editDayTimes(day, dh),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHigh,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Text(
                                  dh.isOpen
                                      ? '${dh.open}  -  ${dh.close}'
                                      : 'Closed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: dh.isOpen
                                        ? cs.onSurface
                                        : cs.error,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Toggle
                            _MiniToggle(
                              isOn: dh.isOpen,
                              onTap: () => setState(() =>
                                  _schedule[day] = dh.copyWith(
                                      isOpen: !dh.isOpen)),
                            ),
                          ],
                        ),
                      )
                          .animate(delay: (50 * idx).ms)
                          .fadeIn(duration: 250.ms),
                    );
                  }),
                ],
              ),

              // ─── Floating Save ───
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
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.24),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
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
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        else
                          Icon(LucideIcons.save,
                              size: 16, color: cs.onPrimary),
                        const SizedBox(width: 10),
                        Text('SAVE HOURS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: cs.onPrimary,
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

  void _editDayTimes(String day, _DayHours dh) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final openCtrl = TextEditingController(text: dh.open);
    final closeCtrl = TextEditingController(text: dh.close);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space6),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              Text('$day Hours',
                  style: tt.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: AppTheme.space5),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OPENS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: cs.onSurfaceVariant,
                            )),
                        const SizedBox(height: 6),
                        TextField(
                          controller: openCtrl,
                          decoration: InputDecoration(
                            hintText: '09:00',
                            filled: true,
                            fillColor: cs.surfaceContainerLow,
                          ),
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CLOSES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: cs.onSurfaceVariant,
                            )),
                        const SizedBox(height: 6),
                        TextField(
                          controller: closeCtrl,
                          decoration: InputDecoration(
                            hintText: '22:00',
                            filled: true,
                            fillColor: cs.surfaceContainerLow,
                          ),
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space5),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _schedule[day] = dh.copyWith(
                        open: openCtrl.text.trim(),
                        close: closeCtrl.text.trim(),
                      );
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
              const SizedBox(height: AppTheme.space3),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper classes ───

class _DayHours {
  final bool isOpen;
  final String open;
  final String close;

  const _DayHours({
    required this.isOpen,
    required this.open,
    required this.close,
  });

  _DayHours copyWith({bool? isOpen, String? open, String? close}) =>
      _DayHours(
        isOpen: isOpen ?? this.isOpen,
        open: open ?? this.open,
        close: close ?? this.close,
      );
}

/// Toggle knob matching the screenshot design.
class _MiniToggle extends StatelessWidget {
  final bool isOn;
  final VoidCallback onTap;
  const _MiniToggle({required this.isOn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: isOn
              ? AppColors.secondary.withValues(alpha: 0.40)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isOn ? AppColors.secondary : cs.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
