import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// Venue Language & Region settings — full-page screen.
///
/// Layout (matching screenshot):
///   Back + Header → DISPLAY LANGUAGE grid (4 chips) →
///   REGIONAL SETTINGS (Currency, Timezone, Date Format)
///
/// Preferences are local-only for now (not persisted to Supabase).
class VenueLanguageRegionScreen extends ConsumerStatefulWidget {
  const VenueLanguageRegionScreen({super.key});

  @override
  ConsumerState<VenueLanguageRegionScreen> createState() =>
      _VenueLanguageRegionScreenState();
}

class _VenueLanguageRegionScreenState
    extends ConsumerState<VenueLanguageRegionScreen> {
  String _selectedLanguage = 'English';

  static const _languages = ['English', 'Maltese', 'Italian', 'French'];

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
              subtitle: 'No venue linked to this account.',
            );
          }

          return ListView(
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
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Icon(LucideIcons.chevronLeft,
                          size: 18, color: cs.onSurface),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Language & Region',
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
              const SizedBox(height: AppTheme.space8),

              // ─── Section: DISPLAY LANGUAGE ───
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('DISPLAY LANGUAGE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                    )),
              ),
              const SizedBox(height: AppTheme.space4),

              // ─── Language Chips (2×2 grid) ───
              Wrap(
                spacing: AppTheme.space3,
                runSpacing: AppTheme.space3,
                children: _languages.map((lang) {
                  final selected = lang == _selectedLanguage;
                  return PressableScale(
                    onTap: () => setState(() => _selectedLanguage = lang),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: (MediaQuery.of(context).size.width -
                              AppTheme.space6 * 2 -
                              AppTheme.space3) /
                          2,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.secondary.withValues(alpha: 0.25)
                            : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.secondary.withValues(alpha: 0.40)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                        boxShadow: AppTheme.clayShadow,
                      ),
                      child: Center(
                        child: Text(lang,
                            style: tt.titleSmall?.copyWith(
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                              color: selected
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            )),
                      ),
                    ),
                  );
                }).toList(),
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0, duration: 300.ms),

              const SizedBox(height: AppTheme.space8),

              // ─── Section: REGIONAL SETTINGS ───
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('REGIONAL SETTINGS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                    )),
              ),
              const SizedBox(height: AppTheme.space3),

              _RegionalTile(
                icon: LucideIcons.creditCard,
                iconColor: cs.primary,
                label: 'CURRENCY',
                value: 'EUR (€)',
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 100.ms)
                  .slideY(
                      begin: 0.05, end: 0, duration: 300.ms, delay: 100.ms),
              const SizedBox(height: AppTheme.space2),

              _RegionalTile(
                icon: LucideIcons.clock,
                iconColor: AppColors.secondary,
                label: 'TIMEZONE',
                value: 'CET (Valletta)',
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 200.ms)
                  .slideY(
                      begin: 0.05, end: 0, duration: 300.ms, delay: 200.ms),
              const SizedBox(height: AppTheme.space2),

              _RegionalTile(
                icon: LucideIcons.clock4,
                iconColor: AppColors.secondary.withValues(alpha: 0.70),
                label: 'DATE FORMAT',
                value: 'DD/MM/YYYY',
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 300.ms)
                  .slideY(
                      begin: 0.05, end: 0, duration: 300.ms, delay: 300.ms),
            ],
          );
        },
      ),
    );
  }
}

// ─── Private Widgets ───

class _RegionalTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _RegionalTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
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
            child: Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                )),
          ),
          Text(value,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              )),
        ],
      ),
    );
  }
}
