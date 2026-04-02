import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/config/country_runtime.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/venue_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Admin venue detail screen with activation/deactivation controls.
/// Matches React admin/VenueDetail.tsx.
class AdminVenueDetailScreen extends ConsumerWidget {
  final String venueId;
  final Future<void> Function(String venueId, Map<String, dynamic> updates)?
  onUpdateVenueOverride;

  const AdminVenueDetailScreen({
    super.key,
    required this.venueId,
    this.onUpdateVenueOverride,
  });

  void _invalidateVenueCaches(WidgetRef ref, String venueId) {
    ref.invalidate(allVenuesProvider);
    ref.invalidate(venueByIdProvider(venueId));
  }

  Future<void> _showVenueAccessEditor(
    BuildContext context,
    WidgetRef ref,
    Venue venue,
    Future<void> Function(String venueId, Map<String, dynamic> updates)?
    onUpdateVenue,
  ) async {
    final config = CountryRuntime.config;
    final expectedPhoneLength = config.country.code == 'RW' ? 10 : 8;
    final controller = TextEditingController(
      text: normalizePhoneLocalInput(
        venue.effectiveAccessPhone ?? '',
        countryCode: config.defaultCountryCode,
        maxDigits: expectedPhoneLength,
      ),
    );
    var isSaving = false;
    final hadExistingAccessNumber = venue.hasAssignedAccessPhone;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final localPhone = normalizePhoneLocalInput(
              controller.text,
              countryCode: config.defaultCountryCode,
              maxDigits: expectedPhoneLength,
            );
            final canSave =
                !isSaving &&
                (isValidPhoneLocalInput(
                      controller.text,
                      countryCode: config.defaultCountryCode,
                      expectedLength: expectedPhoneLength,
                    ) ||
                    (hadExistingAccessNumber && localPhone.isEmpty));

            Future<void> save() async {
              if (!canSave) return;
              setSheetState(() => isSaving = true);
              try {
                final isClearing = localPhone.isEmpty;
                await (onUpdateVenue?.call(venue.id, {
                      'phone': isClearing
                          ? null
                          : '${config.countryDialCode}$localPhone',
                    }) ??
                    VenueRepository.instance.updateVenueAsAdmin(venue.id, {
                      'phone': isClearing
                          ? null
                          : '${config.countryDialCode}$localPhone',
                    }));
                _invalidateVenueCaches(ref, venue.id);
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isClearing
                            ? 'Venue WhatsApp access cleared'
                            : venue.isOpen
                            ? 'Venue WhatsApp access updated'
                            : 'WhatsApp saved. Activate the venue to validate access.',
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (sheetContext.mounted) {
                  setSheetState(() => isSaving = false);
                }
                final raw = error.toString();
                final message =
                    raw.contains('already assigned to another venue')
                    ? 'This WhatsApp number is already assigned to another venue.'
                    : 'Update failed: $error';
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.space4,
                AppTheme.space4,
                AppTheme.space4,
                MediaQuery.of(sheetContext).viewInsets.bottom + AppTheme.space4,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.space6),
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  border: Border.all(color: AppColors.white5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Venue WhatsApp Access',
                      style: Theme.of(sheetContext).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Text(
                      'Save the WhatsApp number assigned to this venue. Once the venue is active, staff can log in directly with OTP.',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(
                              sheetContext,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: AppTheme.space5),
                    CountryPhoneInput.fromConfig(
                      config: config,
                      controller: controller,
                      onChanged: (_) => setSheetState(() {}),
                      onSubmitted: canSave ? save : null,
                    ),
                    const SizedBox(height: AppTheme.space5),
                    SizedBox(
                      width: double.infinity,
                      child: PremiumButton(
                        label: isSaving
                            ? 'SAVING...'
                            : localPhone.isEmpty && hadExistingAccessNumber
                            ? 'CLEAR WHATSAPP NUMBER'
                            : 'SAVE WHATSAPP NUMBER',
                        icon: LucideIcons.messageCircle,
                        onPressed: canSave ? save : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venueAsync = ref.watch(venueByIdProvider(venueId));

    return Scaffold(
      body: venueAsync.when(
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 200),
        ),
        error: (err, _) => ErrorState(
          message: 'Could not load venue.',
          onRetry: () => ref.invalidate(venueByIdProvider(venueId)),
        ),
        data: (venue) {
          if (venue == null) {
            return Center(child: Text('Venue not found', style: tt.bodyLarge));
          }
          return _buildContent(context, ref, cs, tt, venue);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme cs,
    TextTheme tt,
    Venue venue,
  ) {
    return CustomScrollView(
      slivers: [
        // ─── Header ───
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppColors.white5),
                      ),
                      child: const Icon(LucideIcons.chevronLeft, size: 28),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ADMIN · VENUE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: cs.primary,
                          ),
                        ),
                        Text(
                          venue.name,
                          style: tt.headlineMedium?.copyWith(height: 1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── Info Card ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                border: Border.all(color: AppColors.white5),
                boxShadow: AppTheme.clayShadow,
              ),
              child: Column(
                children: [
                  _infoRow(tt, cs, 'Category', venue.category),
                  const SizedBox(height: AppTheme.space4),
                  Container(height: 1, color: AppColors.white5),
                  const SizedBox(height: AppTheme.space4),
                  _infoRow(tt, cs, 'Address', venue.address),
                  const SizedBox(height: AppTheme.space4),
                  Container(height: 1, color: AppColors.white5),
                  const SizedBox(height: AppTheme.space4),
                  _infoRow(
                    tt,
                    cs,
                    'Rating',
                    '${venue.rating} (${venue.ratingCount} reviews)',
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Container(height: 1, color: AppColors.white5),
                  const SizedBox(height: AppTheme.space4),
                  _infoRow(tt, cs, 'Status', venue.status.label),
                  const SizedBox(height: AppTheme.space4),
                  Container(height: 1, color: AppColors.white5),
                  const SizedBox(height: AppTheme.space4),
                  _infoRow(
                    tt,
                    cs,
                    'WhatsApp',
                    venue.phone?.trim().isNotEmpty == true
                        ? venue.phone!
                        : 'Not set',
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Container(height: 1, color: AppColors.white5),
                  const SizedBox(height: AppTheme.space4),
                  _infoRow(tt, cs, 'Country', venue.country.label),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          ),
        ),

        // ─── Admin Actions ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADMIN ACTIONS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.60),
                  ),
                ),
                const SizedBox(height: AppTheme.space4),

                Container(
                  padding: const EdgeInsets.all(AppTheme.space6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                    border: Border.all(color: AppColors.white5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Venue WhatsApp Access',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        venue.hasAssignedAccessPhone
                            ? venue.isAccessReady
                                  ? 'WhatsApp OTP login is ready for this venue.'
                                  : venue.isOpen
                                  ? 'Number saved. Complete OTP validation to finish access setup.'
                                  : 'Number saved. Activate the venue to validate access.'
                            : 'Add the venue WhatsApp number before staff can log in.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: venue.isAccessReady
                              ? cs.secondary
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showVenueAccessEditor(
                            context,
                            ref,
                            venue,
                            onUpdateVenueOverride,
                          ),
                          icon: const Icon(LucideIcons.messageCircle),
                          label: Text(
                            venue.hasAssignedAccessPhone
                                ? 'Edit WhatsApp Number'
                                : 'Add WhatsApp Number',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.space4),

                // Toggle activation
                Container(
                  padding: const EdgeInsets.all(AppTheme.space6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                    border: Border.all(color: AppColors.white5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Venue Activation',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            venue.isOpen
                                ? 'Venue is live and active'
                                : 'Venue is deactivated',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: venue.isOpen ? cs.secondary : cs.error,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: venue.isOpen,
                        onChanged: (_) async {
                          final newStatus = venue.isOpen
                              ? 'inactive'
                              : 'active';
                          try {
                            await VenueRepository.instance.updateVenueStatus(
                              venue.id,
                              newStatus,
                            );
                            _invalidateVenueCaches(ref, venue.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Venue ${venue.isOpen ? 'deactivated' : 'activated'}',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Update failed: $e')),
                              );
                            }
                          }
                        },
                        activeThumbColor: cs.secondary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.space4),

                Container(
                  padding: const EdgeInsets.all(AppTheme.space6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                    border: Border.all(color: AppColors.white5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            Text(
                              venue.orderingEnabled
                                  ? 'Guests can place orders for this venue'
                                  : 'Guests can browse only until validation is complete',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: venue.orderingEnabled
                                    ? cs.secondary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: venue.orderingEnabled,
                        onChanged: (_) async {
                          try {
                            await VenueRepository.instance
                                .updateVenueOrderingEnabled(
                                  venue.id,
                                  !venue.orderingEnabled,
                                );
                            _invalidateVenueCaches(ref, venue.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    venue.orderingEnabled
                                        ? 'Guest ordering disabled'
                                        : 'Guest ordering enabled',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Update failed: $e')),
                              );
                            }
                          }
                        },
                        activeThumbColor: cs.secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space12)),
      ],
    );
  }

  Widget _infoRow(TextTheme tt, ColorScheme cs, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: cs.onSurfaceVariant.withValues(alpha: 0.60),
          ),
        ),
        Text(
          value,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
