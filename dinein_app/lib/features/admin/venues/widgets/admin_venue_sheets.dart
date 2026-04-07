import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:core_pkg/config/country_config.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/services/venue_repository.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';


/// Static methods for admin venue bottom sheets.
///
/// These are extracted from AdminVenueDetailScreen to reduce file size.
/// Each method shows a modal bottom sheet and returns via callback.
abstract final class AdminVenueSheets {
  /// Show the WhatsApp access phone editor.
  static Future<void> showAccessEditor({
    required BuildContext context,
    required Venue venue,
    required CountryConfig config,
    required TextEditingController phoneCtrl,
    required VoidCallback onCachesInvalidated,
    required Future<void> Function(String venueId, Map<String, dynamic> updates)?
        onUpdateVenueOverride,
  }) async {
    final expectedPhoneLength = config.localPhoneLength;
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
                final updates = {
                  'phone': isClearing
                      ? null
                      : '${config.countryDialCode}$localPhone',
                };
                await (onUpdateVenueOverride?.call(venue.id, updates) ??
                    VenueRepository.instance.updateVenueAsAdmin(
                      venue.id,
                      updates,
                    ));
                phoneCtrl.text = updates['phone']?.toString() ?? '';
                onCachesInvalidated();
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
                if (!context.mounted) return;
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
              } catch (error) {
                if (sheetContext.mounted) {
                  setSheetState(() => isSaving = false);
                }
                final raw = error.toString();
                final message =
                    raw.contains('already assigned to another venue')
                    ? 'This WhatsApp number is already assigned to another venue.'
                    : 'Update failed: $error';
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              }
            }

            final cs = Theme.of(sheetContext).colorScheme;
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
                  color: cs.surface,
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

  /// Show QR code bottom sheet.
  static void showQr({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Uri uri,
    required Future<void> Function(String label, Uri uri) onCopyLink,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: QrImageView(
                  data: uri.toString(),
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              PremiumButton(
                label: 'COPY URL',
                icon: LucideIcons.copy,
                isOutlined: true,
                onPressed: () => onCopyLink(title, uri),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
