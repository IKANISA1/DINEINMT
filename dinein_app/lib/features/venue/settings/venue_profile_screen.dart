import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:core_pkg/config/country_runtime.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/google_places_service.dart';
import 'package:dinein_app/core/services/image_upload_service.dart';
import 'package:dinein_app/core/services/venue_repository.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

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
  final _momoCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();

  bool _saving = false;
  bool _syncingProfile = false;
  bool _uploadingCover = false;
  String? _seededId;

  // Address autocomplete state
  List<PlaceAutocompleteSuggestion> _addressSuggestions = const [];
  bool _showAddressSuggestions = false;
  Timer? _debounceTimer;
  final _addressFocusNode = FocusNode();

  Country get _country => CountryRuntime.config.country;

  @override
  void initState() {
    super.initState();
    _addressFocusNode.addListener(() {
      if (!_addressFocusNode.hasFocus && mounted) {
        // Delay hide so tap on suggestion can register
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showAddressSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _addressFocusNode.dispose();
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _revolutCtrl.dispose();
    _momoCtrl.dispose();
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
    _momoCtrl.text = venue.momoCode ?? '';
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
      final updates = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'image_url': _coverCtrl.text.trim().isEmpty
            ? null
            : _coverCtrl.text.trim(),
      };

      // Country-aware payment field
      if (_country == Country.mt) {
        updates['revolut_url'] = _revolutCtrl.text.trim().isEmpty
            ? null
            : _revolutCtrl.text.trim();
      } else if (_country == Country.rw) {
        updates['momo_code'] = _momoCtrl.text.trim().isEmpty
            ? null
            : _momoCtrl.text.trim();
      }

      await VenueRepository.instance.updateVenue(venue.id, updates);
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
      // Reset seeded ID so the form re-seeds with updated data (including address)
      _seededId = null;
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

  Future<void> _uploadCoverImage(Venue venue) async {
    if (_uploadingCover) return;
    setState(() => _uploadingCover = true);
    try {
      final url = await ImageUploadService.instance
          .pickAndUploadVenueImage(venue.id);
      if (url == null) {
        // User cancelled the picker
        return;
      }
      // Update local controller so the preview refreshes immediately
      setState(() => _coverCtrl.text = url);
      ref.invalidate(currentVenueProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cover image uploaded.')),
      );
    } on ImageUploadException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload cover image.')),
      );
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  void _onAddressChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _addressSuggestions = const [];
        _showAddressSuggestions = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      try {
        final results =
            await GooglePlacesService.instance.autocomplete(value);
        if (!mounted) return;
        setState(() {
          _addressSuggestions = results;
          _showAddressSuggestions = results.isNotEmpty;
        });
      } catch (_) {
        // Silently fail — user can still type manually
      }
    });
  }

  Future<void> _onSuggestionSelected(PlaceAutocompleteSuggestion s) async {
    setState(() {
      _addressCtrl.text = s.description;
      _addressSuggestions = const [];
      _showAddressSuggestions = false;
    });

    // Fetch full details to get precise formatted address
    try {
      final details =
          await GooglePlacesService.instance.getPlaceDetails(s.placeId);
      if (details != null && mounted) {
        setState(() {
          if (details.formattedAddress.isNotEmpty) {
            _addressCtrl.text = details.formattedAddress;
          }
        });
      }
    } catch (_) {
      // Keep the autocomplete description as fallback
    }
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
            subtitle: 'No venue linked to this account.',
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
                        onTap: _uploadingCover
                            ? null
                            : () => _uploadCoverImage(venue),
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
                              if (_uploadingCover)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Icon(
                                  LucideIcons.upload,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              const SizedBox(width: AppTheme.space3),
                              Text(
                                _uploadingCover
                                    ? 'UPLOADING...'
                                    : 'UPLOAD COVER',
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
                // Country-aware payment field
                if (_country == Country.mt)
                  _ProfileField(
                    icon: LucideIcons.externalLink,
                    label: 'REVOLUT LINK',
                    controller: _revolutCtrl,
                    hint: 'https://revolut.me/yourvenue',
                    keyboardType: TextInputType.url,
                  )
                else if (_country == Country.rw)
                  _ProfileField(
                    icon: LucideIcons.smartphone,
                    label: 'MOMO CODE',
                    controller: _momoCtrl,
                    hint: '078XXXXXXX',
                    keyboardType: TextInputType.phone,
                  ),
                _ProfileField(
                  icon: LucideIcons.phone,
                  label: 'CONCIERGE PHONE',
                  controller: _phoneCtrl,
                  hint: _country == Country.rw
                      ? '+250 788 123 456'
                      : '+356 2123 4567',
                  keyboardType: TextInputType.phone,
                ),
                // Address with Google Places autocomplete
                _AddressAutocompleteField(
                  controller: _addressCtrl,
                  focusNode: _addressFocusNode,
                  suggestions: _addressSuggestions,
                  showSuggestions: _showAddressSuggestions,
                  onChanged: _onAddressChanged,
                  onSuggestionSelected: _onSuggestionSelected,
                  hint: _country == Country.rw
                      ? 'KG 9 Ave, Kigali, Rwanda'
                      : '45 Tower Rd, Sliema, Malta',
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

  const _ProfileField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
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

/// Address field with Google Places autocomplete dropdown.
class _AddressAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<PlaceAutocompleteSuggestion> suggestions;
  final bool showSuggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<PlaceAutocompleteSuggestion> onSuggestionSelected;
  final String hint;

  const _AddressAutocompleteField({
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.showSuggestions,
    required this.onChanged,
    required this.onSuggestionSelected,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: showSuggestions
                    ? AppColors.primary.withValues(alpha: 0.30)
                    : Colors.white.withValues(alpha: 0.05),
              ),
              boxShadow: AppTheme.clayShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.mapPin,
                      size: 13,
                      color: AppColors.primary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ADDRESS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.primary.withValues(alpha: 0.85),
                      ),
                    ),
                    const Spacer(),
                    if (GooglePlacesService.instance.isConfigured)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.search,
                            size: 10,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.40),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'POWERED BY GOOGLE',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color:
                                  cs.onSurfaceVariant.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 3,
                  minLines: 1,
                  onChanged: onChanged,
                  decoration: InputDecoration.collapsed(hintText: hint),
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // Suggestions dropdown
          if (showSuggestions && suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: suggestions.map((suggestion) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSuggestionSelected(suggestion),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.mapPin,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      suggestion.mainText,
                                      style: tt.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (suggestion.secondaryText.isNotEmpty)
                                      Text(
                                        suggestion.secondaryText,
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                LucideIcons.arrowUpLeft,
                                size: 14,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.30),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
