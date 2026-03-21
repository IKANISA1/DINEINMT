import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Venue detail screen — exact match of React VenueDetails.tsx.
///
/// Hero header, floating controls, category badge, rating, expandable About
/// with detail chips, Reviews section, Menu Highlights grid, View Menu CTA.
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

  Future<void> _shareVenue(Venue venue) async {
    final tableLine = widget.tableNumber == null
        ? ''
        : '\nTable: ${widget.tableNumber}';
    await SharePlus.instance.share(
      ShareParams(
        title: '${venue.name} on DineIn',
        text:
            'Check out ${venue.name} on DineIn Malta.\n'
            '${venue.category} • ${venue.address}$tableLine',
      ),
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open the venue phone number.')),
    );
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
      error: (err, _) => Scaffold(
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
        return _buildDetail(context, venue);
      },
    );
  }

  Widget _buildDetail(BuildContext context, Venue venue) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Hero Image Header (45vh) ───
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.45,
            pinned: true,
            stretch: true,
            backgroundColor: cs.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Venue hero image
                  DineInImage(
                    imageUrl: venue.imageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: LucideIcons.store,
                  ),
                  // Bottom gradient to surface
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            cs.surface.withValues(alpha: 0.10),
                            cs.surface,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ─── Venue Title Overlay (bottom) ───
                  Positioned(
                    bottom: 32,
                    left: 32,
                    right: 32,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category badge
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
                                color: cs.primary.withValues(alpha: 0.40),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Text(
                            venue.category.toUpperCase(),
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Venue name (text-5xl)
                        Text(
                          venue.name,
                          style: tt.displayMedium?.copyWith(
                            color: Colors.white,
                            letterSpacing: -2,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Floating controls
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.chevronLeft,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            actions: [
              _FloatingAction(
                icon: LucideIcons.share2,
                onTap: () => _shareVenue(venue),
              ),
              _FloatingAction(
                icon: _isSaved ? LucideIcons.heart : LucideIcons.heartOff,
                iconColor: _isSaved ? cs.primary : Colors.white,
                onTap: () => _toggleSavedVenue(venue),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ─── Content ───
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppTheme.space6),

                // Table badge (if from QR)
                if (widget.tableNumber != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space4),
                    child: Row(
                      children: [
                        StatusBadge(
                          label: 'Table ${widget.tableNumber}',
                          color: cs.primaryContainer.withValues(alpha: 0.30),
                          textColor: cs.primary,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),

                // ─── About Card (expandable accordion) ───
                _AboutSection(
                  description: venue.description,
                  isExpanded: _aboutExpanded,
                  onToggle: () =>
                      setState(() => _aboutExpanded = !_aboutExpanded),
                  isOpen: venue.isOpen,
                  phone: venue.phone,
                  onCall: venue.phone == null ? null : () => _callVenue(venue),
                  venue: venue,
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),

                const SizedBox(height: AppTheme.space6),

                // ─── Menu Highlights ───
                _MenuHighlights(
                  venue: venue,
                ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.05),

                const SizedBox(height: AppTheme.space16),
              ]),
            ),
          ),
        ],
      ),

      // ─── Sticky Bottom CTA ───
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
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
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
              },
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
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: cs.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
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

// ─── Floating action button in app bar ───
class _FloatingAction extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _FloatingAction({
    required this.icon,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
        ),
      ),
    );
  }
}

// ─── Expandable About Section (matches React exactly) ───
class _AboutSection extends StatelessWidget {
  final String description;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool isOpen;
  final String? phone;
  final VoidCallback? onCall;
  final Venue? venue;

