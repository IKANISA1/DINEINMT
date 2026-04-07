import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:core_pkg/constants/app_download_links.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/app_telemetry.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'widgets/share_venue_dialog.dart';
import 'widgets/venue_about_section.dart';
import 'widgets/venue_hero_action.dart';
import 'widgets/venue_menu_highlights.dart';
import 'widgets/venue_wifi_sheet.dart';



class VenueDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  final String? tableNumber;

  const VenueDetailScreen({super.key, required this.slug, this.tableNumber});

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  bool _aboutExpanded = false;
  bool _isSaved = false;
  String? _trackedVenueViewId;

  void _trackGuestEvent(
    String eventName, {
    String? venueId,
    Map<String, Object?> details = const {},
  }) {
    unawaited(
      AppTelemetryService.trackGuestEvent(
        eventName,
        route: AppRoutePaths.venueDetail.replaceFirst(
          ':${AppRouteParams.slug}',
          widget.slug,
        ),
        venueId: venueId,
        details: details,
      ),
    );
  }

  void _trackVenueViewed(Venue venue) {
    if (_trackedVenueViewId == venue.id) return;
    _trackedVenueViewId = venue.id;
    _trackGuestEvent(
      'venue_detail_viewed',
      venueId: venue.id,
      details: {
        'slug': venue.slug,
        'table_context': widget.tableNumber?.trim().isNotEmpty == true,
        'can_order': venue.canAcceptGuestOrders,
      },
    );
  }

  Uri _venueLink(Venue venue) {
    final config = ref.read(countryConfigProvider);
    final table = widget.tableNumber?.trim();
    if (table != null && table.isNotEmpty) {
      return buildVenueTableDeepLinkUri(
        slug: venue.slug,
        tableNumber: table,
        config: config,
      );
    }
    return buildVenueDeepLinkUri(slug: venue.slug, config: config);
  }

  void _openMenu(Venue venue) {
    _trackGuestEvent(
      'menu_opened',
      venueId: venue.id,
      details: {
        'slug': venue.slug,
        'table_context': widget.tableNumber?.trim().isNotEmpty == true,
      },
    );
    ref
        .read(cartProvider.notifier)
        .setVenue(
          venueId: venue.id,
          venueSlug: venue.slug,
          venueName: venue.name,
          venueRevolutUrl: venue.revolutUrl,
          venueCountry: venue.country,
          tableNumber: widget.tableNumber,
        );
    context.pushNamed(
      AppRouteNames.menu,
      pathParameters: {AppRouteParams.slug: venue.slug},
      extra: venue.id,
    );
  }

  Future<void> _showShareDialog(Venue venue) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (_) =>
          ShareVenueDialog(venue: venue, shareUri: _venueLink(venue)),
    );
  }

  void _toggleSavedVenue(Venue venue) {
    setState(() => _isSaved = !_isSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved
              ? '${venue.name} saved for later.'
              : '${venue.name} removed from saved venues.',
        ),
      ),
    );
  }

  Future<void> _callVenue(Venue venue) async {
    final rawPhone = venue.phone?.trim();
    if (rawPhone == null || rawPhone.isEmpty) return;

    final normalized = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: normalized);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open the venue phone number.')),
    );
  }



  Future<void> _openMaps(Venue venue) async {
    final raw = venue.googleMapsUri?.trim();
    final uri = raw == null || raw.isEmpty ? null : Uri.tryParse(raw);
    if (uri == null) return;

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open the venue map link.')),
    );
  }

  Future<void> _handleWifiTap(Venue venue) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Connecting to ${venue.wifiSsid ?? 'venue WiFi'}...'),
        duration: const Duration(seconds: 2),
      ),
    );

    final wifiService = ref.read(guestWifiServiceProvider);
    final result = await wifiService.connectToVenueWifi(venue);

    if (!mounted) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(result.message)));

    if (result.shouldShowManualFallback) {
      showVenueWifiSheet(context, venue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venueBySlugProvider(widget.slug));

    return venueAsync.when(
      loading: () => Scaffold(
        body: SafeArea(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: const [
              SkeletonLoader(width: double.infinity, height: 280, borderRadius: 0),
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SkeletonLoader(width: 200, height: 28, borderRadius: 8),
              ),
              SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SkeletonLoader(width: 140, height: 16, borderRadius: 6),
              ),
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SkeletonLoader(width: double.infinity, height: 120, borderRadius: 20),
              ),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SkeletonLoader(width: double.infinity, height: 80, borderRadius: 20),
              ),
            ],
          ),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: ErrorState(
          message: 'The venue "${widget.slug}" could not be loaded.',
          onRetry: () => ref.invalidate(venueBySlugProvider(widget.slug)),
        ),
      ),
      data: (venue) {
        if (venue == null) {
          return Scaffold(
            body: EmptyState(
              icon: LucideIcons.store,
              title: 'Venue not found',
              subtitle: 'No venue matches "${widget.slug}".',
            ),
          );
        }
        _trackVenueViewed(venue);
        return _VenueDetailBody(
          venue: venue,
          tableNumber: widget.tableNumber,
          isSaved: _isSaved,
          aboutExpanded: _aboutExpanded,
          onBack: () => context.pop(),
          onShare: () => _showShareDialog(venue),
          onToggleSaved: () => _toggleSavedVenue(venue),
          onToggleAbout: () => setState(() => _aboutExpanded = !_aboutExpanded),
          onCall: venue.phone == null ? null : () => _callVenue(venue),

          onMaps: venue.googleMapsUri == null ? null : () => _openMaps(venue),
          onWifiTap: venue.hasWifi && !kIsWeb
              ? () => _handleWifiTap(venue)
              : null,
          onOpenMenu: () => _openMenu(venue),
        );
      },
    );
  }
}

