import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/venue_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

class VenueProfileScreen extends ConsumerStatefulWidget {
  const VenueProfileScreen({super.key});

  @override
  ConsumerState<VenueProfileScreen> createState() => _VenueProfileScreenState();
}

class _VenueProfileScreenState extends ConsumerState<VenueProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _revolutCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();

  bool _saving = false;
  bool _syncingProfile = false;
  String? _seededId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _revolutCtrl.dispose();
    _coverCtrl.dispose();
    super.dispose();
  }

  void _seed(Venue venue) {
    if (_seededId == venue.id) return;
    _seededId = venue.id;
    _nameCtrl.text = venue.name;
    _categoryCtrl.text = venue.category;
    _phoneCtrl.text = venue.phone ?? '';
    _addressCtrl.text = venue.address;
    _revolutCtrl.text = venue.revolutUrl ?? '';
    _coverCtrl.text = venue.imageUrl ?? '';
  }

  Future<void> _save(Venue venue) async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Venue name is required.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await VenueRepository.instance.updateVenue(venue.id, {
        'name': _nameCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'revolut_url': _revolutCtrl.text.trim().isEmpty
            ? null
            : _revolutCtrl.text.trim(),
        'image_url': _coverCtrl.text.trim().isEmpty
            ? null
            : _coverCtrl.text.trim(),
      });
      ref.invalidate(currentVenueProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save profile.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncProfileData(Venue venue) async {
    if (_syncingProfile) return;
    setState(() => _syncingProfile = true);
    try {
      await VenueRepository.instance.enrichVenueProfile(venue.id);
      ref.invalidate(currentVenueProvider);
      ref.invalidate(venueByIdProvider(venue.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venue discovery data refreshed.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not refresh venue discovery data.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncingProfile = false);
    }
  }

  void _showCoverUrlDialog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final urlCtrl = TextEditingController(text: _coverCtrl.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppTheme.space4,
          right: AppTheme.space4,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTheme.space4,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cover Image URL',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppTheme.space4),
              TextField(
                controller: urlCtrl,
                keyboardType: TextInputType.url,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'https://images.example.com/venue.jpg',
                  filled: true,
                  fillColor: cs.surface,
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              PressableScale(
                onTap: () {
                  setState(() => _coverCtrl.text = urlCtrl.text.trim());
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Text(
                      'APPLY',
                      style: tt.labelLarge?.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venueAsync = ref.watch(currentVenueProvider);

    return venueAsync.when(
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

        _seed(venue);

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                AppTheme.space6,
                AppTheme.space6,
                170,
              ),
              children: [
                Row(
                  children: [
                    PressableScale(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          context.pop();
                        } else {
                          context.goNamed(AppRouteNames.venueSettings);
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Icon(
                          LucideIcons.chevronLeft,
                          size: 22,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Venue Profile',
                          style: tt.headlineLarge?.copyWith(
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
                const SizedBox(height: AppTheme.space6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 210,
                        width: double.infinity,
                        child: DineInImage(
                          imageUrl: _coverCtrl.text.trim().isNotEmpty
                              ? _coverCtrl.text.trim()
                              : venue.imageUrl,
                          fit: BoxFit.cover,
                          fallbackIcon: LucideIcons.camera,
                        ),
                      ),
                      PressableScale(
                        onTap: () => _showCoverUrlDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF4B4430,
                            ).withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.camera,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: AppTheme.space3),
                              Text(
                                'UPDATE COVER',
                                style: tt.labelLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: AppTheme.space6),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    boxShadow: AppTheme.clayShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Discovery Data',
                                  style: tt.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Keep Maps data, review summaries, and geo metadata current for the guest web experience.',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (venue.enrichmentStatus != null)
                            StatusBadge(
                              label: venue.enrichmentStatus!,
                              color: AppColors.primary.withValues(alpha: 0.12),
                              textColor: AppColors.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusBadge(
                            label: '${venue.ratingCount} ratings',
                            color: cs.surfaceContainerHigh,
                            textColor: cs.onSurfaceVariant,
                          ),
                          if (venue.priceLevelLabel != null)
                            StatusBadge(
                              label: venue.priceLevelLabel!,
                              color: cs.surfaceContainerHigh,
                              textColor: cs.onSurfaceVariant,
                            ),
                          StatusBadge(
                            label:
                                venue.latitude != null &&
                                    venue.longitude != null
                                ? 'Geo Ready'
                                : 'Geo Missing',
                            color:
                                venue.latitude != null &&
                                    venue.longitude != null
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : cs.error.withValues(alpha: 0.12),
                            textColor:
                                venue.latitude != null &&
                                    venue.longitude != null
                                ? AppColors.primary
                                : cs.error,
                          ),
                        ],
                      ),
                      if (venue.primaryReviewSnippet != null) ...[
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          venue.primaryReviewSnippet!,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.55,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTheme.space5),
                      SizedBox(
                        width: double.infinity,
                        child: PressableScale(
                          onTap: _syncingProfile
                              ? null
                              : () => _syncProfileData(venue),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_syncingProfile)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onPrimary,
                                    ),
                                  )
                                else
                                  const Icon(
                                    LucideIcons.sparkles,
                                    size: 16,
                                    color: AppColors.onPrimary,
                                  ),
                                const SizedBox(width: 10),
                                Text(
                                  _syncingProfile
                                      ? 'SYNCING...'
                                      : 'SYNC PROFILE DATA',
                                  style: TextStyle(
                                    color: AppColors.onPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                _ProfileField(
                  icon: LucideIcons.user,
                  label: 'VENUE NAME',
                  controller: _nameCtrl,
                  hint: 'The Golden Spoon',
                ),
                _ProfileField(
                  icon: LucideIcons.chefHat,
                  label: 'CUISINE TYPE',
                  controller: _categoryCtrl,
                  hint: 'Modern Mediterranean',
                ),
                _ProfileField(
                  icon: LucideIcons.externalLink,
                  label: 'REVOLUT LINK',
                  controller: _revolutCtrl,
                  hint: 'https://revolut.me/yourvenue',
                  keyboardType: TextInputType.url,
                ),
                _ProfileField(
                  icon: LucideIcons.phone,
                  label: 'CONCIERGE PHONE',
                  controller: _phoneCtrl,
                  hint: '+356 2123 4567',
                  keyboardType: TextInputType.phone,
                ),
                _ProfileField(
                  icon: LucideIcons.mapPin,
                  label: 'ADDRESS',
                  controller: _addressCtrl,
                  hint: '45 Tower Rd, Sliema, Malta',
                  maxLines: 3,
                ),
              ],
            ),
            Positioned(
              left: AppTheme.space6,
              right: AppTheme.space6,
              bottom: 100,
              child: PressableScale(
                onTap: _saving ? null : () => _save(venue),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_saving)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      else
                        const Icon(
                          LucideIcons.save,
                          size: 16,
                          color: AppColors.onPrimary,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        'SAVE CHANGES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;

  const _ProfileField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
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
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: AppTheme.clayShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppColors.primary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
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
