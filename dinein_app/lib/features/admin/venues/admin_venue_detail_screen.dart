import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:core_pkg/constants/app_download_links.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/venue_repository.dart';
import 'package:dinein_app/shared/widgets/branded_qr_tools.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'widgets/admin_venue_form_widgets.dart';
import 'widgets/admin_venue_sheets.dart';

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
  final _ownerWhatsAppCtrl = TextEditingController();
  final _ownerContactPhoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _reservationCtrl = TextEditingController();

  final _wifiSsidCtrl = TextEditingController();
  final _wifiPasswordCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _promoMessageCtrl = TextEditingController();

  static const _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final Map<String, DayHours> _schedule = <String, DayHours>{};
  VenueStatus _status = VenueStatus.inactive;
  bool _orderingEnabled = false;
  bool _isPromoActive = false;
  String _wifiSecurity = 'WPA';
  bool _saving = false;
  bool _syncingProfile = false;
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
    _ownerWhatsAppCtrl.dispose();
    _ownerContactPhoneCtrl.dispose();
    _emailCtrl.dispose();
    _imageCtrl.dispose();
    _websiteCtrl.dispose();
    _reservationCtrl.dispose();

    _wifiSsidCtrl.dispose();
    _wifiPasswordCtrl.dispose();
    _instagramCtrl.dispose();
    _facebookCtrl.dispose();
    _tiktokCtrl.dispose();
    _promoMessageCtrl.dispose();
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
    _ownerWhatsAppCtrl.text = venue?.ownerWhatsAppNumber ?? '';
    _ownerContactPhoneCtrl.text = venue?.ownerContactPhone ?? '';
    _emailCtrl.text = venue?.email ?? '';
    _imageCtrl.text = venue?.imageUrl ?? '';
    _websiteCtrl.text = venue?.websiteUrl ?? '';
    _reservationCtrl.text = venue?.reservationUrl ?? '';

    _wifiSsidCtrl.text = venue?.wifiSsid ?? '';
    _wifiPasswordCtrl.text = venue?.wifiPassword ?? '';
    _instagramCtrl.text = venue?.socialLinks?['instagram'] ?? '';
    _facebookCtrl.text = venue?.socialLinks?['facebook'] ?? '';
    _tiktokCtrl.text = venue?.socialLinks?['tiktok'] ?? '';
    _wifiSecurity = venue?.wifiSecurity ?? 'WPA';
    _status = venue?.status ?? VenueStatus.inactive;
    _orderingEnabled = venue?.orderingEnabled ?? false;
    _isPromoActive = venue?.isPromoActive ?? false;
    _promoMessageCtrl.text = venue?.promoMessage ?? '';
    _slugDirty = venue != null;

    _schedule.clear();
    for (final day in _days) {
      final hours = venue?.openingHours?[day];
      _schedule[day] = DayHours(
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
      'owner_whatsapp_number': _ownerWhatsAppCtrl.text.trim().isEmpty ? null : _ownerWhatsAppCtrl.text.trim(),
      'owner_contact_phone': _ownerContactPhoneCtrl.text.trim().isEmpty ? null : _ownerContactPhoneCtrl.text.trim(),
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

      'wifi_ssid': wifiSsid.isEmpty ? null : wifiSsid,
      'wifi_password': wifiSsid.isEmpty
          ? null
          : (wifiPassword.isEmpty ? null : wifiPassword),
      'wifi_security': wifiSsid.isEmpty ? null : _wifiSecurity,
      'social_links': _buildSocialLinksPayload(),
      'opening_hours': _buildOpeningHoursPayload(),
      'status': _status.dbValue,
      'ordering_enabled': _orderingEnabled,
      'is_promo_active': _isPromoActive,
      'promo_message': _promoMessageCtrl.text.trim().isEmpty ? null : _promoMessageCtrl.text.trim(),
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
      _showSnack('Could not save venue. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      if (file.bytes == null) {
        _showSnack('Cannot read image data');
        return;
      }

      setState(() => _saving = true);
      final ext = file.extension ?? 'png';
      final fileName = 'venue_${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      // We assume a 'venues' bucket exists. If it doesn't, this will throw.
      final supabase = Supabase.instance.client;
      await supabase.storage.from('venues').uploadBinary(
            'images/$fileName',
            file.bytes!,
          );
          
      final url = supabase.storage.from('venues').getPublicUrl('images/$fileName');
      setState(() {
        _imageCtrl.text = url;
      });
      _showSnack('Image uploaded successfully.');
    } catch (e) {
      _showSnack('Image upload failed. Please try again later.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadMenuDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      if (file.bytes == null) {
        _showSnack('Cannot read file data');
        return;
      }

      setState(() => _saving = true);
      final ext = file.extension ?? 'pdf';
      final fileName = 'menu_${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      final supabase = Supabase.instance.client;
      await supabase.storage.from('venues').uploadBinary(
            'menus/$fileName',
            file.bytes!,
          );
          
      // Typically the backend triggers the OCR pipeline automatically via a webhook when a menu is uploaded.
      _showSnack('Menu document uploaded. OCR pipeline will process this shortly.');
    } catch (e) {
      _showSnack('Menu document upload failed. Please try again later.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  Future<void> _deleteVenue(Venue venue) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius3xl),
        ),
        title: Text(
          'Delete Venue?',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: cs.error,
          ),
        ),
        content: Text(
          'This venue will be removed from the platform. '
          'This action cannot be easily undone.',
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: cs.error.withValues(alpha: 0.10),
            ),
            child: Text(
              'DELETE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _saving = true);

    try {
      await VenueRepository.instance.deleteVenue(venue.id);
      _invalidateVenueCaches(venue.id);

      if (mounted) {
        _showSnack('Venue completely deleted.');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnack('Failed to delete venue. Please try again.');
      }
    }
  }

  Future<void> _syncProfileData(Venue venue) async {
    if (_syncingProfile) return;
    setState(() => _syncingProfile = true);
    try {
      await VenueRepository.instance.enrichVenueProfile(
        venue.id,
        useAdminSession: true,
      );
      _invalidateVenueCaches(venue.id);
      if (!mounted) return;
      _showSnack('Venue discovery data refreshed.');
    } catch (error) {
      _showSnack('Could not refresh venue discovery data. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _syncingProfile = false);
      }
    }
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
                _buildHeader(cs, tt, venue),
                const SizedBox(height: AppTheme.space6),
                _buildPreviewCard(cs, tt, slug, venue),
                if (venue != null) ...[
                  const SizedBox(height: AppTheme.space4),
                  _buildDiscoveryDataCard(cs, tt, venue),
                ],
                const SizedBox(height: AppTheme.space4),
                _buildCoreDetailsSection(config),
                const SizedBox(height: AppTheme.space4),
                _buildProfileDataSection(config),
                const SizedBox(height: AppTheme.space4),
                _buildDocumentSubmissionSection(),
                const SizedBox(height: AppTheme.space4),
                _buildPromoSection(),
                const SizedBox(height: AppTheme.space4),
                _buildAccessAndOnboardingSection(config),
                const SizedBox(height: AppTheme.space4),
                _buildOperationalSection(cs, tt, venue),
                const SizedBox(height: AppTheme.space4),
                _buildGuestAccessSection(tt, guestUri, appUri),
                const SizedBox(height: AppTheme.space4),
                _buildWifiSocialSection(),
                const SizedBox(height: AppTheme.space4),
                _buildOpeningHoursSection(cs, tt),
                const SizedBox(height: AppTheme.space6),
                _buildDangerZone(cs, tt, venue),
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

  // ── Header ──────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs, TextTheme tt, Venue? venue) {
    return Row(
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
            child: Icon(LucideIcons.chevronLeft, size: 22, color: cs.onSurface),
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
                widget.isCreate ? 'CREATE ADMIN VENUE' : 'ADMIN · VENUE',
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
    );
  }

  // ── Preview Card ────────────────────────────────────────────────────

  Widget _buildPreviewCard(
    ColorScheme cs,
    TextTheme tt,
    String slug,
    Venue? venue,
  ) {
    return ClayCard(
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
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  slug.isEmpty ? 'slug-pending' : slug,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
                      textColor: _orderingEnabled ? cs.primary : cs.onSurface,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Discovery Data ──────────────────────────────────────────────────

  Widget _buildDiscoveryDataCard(ColorScheme cs, TextTheme tt, Venue venue) {
    return ClayCard(
      padding: const EdgeInsets.all(AppTheme.space5),
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
                      'Refresh Maps-backed profile data used across guest discovery, venue detail, and admin review surfaces.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (venue.enrichmentStatus != null)
                StatusBadge(
                  label: venue.enrichmentStatus!,
                  color: cs.primary.withValues(alpha: 0.12),
                  textColor: cs.primary,
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
                label: venue.latitude != null && venue.longitude != null
                    ? 'Geo Ready'
                    : 'Geo Missing',
                color: venue.latitude != null && venue.longitude != null
                    ? cs.primary.withValues(alpha: 0.12)
                    : cs.error.withValues(alpha: 0.12),
                textColor: venue.latitude != null && venue.longitude != null
                    ? cs.primary
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
          Row(
            children: [
              Expanded(
                child: PremiumButton(
                  label: _syncingProfile ? 'SYNCING...' : 'SYNC PROFILE DATA',
                  icon: LucideIcons.sparkles,
                  onPressed: _syncingProfile
                      ? null
                      : () => _syncProfileData(venue),
                ),
              ),
              if (venue.googleMapsUri != null) ...[
                const SizedBox(width: AppTheme.space3),
                PressableScale(
                  onTap: () =>
                      _openLink('Map', Uri.parse(venue.googleMapsUri!)),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: AppColors.white5),
                    ),
                    child: Icon(
                      LucideIcons.mapPin,
                      size: 20,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Core Details ────────────────────────────────────────────────────

  Widget _buildCoreDetailsSection(CountryConfig config) {
    return AdminVenueSectionCard(
      title: 'Core Details',
      children: [
        AdminVenueLabeledField(
          label: 'NAME',
          controller: _nameCtrl,
          hint: 'Harbor Table',
          onChanged: _handleNameChanged,
        ),
        Row(
          children: [
            Expanded(
              child: AdminVenueLabeledField(
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
              child: AdminVenueLabeledField(
                label: 'CATEGORY',
                controller: _categoryCtrl,
                hint: 'restaurant',
              ),
            ),
          ],
        ),
        AdminVenueLabeledField(
          label: 'ADDRESS',
          controller: _addressCtrl,
          hint: config.addressHint,
        ),
        AdminVenueLabeledField(
          label: 'DESCRIPTION',
          controller: _descriptionCtrl,
          hint: 'Short guest-facing venue summary',
          maxLines: 4,
        ),
      ],
    );
  }

  // ── Profile Data ────────────────────────────────────────────────────

  Widget _buildProfileDataSection(CountryConfig config) {
    return AdminVenueSectionCard(
      title: 'Profile Data',
      children: [
        Row(
          children: [
            Expanded(
              child: AdminVenueLabeledField(
                label: 'PUBLIC PHONE',
                controller: _phoneCtrl,
                hint: '${config.countryDialCode}...',
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: AdminVenueLabeledField(
                label: 'EMAIL',
                controller: _emailCtrl,
                hint: 'venue@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AdminVenueLabeledField(
                label: 'IMAGE URL',
                controller: _imageCtrl,
                hint: 'https://images.example.com/venue.jpg',
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppTheme.space2),
            InkWell(
              onTap: _uploadProfileImage,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(LucideIcons.uploadCloud, size: 20),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: AdminVenueLabeledField(
                label: 'WEBSITE',
                controller: _websiteCtrl,
                hint: 'https://venue.example.com',
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: AdminVenueLabeledField(
                label: 'RESERVATION URL',
                controller: _reservationCtrl,
                hint: 'https://reserve.example.com',
                keyboardType: TextInputType.url,
              ),
            ),
          ],
        ),
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.space2, bottom: AppTheme.space2),
            child: Text(
              'Payment destinations (MoMo / Revolut codes) are strictly managed by system integrations or venue owners directly and cannot be modified by site administrators.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
      ],
    );
  }

  // ── Document Submissions ──────────────────────────────────────────────

  Widget _buildDocumentSubmissionSection() {
    return AdminVenueSectionCard(
      title: 'Menu / Document Submissions',
      children: [
        Text(
          'Upload menu documents (PDF, JPG) so the backend OCR pipeline can process their items automatically.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppTheme.space4),
        FilledButton.tonalIcon(
          onPressed: _uploadMenuDocument,
          icon: const Icon(LucideIcons.fileText),
          label: const Text('Upload Menu Document'),
        ),
      ],
    );
  }

  // ── Home Display Promos ─────────────────────────────────────────────

  Widget _buildPromoSection() {
    final cs = Theme.of(context).colorScheme;
    return AdminVenueSectionCard(
      title: 'Home Display Promo',
      children: [
        Text(
          'Highlight a special promo or announcement on the guest app home screen.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppTheme.space4),
        AdminVenueLabeledField(
          label: 'PROMO MESSAGE',
          controller: _promoMessageCtrl,
          hint: 'e.g. "Free delivery on all orders this weekend!"',
          maxLines: 2,
        ),
        const SizedBox(height: AppTheme.space4),
        Container(
          padding: const EdgeInsets.all(AppTheme.space4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Promo Visibility',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPromoActive
                          ? 'Guests can see this promo message.'
                          : 'Promo message is hidden.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space4),
              Switch(
                value: _isPromoActive,
                onChanged: (val) => setState(() => _isPromoActive = val),
                activeThumbColor: AppColors.secondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Access & Onboarding ─────────────────────────────────────────────

  Widget _buildAccessAndOnboardingSection(CountryConfig config) {
    return AdminVenueSectionCard(
      title: 'Auth & Access',
      children: [
        Row(
          children: [
            Expanded(
              child: AdminVenueLabeledField(
                label: 'OWNER WHATSAPP NUMBER',
                controller: _ownerWhatsAppCtrl,
                hint: '${config.countryDialCode}...',
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: AdminVenueLabeledField(
                label: 'OWNER CONTACT PHONE',
                controller: _ownerContactPhoneCtrl,
                hint: '${config.countryDialCode}...',
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space2),
        Text(
          'The Owner WhatsApp Number is required for venue operators to log in via WhatsApp OTP.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  // ── Operational Controls ────────────────────────────────────────────

  Widget _buildOperationalSection(ColorScheme cs, TextTheme tt, Venue? venue) {
    return AdminVenueSectionCard(
      title: 'Operational Controls',
      children: [
        Row(
          children: [
            AdminStatusDot(status: _status.dbValue),
            const SizedBox(width: AppTheme.space3),
            Text(
              'CURRENT STATUS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: cs.onSurfaceVariant.withValues(alpha: 0.30),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space4),
        AdminStatusButton(
          label: 'Activate Venue',
          subtitle: 'Visible to guests • Ordering depends on validation',
          icon: LucideIcons.play,
          isSelected: _status == VenueStatus.active,
          selectedColor: AppColors.secondary,
          onTap: () => setState(() => _status = VenueStatus.active),
        ),
        const SizedBox(height: AppTheme.space4),
        AdminStatusButton(
          label: 'Maintenance Mode',
          subtitle: 'Visible as unavailable • Ordering disabled',
          icon: LucideIcons.clock,
          isSelected: _status == VenueStatus.maintenance,
          selectedColor: AppColors.warning,
          onTap: () => setState(() => _status = VenueStatus.maintenance),
        ),
        const SizedBox(height: AppTheme.space4),
        AdminStatusButton(
          label: 'Suspend Venue',
          subtitle: 'Hidden from all guests',
          icon: LucideIcons.pause,
          isSelected: _status == VenueStatus.suspended,
          selectedColor: cs.error,
          onTap: () => setState(() => _status = VenueStatus.suspended),
        ),
        const SizedBox(height: AppTheme.space6),
        Container(
          padding: const EdgeInsets.all(AppTheme.space5),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
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
                    const SizedBox(height: 4),
                    Text(
                      _orderingEnabled
                          ? 'Validated venues can accept guest orders.'
                          : 'Guests can browse this venue, but ordering stays unavailable.',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space4),
              Switch(
                value: _orderingEnabled,
                onChanged: (val) => setState(() => _orderingEnabled = val),
                activeThumbColor: AppColors.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        if (venue != null)
          Container(
            padding: const EdgeInsets.all(AppTheme.space4),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
                      ? 'Edit WhatsApp'
                      : 'Add WhatsApp',
                  icon: LucideIcons.messageCircle,
                  isOutlined: true,
                  isSmall: true,
                  onPressed: () => AdminVenueSheets.showAccessEditor(
                    context: context,
                    venue: venue,
                    config: ref.read(countryConfigProvider),
                    phoneCtrl: _ownerWhatsAppCtrl,
                    onCachesInvalidated: () => _invalidateVenueCaches(venue.id),
                    onUpdateVenueOverride: widget.onUpdateVenueOverride,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            'Save the venue first to manage WhatsApp access and QR sharing.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _buildDangerZone(ColorScheme cs, TextTheme tt, Venue? venue) {
    if (venue == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
          child: Text(
            'Danger Zone',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: cs.error,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space5),
        PressableScale(
          onTap: () => _deleteVenue(venue),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.space6),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radius3xl),
              border: Border.all(color: cs.error.withValues(alpha: 0.10)),
              boxShadow: AppTheme.clayShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Icon(LucideIcons.trash2, size: 28, color: cs.error),
                ),
                const SizedBox(width: AppTheme.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete Venue',
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: cs.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'IRREVERSIBLE ACTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: cs.error,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 24,
                    color: cs.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Guest Access ────────────────────────────────────────────────────

  Widget _buildGuestAccessSection(TextTheme tt, Uri? guestUri, Uri? appUri) {
    return AdminVenueSectionCard(
      title: 'Guest Access',
      children: [
        if (guestUri == null || appUri == null)
          Text(
            'Enter a valid slug to generate the guest URL, venue app URL, and guest QR code.',
            style: tt.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          AdminVenueLinkAccessRow(
            label: 'Guest URL',
            value: guestUri.toString(),
            onCopy: () => _copyLink('Guest URL', guestUri),
            onOpen: () => _openLink('Guest URL', guestUri),
          ),
          const SizedBox(height: AppTheme.space3),
          AdminVenueLinkAccessRow(
            label: 'Venue App URL',
            value: appUri.toString(),
            onCopy: () => _copyLink('Venue app URL', appUri),
            onOpen: () => _openLink('Venue app URL', appUri),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            'Generate a clean QR poster for either the direct guest menu link or the smart venue app link.',
            style: tt.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackCards = constraints.maxWidth < 760;
              final cards = [
                Expanded(
                  child: AdminVenueQrPreviewCard(
                    label: 'GENERATE GUEST QR',
                    uri: guestUri,
                    onTap: () => showBrandedQrSheet(
                      context: context,
                      title: '${_nameCtrl.text.trim()} guest QR',
                      helperText:
                          'Guests scan this QR to open the venue menu directly.',
                      uri: guestUri,
                      shareFileName:
                          '${_slugCtrl.text.trim().isEmpty ? 'venue' : _slugCtrl.text.trim()}_guest_qr.png',
                      shareSubject: '${_nameCtrl.text.trim()} guest QR',
                      copyFeedbackMessage: 'Guest URL copied.',
                      openLabel: 'guest URL',
                    ),
                  ),
                ),
                Expanded(
                  child: AdminVenueQrPreviewCard(
                    label: 'GENERATE VENUE QR',
                    uri: appUri,
                    onTap: () => showBrandedQrSheet(
                      context: context,
                      title: '${_nameCtrl.text.trim()} venue QR',
                      helperText:
                          'Guests scan this QR to open the smart venue app link.',
                      uri: appUri,
                      shareFileName:
                          '${_slugCtrl.text.trim().isEmpty ? 'venue' : _slugCtrl.text.trim()}_venue_qr.png',
                      shareSubject: '${_nameCtrl.text.trim()} venue QR',
                      copyFeedbackMessage: 'Venue app URL copied.',
                      openLabel: 'venue app URL',
                    ),
                  ),
                ),
              ];

              if (stackCards) {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: AppTheme.space4),
                    cards[1],
                  ],
                );
              }

              return Row(
                children: [
                  cards[0],
                  const SizedBox(width: AppTheme.space4),
                  cards[1],
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  // ── WiFi & Social ───────────────────────────────────────────────────

  Widget _buildWifiSocialSection() {
    return AdminVenueSectionCard(
      title: 'WiFi & Social',
      children: [
        Row(
          children: [
            Expanded(
              child: AdminVenueLabeledField(
                label: 'WIFI SSID',
                controller: _wifiSsidCtrl,
                hint: 'Guest WiFi',
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _wifiSecurity,
                decoration: const InputDecoration(labelText: 'WIFI SECURITY'),
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
        AdminVenueLabeledField(
          label: 'WIFI PASSWORD',
          controller: _wifiPasswordCtrl,
          hint: 'Network password',
        ),
        Row(
          children: [
            Expanded(
              child: AdminVenueLabeledField(
                label: 'INSTAGRAM',
                controller: _instagramCtrl,
                hint: 'https://instagram.com/venue',
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: AdminVenueLabeledField(
                label: 'FACEBOOK',
                controller: _facebookCtrl,
                hint: 'https://facebook.com/venue',
                keyboardType: TextInputType.url,
              ),
            ),
          ],
        ),
        AdminVenueLabeledField(
          label: 'TIKTOK',
          controller: _tiktokCtrl,
          hint: 'https://tiktok.com/@venue',
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  // ── Opening Hours ───────────────────────────────────────────────────

  Widget _buildOpeningHoursSection(ColorScheme cs, TextTheme tt) {
    return AdminVenueSectionCard(
      title: 'Opening Hours',
      children: [
        ..._days.map((day) {
          final hours = _schedule[day]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
                      _schedule[day] = hours.copyWith(isOpen: !hours.isOpen);
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
                          color: hours.isOpen ? cs.secondary : cs.error,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  PressableScale(
                    onTap: () => AdminVenueSheets.showScheduleEditor(
                      context: context,
                      day: day,
                      hours: hours,
                      onApply: (updated) {
                        setState(() => _schedule[day] = updated);
                      },
                    ),
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
    );
  }
}