  const _AboutSection({
    required this.description,
    required this.isExpanded,
    required this.onToggle,
    required this.isOpen,
    this.phone,
    this.onCall,
    this.venue,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with toggle
          GestureDetector(
            onTap: onToggle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('About', style: tt.headlineMedium), // text-2xl font-black
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isExpanded ? cs.primary : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 500),
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

          // Description with clamp
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
                stops: const [0.6, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.40),
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
                // Detail chips
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DetailChip(
                      icon: LucideIcons.clock,
                      label: isOpen ? 'Open Now' : 'Closed',
                    ),
                    if (phone != null)
                      _DetailChip(
                        icon: LucideIcons.phone,
                        label: 'Call',
                        onTap: onCall,
                      ),
                    if (venue != null && venue!.hasWifi)
                      _DetailChip(
                        icon: LucideIcons.wifi,
                        label: 'WiFi',
                        onTap: () => _showWifiSheet(context, venue!),
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

// ─── Detail chip (Clock, Phone, Globe inside About) ───
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DetailChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
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

// ─── Guest WiFi sheet with copy + QR ───
void _showWifiSheet(BuildContext ctx, Venue venue) {
  final cs = Theme.of(ctx).colorScheme;
  final tt = Theme.of(ctx).textTheme;
  final ssid = venue.wifiSsid ?? '';
  final password = venue.wifiPassword ?? '';
  final security = venue.wifiSecurity ?? 'WPA';
  // Standard WiFi QR code format
  final wifiQrData = 'WIFI:S:$ssid;T:$security;P:$password;;';

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
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
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
                        '$security • Tap below to copy password',
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
            // Copy password button
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
            ),
            const SizedBox(height: 20),
            // Divider with "or scan" label
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
            // QR Code
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

// ─── Menu Highlights Grid ───
class _MenuHighlights extends ConsumerWidget {
  final Venue venue;

  const _MenuHighlights({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Get menu items for this venue (first 3)
    final menuAsync = ref.watch(menuItemsProvider(venue.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Highlights', style: tt.headlineLarge),
              ), // text-3xl font-black
              const SizedBox(width: AppTheme.space3),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: GestureDetector(
                      onTap: () => context.pushNamed(
                        AppRouteNames.menu,
                        pathParameters: {AppRouteParams.slug: venue.slug},
                        extra: venue.id,
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
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space6),

        menuAsync.when(
          loading: () => Column(
            children: List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SkeletonLoader(width: double.infinity, height: 180),
              ),
            ),
          ),
          error: (_, a) => const SizedBox.shrink(),
          data: (items) {
            MenuItem? getHighlight(List<String> kws, Set<String> used) {
              for (final item in items) {
                if (used.contains(item.id)) continue;
                final cat = item.category.toLowerCase();
                if (kws.any((k) => cat.contains(k))) {
                  return item;
                }
              }
              return null;
            }

            final usedIds = <String>{};
            final cocktails = getHighlight(['cocktail'], usedIds);
            if (cocktails != null) usedIds.add(cocktails.id);

            final beers = getHighlight(['beer'], usedIds);
            if (beers != null) usedIds.add(beers.id);

            final mains = getHighlight([
              'main',
              'pizza',
              'burger',
              'pasta',
            ], usedIds);
            if (mains != null) usedIds.add(mains.id);

            final highlights = [
              cocktails,
              beers,
              mains,
            ].whereType<MenuItem>().toList();

            // Fallback to fill up to 3 items
            if (highlights.length < 3) {
              for (final item in items) {
                if (!usedIds.contains(item.id)) {
                  highlights.add(item);
                  usedIds.add(item.id);
                  if (highlights.length >= 3) break;
                }
              }
            }

            if (highlights.isEmpty) return const SizedBox.shrink();

            return Column(
              children: highlights.asMap().entries.map((entry) {
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space6),
                  child: GestureDetector(
                    onTap: () => context.pushNamed(
                      AppRouteNames.menu,
                      pathParameters: {AppRouteParams.slug: venue.slug},
                      extra: venue.id,
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                          boxShadow: AppTheme.clayShadow,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Food image
                            DineInImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              fallbackIcon: LucideIcons.chefHat,
                            ),
                            // Gradient overlay
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.90),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Name + Price
                            Positioned(
                              bottom: 24,
                              left: 24,
                              right: 24,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: tt.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ), // text-xl font-black
                                  ),
                                  const SizedBox(height: 4),
                                  if (venue.isOpen)
                                    Text(
                                      '${venue.country.currencySymbol}${item.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: cs.primary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1,
                                      ), // text-lg primary
                                    )
                                  else
                                    Text(
                                      'PRICE HIDDEN',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.40,
                                        ),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 3.2,
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