class _VenueDetailBody extends StatelessWidget {
  final Venue venue;
  final String? tableNumber;
  final bool isSaved;
  final bool aboutExpanded;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onToggleSaved;
  final VoidCallback onToggleAbout;
  final VoidCallback? onCall;
  final VoidCallback? onMaps;
  final VoidCallback? onWifiTap;
  final VoidCallback onOpenMenu;

  const _VenueDetailBody({
    required this.venue,
    required this.tableNumber,
    required this.isSaved,
    required this.aboutExpanded,
    required this.onBack,
    required this.onShare,
    required this.onToggleSaved,
    required this.onToggleAbout,
    required this.onCall,
    required this.onMaps,
    required this.onWifiTap,
    required this.onOpenMenu,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.45,
            pinned: true,
            stretch: true,
            backgroundColor: cs.surface,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: VenueHeroAction(icon: LucideIcons.chevronLeft, onTap: onBack),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: VenueHeroAction(icon: LucideIcons.share2, onTap: onShare),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
                child: VenueHeroAction(
                  icon: isSaved ? LucideIcons.heart : LucideIcons.heartOff,
                  iconColor: isSaved ? cs.primary : Colors.white,
                  onTap: onToggleSaved,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  DineInImage(
                    imageUrl: venue.imageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: LucideIcons.store,
                    semanticLabel: '${venue.name} photo',
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.18),
                            cs.surface,
                          ],
                          stops: const [0.0, 0.35, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 32,
                    right: 32,
                    bottom: 32,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          venue.name,
                          style: tt.displayMedium?.copyWith(
                            color: Colors.white,
                            height: 0.95,
                            letterSpacing: -2.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(LucideIcons.star, size: 16, color: cs.primary),
                            const SizedBox(width: 8),
                            Text(
                              venue.rating.toStringAsFixed(
                                venue.rating.truncateToDouble() == venue.rating
                                    ? 0
                                    : 1,
                              ),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.2,
                              ),
                            ),
                            if (venue.ratingCount > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(${venue.ratingCount})',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.62),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppTheme.space6),
                if (venue.isPromoActive && venue.promoMessage?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: cs.secondary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.tag, color: cs.secondary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              venue.promoMessage!,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (tableNumber != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space4),
                    child: Row(
                      children: [
                        StatusBadge(
                          label: 'Table $tableNumber',
                          color: cs.primaryContainer.withValues(alpha: 0.24),
                          textColor: cs.primary,
                        ),
                      ],
                    ),
                  ),
                VenueAboutSection(
                  venue: venue,
                  isExpanded: aboutExpanded,
                  onToggle: onToggleAbout,
                  onCall: onCall,
                  onMaps: onMaps,
                  onWifiTap: onWifiTap,
                ),
                const SizedBox(height: AppTheme.space6),
                VenueMenuHighlights(
                  venue: venue,
                  onOpenMenu: onOpenMenu,
                ),
                const SizedBox(height: AppTheme.space6),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space4,
          AppTheme.space2,
          AppTheme.space4,
          AppTheme.space4,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.08)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onOpenMenu,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'VIEW MENU',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(LucideIcons.chevronRight, size: 18, color: cs.onPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

