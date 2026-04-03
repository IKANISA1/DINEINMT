import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/country_config_provider.dart';
import '../../../core/constants/app_download_links.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/venue_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

class AdminVenueDetailScreen extends ConsumerStatefulWidget {
  final String? venueId;
  final Venue? initialVenueOverride;
  final Future<void> Function(String venueId, Map<String, dynamic> updates)?
  onUpdateVenueOverride;

  const AdminVenueDetailScreen({
    super.key,
    this.venueId,
    this.initialVenueOverride,
    this.onUpdateVenueOverride,
  });

  bool get isCreate => venueId == null;

  @override
  ConsumerState<AdminVenueDetailScreen> createState() =>
      _AdminVenueDetailScreenState();
}

class _AdminVenueDetailScreenState
    extends ConsumerState<AdminVenueDetailScreen> {
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _reservationCtrl = TextEditingController();
  final _revolutCtrl = TextEditingController();
  final _wifiSsidCtrl = TextEditingController();
  final _wifiPasswordCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();

  static const _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final Map<String, _DayHours> _schedule = <String, _DayHours>{};
  VenueStatus _status = VenueStatus.inactive;
  bool _orderingEnabled = false;
  String _wifiSecurity = 'WPA';
  bool _saving = false;
  String? _seededKey;
  bool _slugDirty = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _imageCtrl.dispose();
    _websiteCtrl.dispose();
    _reservationCtrl.dispose();
    _revolutCtrl.dispose();
    _wifiSsidCtrl.dispose();
    _wifiPasswordCtrl.dispose();
    _instagramCtrl.dispose();
    _facebookCtrl.dispose();
    _tiktokCtrl.dispose();
    super.dispose();
  }

  void _invalidateVenueCaches(String? venueId) {
    ref.invalidate(allVenuesProvider);
    if (venueId != null) {
      ref.invalidate(venueByIdProvider(venueId));
    }
  }

  void _seed(Venue? venue) {
    final seedKey = venue?.id ?? '__new__';
    if (_seededKey == seedKey) return;
    _seededKey = seedKey;

    _nameCtrl.text = venue?.name ?? '';
    _slugCtrl.text = venue?.slug ?? '';
    _categoryCtrl.text = venue?.category ?? 'restaurant';
    _descriptionCtrl.text = venue?.description ?? '';
    _addressCtrl.text = venue?.address ?? '';
    _phoneCtrl.text = venue?.phone ?? '';
    _emailCtrl.text = venue?.email ?? '';
    _imageCtrl.text = venue?.imageUrl ?? '';
    _websiteCtrl.text = venue?.websiteUrl ?? '';
    _reservationCtrl.text = venue?.reservationUrl ?? '';
    _revolutCtrl.text = venue?.revolutUrl ?? '';
    _wifiSsidCtrl.text = venue?.wifiSsid ?? '';
    _wifiPasswordCtrl.text = venue?.wifiPassword ?? '';
    _instagramCtrl.text = venue?.socialLinks?['instagram'] ?? '';
    _facebookCtrl.text = venue?.socialLinks?['facebook'] ?? '';
    _tiktokCtrl.text = venue?.socialLinks?['tiktok'] ?? '';
    _wifiSecurity = venue?.wifiSecurity ?? 'WPA';
    _status = venue?.status ?? VenueStatus.inactive;
    _orderingEnabled = venue?.orderingEnabled ?? false;
    _slugDirty = venue != null;

    _schedule.clear();
    for (final day in _days) {
      final hours = venue?.openingHours?[day];
      _schedule[day] = _DayHours(
        isOpen: hours?.isOpen ?? true,
        open: hours?.open ?? '09:00',
        close: hours?.close ?? '22:00',
      );
    }
  }

  void _handleNameChanged(String value) {
    if (_slugDirty) return;
    final generated = _slugify(value);
    _slugCtrl
      ..text = generated
      ..selection = TextSelection.collapsed(offset: generated.length);
    setState(() {});
  }

  String _slugify(String value) {
    final normalized = value.trim().toLowerCase();
    final collapsed = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return collapsed;
  }

  Map<String, dynamic> _buildOpeningHoursPayload() {
    return {for (final day in _days) day: _schedule[day]!.toJson()};
  }

  Map<String, String> _buildSocialLinksPayload() {
    final payload = <String, String>{};
    void addIfPresent(String key, String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        payload[key] = trimmed;
      }
    }

    addIfPresent('instagram', _instagramCtrl.text);
    addIfPresent('facebook', _facebookCtrl.text);
    addIfPresent('tiktok', _tiktokCtrl.text);
    return payload;
  }

  Future<void> _save(Venue? venue) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Venue name is required.');
      return;
    }

    final slug = _slugify(
      _slugCtrl.text.trim().isEmpty ? name : _slugCtrl.text.trim(),
    );
    if (slug.isEmpty) {
      _showSnack('Venue slug is required.');
      return;
    }

    final config = ref.read(countryConfigProvider);
    final wifiSsid = _wifiSsidCtrl.text.trim();
    final wifiPassword = _wifiPasswordCtrl.text.trim();

    final updates = <String, dynamic>{
      'name': name,
      'slug': slug,
      'category': _categoryCtrl.text.trim().isEmpty
          ? 'restaurant'
          : _categoryCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'image_url': _imageCtrl.text.trim().isEmpty
          ? null
          : _imageCtrl.text.trim(),
      'website_url': _websiteCtrl.text.trim().isEmpty
          ? null
          : _websiteCtrl.text.trim(),
      'reservation_url': _reservationCtrl.text.trim().isEmpty
          ? null
          : _reservationCtrl.text.trim(),
      'revolut_url': _revolutCtrl.text.trim().isEmpty
          ? null
          : _revolutCtrl.text.trim(),
      'wifi_ssid': wifiSsid.isEmpty ? null : wifiSsid,
      'wifi_password': wifiSsid.isEmpty
          ? null
          : (wifiPassword.isEmpty ? null : wifiPassword),
      'wifi_security': wifiSsid.isEmpty ? null : _wifiSecurity,
      'social_links': _buildSocialLinksPayload(),
      'opening_hours': _buildOpeningHoursPayload(),
      'status': _status.dbValue,
      'ordering_enabled': _orderingEnabled,
      'country': config.country.code,
    };

    setState(() => _saving = true);
    try {
      if (widget.isCreate) {
        final created = await VenueRepository.instance.createVenue(updates);
        _invalidateVenueCaches(created.id);
        if (!mounted) return;
        _showSnack('Venue created.');
        context.goNamed(
          AppRouteNames.adminVenueDetail,
          pathParameters: {AppRouteParams.id: created.id},
        );
      } else {
        final venueId = widget.venueId!;
        await (widget.onUpdateVenueOverride?.call(venueId, updates) ??
            VenueRepository.instance.updateVenueAsAdmin(venueId, updates));
        _invalidateVenueCaches(venueId);
        if (!mounted) return;
        _showSnack('Venue updated.');
      }
    } catch (error) {
      _showSnack('Could not save venue: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _showVenueAccessEditor(Venue venue) async {
    final config = ref.read(countryConfigProvider);
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
                final updates = {
                  'phone': isClearing
                      ? null
                      : '${config.countryDialCode}$localPhone',
                };
                await (widget.onUpdateVenueOverride?.call(venue.id, updates) ??
                    VenueRepository.instance.updateVenueAsAdmin(
                      venue.id,
                      updates,
                    ));
                _phoneCtrl.text = updates['phone']?.toString() ?? '';
                _invalidateVenueCaches(venue.id);
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
                if (!mounted) return;
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
                if (!mounted) return;
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

  Future<void> _copyLink(String label, Uri uri) async {
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    _showSnack('$label copied.');
  }

  Future<void> _openLink(String label, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    _showSnack('Unable to open $label.');
  }

  void _showQrSheet({
    required String title,
    required String subtitle,
    required Uri uri,
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                onPressed: () => _copyLink(title, uri),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editDayTimes(String day) {
    final hours = _schedule[day]!;
    final openCtrl = TextEditingController(text: hours.open);
    final closeCtrl = TextEditingController(text: hours.close);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.space4,
            AppTheme.space4,
            AppTheme.space4,
            MediaQuery.of(ctx).viewInsets.bottom + AppTheme.space4,
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
                  '$day Hours',
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Row(
                  children: [
                    Expanded(
                      child: _InlineField(
                        label: 'OPEN',
                        controller: openCtrl,
                        hint: '09:00',
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Expanded(
                      child: _InlineField(
                        label: 'CLOSE',
                        controller: closeCtrl,
                        hint: '22:00',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space4),
                PremiumButton(
                  label: 'APPLY HOURS',
                  icon: LucideIcons.check,
                  onPressed: () {
                    setState(() {
                      _schedule[day] = hours.copyWith(
                        open: openCtrl.text.trim().isEmpty
                            ? hours.open
                            : openCtrl.text.trim(),
                        close: closeCtrl.text.trim().isEmpty
                            ? hours.close
                            : closeCtrl.text.trim(),
                      );
                    });
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final seededVenue = widget.initialVenueOverride;
    if (seededVenue != null) {
      _seed(seededVenue);
      return _buildScaffold(context, seededVenue);
    }

    if (widget.isCreate) {
      _seed(null);
      return _buildScaffold(context, null);
    }

    final venueAsync = ref.watch(venueByIdProvider(widget.venueId!));
    return venueAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: SkeletonLoader(width: double.infinity, height: 260),
        ),
      ),
      error: (_, _) => Scaffold(
        body: ErrorState(
          message: 'Could not load venue.',
          onRetry: () => ref.invalidate(venueByIdProvider(widget.venueId!)),
        ),
      ),
      data: (venue) {
        if (venue == null) {
          return const Scaffold(
            body: EmptyState(
              icon: LucideIcons.store,
              title: 'Venue not found',
              subtitle: 'The selected venue could not be loaded.',
            ),
          );
        }
        _seed(venue);
        return _buildScaffold(context, venue);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Venue? venue) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final config = ref.watch(countryConfigProvider);
    final slug = _slugify(_slugCtrl.text);
    final guestUri = slug.isEmpty
        ? null
        : buildVenueDeepLinkUri(slug: slug, config: config);
    final appUri = slug.isEmpty
        ? null
        : buildVenueDownloadRedirectUri(
            slug: slug,
            config: config,
            venueName: _nameCtrl.text.trim(),
          );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                AppTheme.space6,
                AppTheme.space6,
                160,
              ),
              children: [
                Row(
                  children: [
                    PressableScale(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          context.pop();
                        } else {
                          context.goNamed(AppRouteNames.adminVenues);
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.white5),
                        ),
                        child: Icon(
                          LucideIcons.chevronLeft,
                          size: 22,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isCreate ? 'New Venue' : 'Venue Management',
                            style: tt.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            widget.isCreate
                                ? 'CREATE ADMIN VENUE'
                                : 'ADMIN · VENUE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (venue != null)
                      StatusBadge(
                        label: venue.status.label,
                        color: venue.status == VenueStatus.active
                            ? cs.secondary.withValues(alpha: 0.12)
                            : cs.error.withValues(alpha: 0.12),
                        textColor: venue.status == VenueStatus.active
                            ? cs.secondary
                            : cs.error,
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.space6),
                ClayCard(
                  padding: const EdgeInsets.all(AppTheme.space5),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: DineInImage(
                            imageUrl: _imageCtrl.text.trim().isEmpty
                                ? venue?.imageUrl
                                : _imageCtrl.text.trim(),
                            fit: BoxFit.cover,
                            fallbackIcon: LucideIcons.store,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameCtrl.text.trim().isEmpty
                                  ? 'Venue preview'
                                  : _nameCtrl.text.trim(),
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              slug.isEmpty ? 'slug-pending' : slug,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppTheme.space3),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatusBadge(
                                  label: _status.label,
                                  color: _status == VenueStatus.active
                                      ? cs.secondary.withValues(alpha: 0.12)
                                      : cs.surfaceContainerHighest,
                                  textColor: _status == VenueStatus.active
                                      ? cs.secondary
                                      : cs.onSurface,
                                ),
                                StatusBadge(
                                  label: _orderingEnabled
                                      ? 'Ordering Enabled'
                                      : 'Browse Only',
                                  color: _orderingEnabled
                                      ? cs.primary.withValues(alpha: 0.12)
                                      : cs.surfaceContainerHighest,
                                  textColor: _orderingEnabled
                                      ? cs.primary
                                      : cs.onSurface,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                _SectionCard(
                  title: 'Core Details',
                  children: [
                    _LabeledField(
                      label: 'NAME',
                      controller: _nameCtrl,
                      hint: 'Harbor Table',
                      onChanged: _handleNameChanged,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'SLUG',
                            controller: _slugCtrl,
                            hint: 'harbor-table',
                            onChanged: (_) {
                              _slugDirty = true;
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Expanded(
                          child: _LabeledField(
                            label: 'CATEGORY',
                            controller: _categoryCtrl,
                            hint: 'restaurant',
                          ),
                        ),
                      ],
                    ),
                    _LabeledField(
                      label: 'ADDRESS',
                      controller: _addressCtrl,
                      hint: config.addressHint,
                    ),
                    _LabeledField(
                      label: 'DESCRIPTION',
                      controller: _descriptionCtrl,
                      hint: 'Short guest-facing venue summary',
                      maxLines: 4,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space4),
                _SectionCard(
                  title: 'Profile Data',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'PHONE',
                            controller: _phoneCtrl,
                            hint: '${config.countryDialCode}...',
                          ),
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Expanded(
                          child: _LabeledField(
                            label: 'EMAIL',
                            controller: _emailCtrl,
                            hint: 'venue@example.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    _LabeledField(
                      label: 'IMAGE URL',
                      controller: _imageCtrl,
                      hint: 'https://images.example.com/venue.jpg',
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() {}),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'WEBSITE',
                            controller: _websiteCtrl,
                            hint: 'https://venue.example.com',
                            keyboardType: TextInputType.url,
                          ),
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Expanded(
                          child: _LabeledField(
                            label: 'RESERVATION URL',
                            controller: _reservationCtrl,
                            hint: 'https://reserve.example.com',
                            keyboardType: TextInputType.url,
                          ),
                        ),
                      ],
                    ),
                    _LabeledField(
                      label: 'REVOLUT URL',
                      controller: _revolutCtrl,
                      hint: 'https://revolut.me/venue',
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space4),
                _SectionCard(
                  title: 'Operational Controls',
                  children: [
                    DropdownButtonFormField<VenueStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'STATUS'),
                      items: VenueStatus.values
                          .map((status) {
                            return DropdownMenuItem<VenueStatus>(
                              value: status,
                              child: Text(status.label),
                            );
                          })
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                      },
                    ),
                    const SizedBox(height: AppTheme.space4),
                    SwitchListTile(
                      value: _orderingEnabled,
                      onChanged: (value) =>
                          setState(() => _orderingEnabled = value),
                      title: const Text('Guest ordering enabled'),
                      subtitle: const Text(
                        'When off, guests can browse the menu but cannot order.',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: AppTheme.space2),
                    if (venue != null)
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Venue WhatsApp Access',
                                    style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    venue.hasAssignedAccessPhone
                                        ? venue.effectiveAccessPhone!
                                        : 'No WhatsApp access number assigned.',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppTheme.space4),
                            PremiumButton(
                              label: venue.hasAssignedAccessPhone
                                  ? 'Edit WhatsApp Number'
                                  : 'Add WhatsApp Number',
                              icon: LucideIcons.messageCircle,
                              isOutlined: true,
                              isSmall: true,
                              onPressed: () => _showVenueAccessEditor(venue),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        'Save the venue first to manage WhatsApp access and QR sharing.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.space4),
                _SectionCard(
                  title: 'Guest Access',
                  children: [
                    if (guestUri == null || appUri == null)
                      Text(
                        'Enter a valid slug to generate the guest URL, venue app URL, and guest QR code.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    else ...[
                      _LinkAccessRow(
                        label: 'Guest URL',
                        value: guestUri.toString(),
                        onCopy: () => _copyLink('Guest URL', guestUri),
                        onOpen: () => _openLink('Guest URL', guestUri),
                      ),
                      const SizedBox(height: AppTheme.space3),
                      _LinkAccessRow(
                        label: 'Venue App URL',
                        value: appUri.toString(),
                        onCopy: () => _copyLink('Venue app URL', appUri),
                        onOpen: () => _openLink('Venue app URL', appUri),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Row(
                        children: [
                          Expanded(
                            child: _QrPreviewCard(
                              label: 'Guest View QR',
                              uri: guestUri,
                              onTap: () => _showQrSheet(
                                title: '${_nameCtrl.text.trim()} guest view',
                                subtitle:
                                    'Guests open the direct venue experience.',
                                uri: guestUri,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Expanded(
                            child: _QrPreviewCard(
                              label: 'Venue App QR',
                              uri: appUri,
                              onTap: () => _showQrSheet(
                                title: '${_nameCtrl.text.trim()} venue app',
                                subtitle:
                                    'Guests use the smart redirect into the venue experience.',
                                uri: appUri,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTheme.space4),
                _SectionCard(
                  title: 'WiFi & Social',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'WIFI SSID',
                            controller: _wifiSsidCtrl,
                            hint: 'Guest WiFi',
                          ),
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _wifiSecurity,
                            decoration: const InputDecoration(
                              labelText: 'WIFI SECURITY',
                            ),
                            items: const ['WPA', 'WEP', 'Open']
                                .map((value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                })
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _wifiSecurity = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    _LabeledField(
                      label: 'WIFI PASSWORD',
                      controller: _wifiPasswordCtrl,
                      hint: 'Network password',
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'INSTAGRAM',
                            controller: _instagramCtrl,
                            hint: 'https://instagram.com/venue',
                            keyboardType: TextInputType.url,
                          ),
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Expanded(
                          child: _LabeledField(
                            label: 'FACEBOOK',
                            controller: _facebookCtrl,
                            hint: 'https://facebook.com/venue',
                            keyboardType: TextInputType.url,
                          ),
                        ),
                      ],
                    ),
                    _LabeledField(
                      label: 'TIKTOK',
                      controller: _tiktokCtrl,
                      hint: 'https://tiktok.com/@venue',
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space4),
                _SectionCard(
                  title: 'Opening Hours',
                  children: [
                    ..._days.map((day) {
                      final hours = _schedule[day]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.space2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainer,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  day,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              PressableScale(
                                onTap: () => setState(() {
                                  _schedule[day] = hours.copyWith(
                                    isOpen: !hours.isOpen,
                                  );
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hours.isOpen
                                        ? cs.secondary.withValues(alpha: 0.12)
                                        : cs.error.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    hours.isOpen ? 'Open' : 'Closed',
                                    style: tt.labelSmall?.copyWith(
                                      color: hours.isOpen
                                          ? cs.secondary
                                          : cs.error,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.space3),
                              PressableScale(
                                onTap: () => _editDayTimes(day),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    hours.isOpen
                                        ? '${hours.open} - ${hours.close}'
                                        : 'Closed',
                                    style: tt.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
            Positioned(
              left: AppTheme.space6,
              right: AppTheme.space6,
              bottom: 100,
              child: PremiumButton(
                label: widget.isCreate ? 'CREATE VENUE' : 'SAVE CHANGES',
                icon: LucideIcons.save,
                isLoading: _saving,
                onPressed: _saving ? null : () => _save(venue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ClayCard(
      padding: const EdgeInsets.all(AppTheme.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          ...children,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _InlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _InlineField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _LinkAccessRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;
  final VoidCallback onOpen;

  const _LinkAccessRow({
    required this.label,
    required this.value,
    required this.onCopy,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space2),
          Column(
            children: [
              PressableScale(
                onTap: onCopy,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.copy, size: 16, color: cs.onSurface),
                ),
              ),
              const SizedBox(height: 6),
              PressableScale(
                onTap: onOpen,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.externalLink,
                    size: 16,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrPreviewCard extends StatelessWidget {
  final String label;
  final Uri uri;
  final VoidCallback onTap;

  const _QrPreviewCard({
    required this.label,
    required this.uri,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: Column(
          children: [
            QrImageView(
              data: uri.toString(),
              version: QrVersions.auto,
              size: 96,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: AppTheme.space3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF121416),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHours {
  final bool isOpen;
  final String open;
  final String close;

  const _DayHours({
    required this.isOpen,
    required this.open,
    required this.close,
  });

  _DayHours copyWith({bool? isOpen, String? open, String? close}) {
    return _DayHours(
      isOpen: isOpen ?? this.isOpen,
      open: open ?? this.open,
      close: close ?? this.close,
    );
  }

  Map<String, dynamic> toJson() => {
    'is_open': isOpen,
    'open': open,
    'close': close,
  };
}
