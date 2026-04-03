import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

class AdminVenuesScreen extends ConsumerStatefulWidget {
  const AdminVenuesScreen({super.key});

  @override
  ConsumerState<AdminVenuesScreen> createState() => _AdminVenuesScreenState();
}

class _AdminVenuesScreenState extends ConsumerState<AdminVenuesScreen> {
  String _activeTab = 'active';
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final config = ref.watch(countryConfigProvider);
    final venuesAsync = ref.watch(allVenuesProvider);

    return Scaffold(
      body: venuesAsync.when(
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 300),
        ),
        error: (_, _) => ErrorState(
          message: 'Could not load venues.',
          onRetry: () => ref.invalidate(allVenuesProvider),
        ),
        data: (venues) {
          final filtered = _query.isEmpty
              ? venues
              : venues
                    .where((venue) {
                      final q = _query.toLowerCase();
                      return venue.name.toLowerCase().contains(q) ||
                          venue.id.toLowerCase().contains(q) ||
                          venue.slug.toLowerCase().contains(q) ||
                          venue.address.toLowerCase().contains(q) ||
                          venue.category.toLowerCase().contains(q);
                    })
                    .toList(growable: false);

          final activeVenues = filtered
              .where((venue) => venue.status == VenueStatus.active)
              .toList(growable: false);
          final inactiveVenues = filtered
              .where((venue) => venue.status != VenueStatus.active)
              .toList(growable: false);
          final displayVenues = _activeTab == 'active'
              ? activeVenues
              : inactiveVenues;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space6,
                    AppTheme.space6,
                    AppTheme.space6,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Venues',
                                  style: tt.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage venue details, guest links, and access QR.',
                                  style: tt.bodyLarge?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PremiumButton(
                            label: 'NEW VENUE',
                            icon: LucideIcons.plus,
                            isOutlined: true,
                            isSmall: true,
                            onPressed: () => context.pushNamed(
                              AppRouteNames.adminVenueCreate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space6),
                      _SearchBar(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(48),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            _TabButton(
                              label: 'Active',
                              count: activeVenues.length,
                              isActive: _activeTab == 'active',
                              onTap: () =>
                                  setState(() => _activeTab = 'active'),
                            ),
                            const SizedBox(width: 8),
                            _TabButton(
                              label: 'Inactive',
                              count: inactiveVenues.length,
                              isActive: _activeTab == 'inactive',
                              onTap: () =>
                                  setState(() => _activeTab = 'inactive'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        'Each venue includes the direct guest link, the smart venue app link, and a guest QR code.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space6),
                    ],
                  ),
                ),
              ),
              if (displayVenues.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: LucideIcons.store,
                    title: _activeTab == 'active'
                        ? 'No active venues'
                        : 'No inactive venues',
                    subtitle: _query.isNotEmpty
                        ? 'Try a different search term.'
                        : 'Create a venue or change the current filter.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space6,
                  ),
                  sliver: SliverList.separated(
                    itemCount: displayVenues.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTheme.space4),
                    itemBuilder: (context, index) {
                      final venue = displayVenues[index];
                      final guestUri = buildVenueDeepLinkUri(
                        slug: venue.slug,
                        config: config,
                      );
                      final appUri = buildVenueDownloadRedirectUri(
                        slug: venue.slug,
                        config: config,
                        venueName: venue.name,
                      );

                      return _VenueCard(
                            venue: venue,
                            guestUri: guestUri,
                            appUri: appUri,
                            onOpenDetail: () => context.pushNamed(
                              AppRouteNames.adminVenueDetail,
                              pathParameters: {AppRouteParams.id: venue.id},
                            ),
                            onShowQr: () => _showQrSheet(
                              context,
                              title: '${venue.name} guest access',
                              subtitle: 'Scan to open the venue on DineIn',
                              uri: appUri,
                            ),
                          )
                          .animate(delay: (50 * index).ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.05, end: 0);
                    },
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.space24),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showQrSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Uri uri,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    await showModalBottomSheet<void>(
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
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: uri.toString()));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Venue link copied.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: 20,
            color: cs.onSurface.withValues(alpha: 0.10),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                hintText: 'Search venues by name, slug, or address...',
                border: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                hintStyle: tt.titleSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.12),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(40),
            boxShadow: isActive ? AppTheme.clayShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isActive ? cs.onPrimary : cs.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? cs.onPrimary.withValues(alpha: 0.15)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final Venue venue;
  final Uri guestUri;
  final Uri appUri;
  final VoidCallback onOpenDetail;
  final VoidCallback onShowQr;

  const _VenueCard({
    required this.venue,
    required this.guestUri,
    required this.appUri,
    required this.onOpenDetail,
    required this.onShowQr,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ClayCard(
      onTap: onOpenDetail,
      padding: const EdgeInsets.all(AppTheme.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: DineInImage(
                    imageUrl: venue.imageUrl,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            venue.name,
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space2),
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
                    const SizedBox(height: 6),
                    Text(
                      venue.category,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      venue.address.isEmpty ? venue.slug : venue.address,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.space3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusBadge(
                          label: venue.orderingEnabled
                              ? 'Ordering On'
                              : 'Browse Only',
                          color: venue.orderingEnabled
                              ? cs.primary.withValues(alpha: 0.12)
                              : cs.surfaceContainerHighest,
                          textColor: venue.orderingEnabled
                              ? cs.primary
                              : cs.onSurface,
                        ),
                        if (venue.hasAssignedAccessPhone)
                          StatusBadge(
                            label: venue.isAccessReady
                                ? 'OTP Ready'
                                : 'OTP Pending',
                            color: venue.isAccessReady
                                ? cs.secondary.withValues(alpha: 0.12)
                                : cs.tertiary.withValues(alpha: 0.12),
                            textColor: venue.isAccessReady
                                ? cs.secondary
                                : cs.tertiary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _LinkRow(label: 'Guest URL', value: guestUri.toString()),
                    const SizedBox(height: AppTheme.space3),
                    _LinkRow(label: 'Venue App URL', value: appUri.toString()),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space4),
              PressableScale(
                onTap: onShowQr,
                child: Container(
                  width: 96,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: appUri.toString(),
                        version: QrVersions.auto,
                        size: 60,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Guest QR',
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF121416),
                        ),
                      ),
                    ],
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

class _LinkRow extends StatelessWidget {
  final String label;
  final String value;

  const _LinkRow({required this.label, required this.value});

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  Future<void> _openLink(BuildContext context) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Unable to open $label.')));
  }

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
                onTap: () => _copyLink(context),
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
                onTap: () => _openLink(context),
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
