import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_download_links.dart';
import '../../../core/config/country_config_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

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

  Uri _venueLink(Venue venue) {
    final config = ref.read(countryConfigProvider);
    final table = widget.tableNumber?.trim();
    if (table != null && table.isNotEmpty) {
      return buildVenueTableDeepLinkUri(slug: venue.slug, tableNumber: table, config: config);
    }
    return buildVenueDeepLinkUri(slug: venue.slug, config: config);
  }

  void _openMenu(Venue venue) {
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
          _ShareVenueDialog(venue: venue, shareUri: _venueLink(venue)),
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

  Future<void> _openWebsite(Venue venue) async {
    final uri = venue.websiteUri;
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
      const SnackBar(content: Text('Unable to open the venue website.')),
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
      _showWifiSheet(context, venue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venueBySlugProvider(widget.slug));

    return venueAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: SkeletonLoader(width: double.infinity, height: 320),
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
          onWebsite: venue.websiteUri == null
              ? null
              : () => _openWebsite(venue),
          onWifiTap: venue.hasWifi ? () => _handleWifiTap(venue) : null,
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
  final VoidCallback? onWebsite;
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
    required this.onWebsite,
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
              child: _HeroAction(icon: LucideIcons.chevronLeft, onTap: onBack),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: _HeroAction(icon: LucideIcons.share2, onTap: onShare),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
                child: _HeroAction(
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.28),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Text(
                            venue.category.toUpperCase(),
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                  ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.08),
                _AboutSection(
                  venue: venue,
                  isExpanded: aboutExpanded,
                  onToggle: onToggleAbout,
                  onCall: onCall,
                  onWebsite: onWebsite,
                  onWifiTap: onWifiTap,
                ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.05),
                const SizedBox(height: AppTheme.space6),
                _MenuHighlights(
                  venue: venue,
                  onOpenMenu: onOpenMenu,
                ).animate(delay: 240.ms).fadeIn().slideY(begin: 0.05),
                const SizedBox(height: AppTheme.space16),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space6,
          AppTheme.space4,
          AppTheme.space6,
          AppTheme.space8,
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
                padding: const EdgeInsets.symmetric(vertical: 20),
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

class _HeroAction extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _HeroAction({required this.icon, this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.white10),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final Venue venue;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onCall;
  final VoidCallback? onWebsite;
  final VoidCallback? onWifiTap;

  const _AboutSection({
    required this.venue,
    required this.isExpanded,
    required this.onToggle,
    required this.onCall,
    required this.onWebsite,
    required this.onWifiTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final description = venue.description.trim().isEmpty
        ? 'Venue details coming soon.'
        : venue.description.trim();

    return Container(
      padding: const EdgeInsets.all(AppTheme.space8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: AppColors.white5),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PressableScale(
            onTap: onToggle,
            child: Row(
              children: [
                Expanded(child: Text('About', style: tt.headlineMedium)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isExpanded ? cs.primary : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 400),
                    turns: isExpanded ? 0.5 : 0,
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: isExpanded ? cs.onPrimary : cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white.withValues(alpha: 0)],
                stops: const [0.52, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  height: 1.6,
                ),
              ),
            ),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DetailChip(
                      icon: LucideIcons.clock3,
                      label: _openingHoursLabel(venue),
                    ),
                    if (venue.phone != null && venue.phone!.trim().isNotEmpty)
                      _DetailChip(
                        icon: LucideIcons.phone,
                        label: venue.phone!,
                        onTap: onCall,
                      ),
                    if (venue.websiteUri != null)
                      _DetailChip(
                        icon: LucideIcons.globe,
                        label: 'Website',
                        onTap: onWebsite,
                      ),
                    if (venue.hasWifi)
                      _DetailChip(
                        icon: LucideIcons.wifi,
                        label: 'Connect to Wifi',
                        onTap: onWifiTap,
                        isPrimary: true,
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
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _DetailChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final background = isPrimary ? cs.primary : cs.surfaceContainerHigh;
    final foreground = isPrimary ? cs.onPrimary : cs.primary;
    final textColor = isPrimary ? cs.onPrimary : cs.onSurface;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isPrimary ? Colors.transparent : AppColors.white5,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.20),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return PressableScale(onTap: onTap, child: content);
  }
}

class _ShareVenueDialog extends StatefulWidget {
  final Venue venue;
  final Uri shareUri;

  const _ShareVenueDialog({required this.venue, required this.shareUri});

  @override
  State<_ShareVenueDialog> createState() => _ShareVenueDialogState();
}

class _ShareVenueDialogState extends State<_ShareVenueDialog> {
  bool _copied = false;

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.shareUri.toString()));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  Future<void> _shareLink() async {
    await SharePlus.instance.share(
      ShareParams(
        title: '${widget.venue.name} on DINEIN',
        text:
            'Check out ${widget.venue.name} on DINEIN.\n'
            '${widget.shareUri}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radius3xl),
          border: Border.all(color: AppColors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(LucideIcons.qrCode, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SHARE VENUE',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Digital experience',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                PressableScale(
                  onTap: () => Navigator.of(context).pop(),
                  minTouchTargetSize: const Size(44, 44),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.white5,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(
                      LucideIcons.x,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
              ),
              child: QrImageView(
                data: widget.shareUri.toString(),
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF121416),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF121416),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            Text(
              widget.venue.name,
              textAlign: TextAlign.center,
              style: tt.headlineSmall?.copyWith(letterSpacing: -0.8),
            ),
            const SizedBox(height: 4),
            Text(
              'SCAN TO OPEN ON DINEIN',
              style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.6,
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            SizedBox(
              width: double.infinity,
              child: PressableScale(
                onTap: _copyLink,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: _copied ? cs.primary : AppColors.white5,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: _copied ? cs.primary : AppColors.white5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _copied ? LucideIcons.check : LucideIcons.copy,
                        size: 16,
                        color: _copied ? cs.onPrimary : cs.onSurface,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _copied ? 'COPIED!' : 'COPY LINK',
                        style: TextStyle(
                          color: _copied ? cs.onPrimary : cs.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space3),
            TextButton(
              onPressed: _shareLink,
              child: Text(
                'SHARE LINK',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showWifiSheet(BuildContext ctx, Venue venue) {
  final cs = Theme.of(ctx).colorScheme;
  final tt = Theme.of(ctx).textTheme;
  final ssid = venue.wifiSsid ?? '';
  final password = venue.wifiPassword ?? '';
  final security = venue.wifiSecurity ?? 'WPA';
  final isOpenNetwork = security.trim().toUpperCase() == 'OPEN';
  final hasPassword = password.trim().isNotEmpty;
  final wifiQrData = _buildWifiQrData(
    ssid: ssid,
    password: password,
    security: security,
  );

  showModalBottomSheet(
    context: ctx,
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(LucideIcons.wifi, size: 22, color: cs.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ssid,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOpenNetwork
                            ? '$security network • no password required'
                            : '$security • Tap below to copy password',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (hasPassword)
              Material(
                color: cs.primaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: password));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: const Text('WiFi password copied!'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.copy, size: 18, color: cs.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TAP TO COPY PASSWORD',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '•' * password.length.clamp(6, 20),
                                style: tt.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          LucideIcons.arrowRight,
                          size: 16,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.badgeCheck, size: 18, color: cs.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'This is an open network. Your device can join without a password.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'OR SCAN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: wifiQrData,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: Color(0xFF1A1A2E),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Point your phone camera to connect',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _buildWifiQrData({
  required String ssid,
  required String password,
  required String security,
}) {
  String escapeWifiValue(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll(':', r'\:');
  }

  final normalizedSecurity = security.trim().toUpperCase();
  final qrSecurity = normalizedSecurity == 'OPEN'
      ? 'nopass'
      : normalizedSecurity;

  final buffer = StringBuffer('WIFI:');
  buffer.write('S:${escapeWifiValue(ssid)};');
  buffer.write('T:$qrSecurity;');
  if (qrSecurity != 'nopass' && password.trim().isNotEmpty) {
    buffer.write('P:${escapeWifiValue(password)};');
  }
  buffer.write(';');
  return buffer.toString();
}

class _MenuHighlights extends ConsumerWidget {
  final Venue venue;
  final VoidCallback onOpenMenu;

  const _MenuHighlights({required this.venue, required this.onOpenMenu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final menuAsync = ref.watch(menuItemsProvider(venue.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: Text('Highlights', style: tt.headlineLarge)),
              PressableScale(
                onTap: onOpenMenu,
                child: ConstrainedBox(
                  key: const ValueKey('venue-detail-see-all-action'),
                  constraints: const BoxConstraints(
                    minWidth: 96,
                    minHeight: 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SEE ALL',
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          LucideIcons.arrowRight,
                          size: 16,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space6),
        menuAsync.when(
          loading: () => Column(
            children: List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppTheme.space6),
                child: SkeletonLoader(width: double.infinity, height: 180),
              ),
            ),
          ),
          error: (error, stackTrace) => const SizedBox.shrink(),
          data: (items) {
            final highlights = _resolveVenueHighlights(items);

            if (highlights.isEmpty) return const SizedBox.shrink();

            return Column(
              children: highlights.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space6),
                  child: PressableScale(
                    onTap: () => context.pushNamed(
                      AppRouteNames.itemDetail,
                      pathParameters: {AppRouteParams.id: item.id},
                      extra: item,
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: AppColors.white10),
                          boxShadow: AppTheme.ambientShadow,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DineInImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              fallbackIcon: LucideIcons.chefHat,
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.18),
                                      Colors.black.withValues(alpha: 0.92),
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 24,
                              right: 24,
                              bottom: 24,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: tt.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${venue.country.currencySymbol}${item.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

List<MenuItem> _resolveVenueHighlights(List<MenuItem> items) {
  final availableItems = items.where((item) => item.isAvailable).toList();
  if (availableItems.isEmpty) return const [];

  final selectedItems =
      availableItems.where((item) => item.highlightRank != null).toList()
        ..sort((a, b) {
          final aRank = a.highlightRank ?? 99;
          final bRank = b.highlightRank ?? 99;
          return aRank.compareTo(bRank);
        });

  final highlights = <MenuItem>[];
  final seenIds = <String>{};

  for (final item in selectedItems) {
    if (seenIds.add(item.id)) {
      highlights.add(item);
    }
    if (highlights.length == 3) {
      return highlights;
    }
  }

  for (final item in availableItems) {
    if (seenIds.add(item.id)) {
      highlights.add(item);
    }
    if (highlights.length == 3) {
      break;
    }
  }

  return highlights;
}

String _openingHoursLabel(Venue venue) {
  final hours = venue.openingHours;
  if (hours == null || hours.isEmpty) {
    return venue.isOpen ? 'Open Now' : 'Closed';
  }

  const weekdayNames = <int, String>{
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };

  final today = weekdayNames[DateTime.now().weekday];
  final todayHours = today == null ? null : hours[today];
  if (todayHours == null) {
    return venue.isOpen ? 'Open Now' : 'Closed';
  }
  if (!todayHours.isOpen) return 'Closed Today';
  if (todayHours.close.trim().isEmpty) return 'Open Today';
  return 'Open until ${_formatHours(todayHours.close)}';
}

String _formatHours(String raw) {
  final parts = raw.split(':');
  if (parts.length < 2) return raw.toUpperCase();

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return raw.toUpperCase();

  final normalizedHour = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final minutePart = minute == 0 ? '' : ':${minute.toString().padLeft(2, '0')}';
  return '$normalizedHour$minutePart $suffix';
}
