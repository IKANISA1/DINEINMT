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

/// Venue Profile editor — full-page screen.
///
/// Cover image with UPDATE COVER overlay → editable form fields →
/// SAVE CHANGES button. All saves go to Supabase via [VenueRepository].
class VenueProfileScreen extends ConsumerStatefulWidget {
  const VenueProfileScreen({super.key});

  @override
  ConsumerState<VenueProfileScreen> createState() => _VenueProfileScreenState();
}

class _VenueProfileScreenState extends ConsumerState<VenueProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _revolutCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();

  bool _saving = false;
  String? _seededId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _revolutCtrl.dispose();
    _coverCtrl.dispose();
    super.dispose();
  }

  void _seed(Venue venue) {
    if (_seededId == venue.id) return;
    _seededId = venue.id;
    _nameCtrl.text = venue.name;
    _categoryCtrl.text = venue.category;
    _descriptionCtrl.text = venue.description;
    _phoneCtrl.text = venue.phone ?? '';
    _addressCtrl.text = venue.address;
    _emailCtrl.text = venue.email ?? '';
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
        'description': _descriptionCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
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
          _seed(venue);
          return Stack(
            children: [
              ListView(
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
                            'Venue Profile',
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
                  const SizedBox(height: AppTheme.space6),

                  // ─── Cover Image ───
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: DineInImage(
                            imageUrl: _coverCtrl.text.trim().isNotEmpty
                                ? _coverCtrl.text.trim()
                                : venue.imageUrl,
                            fit: BoxFit.cover,
                            fallbackIcon: LucideIcons.camera,
                          ),
                        ),
                        // UPDATE COVER button
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showCoverUrlDialog(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.50),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.camera,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'UPDATE COVER',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: AppTheme.space6),

                  // ─── Form Fields ───
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
                    hint: '78 Villegaignon St, Mdina, Malta',
                    maxLines: 2,
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
                        color: AppColors.secondary.withValues(alpha: 0.30),
                      ),
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
                          Icon(LucideIcons.save, size: 16, color: cs.onSurface),
                        const SizedBox(width: 10),
                        Text(
                          'SAVE CHANGES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: cs.onSurface,
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
      ),
    );
  }

  void _showCoverUrlDialog(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final tt = Theme.of(ctx).textTheme;
    final urlCtrl = TextEditingController(text: _coverCtrl.text);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space6),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  fillColor: cs.surfaceContainerLow,
                ),
                style: tt.bodyMedium,
              ),
              const SizedBox(height: AppTheme.space5),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _coverCtrl.text = urlCtrl.text.trim();
                    });
                    Navigator.pop(ctx);
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

// ─── Private Widgets ───

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
          borderRadius: BorderRadius.circular(24),
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
                  color: AppColors.secondary.withValues(alpha: 0.70),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppColors.secondary.withValues(alpha: 0.70),
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
