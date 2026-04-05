import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:core_pkg/config/country_config_provider.dart';
import 'package:core_pkg/constants/app_download_links.dart';
import 'package:core_pkg/constants/enums.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/shared/widgets/branded_qr_tools.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

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
                          PressableScale(
                            onTap: () => _showSearchSheet(context, cs, tt),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _query.isNotEmpty
                                    ? cs.primary.withValues(alpha: 0.15)
                                    : cs.surfaceContainerLow,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _query.isNotEmpty
                                      ? cs.primary.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Icon(
                                LucideIcons.search,
                                size: 18,
                                color: _query.isNotEmpty
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                      // Active search query chip
                      if (_query.isNotEmpty) ...[
                        PressableScale(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          semanticLabel: 'Clear search',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusFull,
                              ),
                              border: Border.all(
                                color: cs.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.search,
                                  size: 12,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '"$_query"',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  LucideIcons.x,
                                  size: 12,
                                  color: cs.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.space4),
                      ],
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space6,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: DataTable(
                          headingTextStyle: tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.onSurfaceVariant,
                            letterSpacing: 1.5,
                          ),
                          dataRowMinHeight: 72,
                          dataRowMaxHeight: 72,
                          columns: const [
                            DataColumn(label: Text('VENUE')),
                            DataColumn(label: Text('SLUG')),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('MODE')),
                            DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: displayVenues.map((venue) {
                            final guestUri = buildVenueDeepLinkUri(
                              slug: venue.slug,
                              config: config,
                            );

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: DineInImage(
                                            imageUrl: venue.imageUrl,
                                            fit: BoxFit.cover,
                                            fallbackIcon: LucideIcons.store,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            venue.name,
                                            style: tt.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            venue.category,
                                            style: tt.bodySmall?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    venue.slug,
                                    style: tt.bodyMedium?.copyWith(
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                DataCell(
                                  StatusBadge(
                                    label: venue.status.label,
                                    color: venue.status == VenueStatus.active
                                        ? cs.secondary.withValues(alpha: 0.12)
                                        : cs.error.withValues(alpha: 0.12),
                                    textColor:
                                        venue.status == VenueStatus.active
                                        ? cs.secondary
                                        : cs.error,
                                  ),
                                ),
                                DataCell(
                                  StatusBadge(
                                    label: venue.orderingEnabled
                                        ? 'Ordering'
                                        : 'Browse Only',
                                    color: venue.orderingEnabled
                                        ? cs.primary.withValues(alpha: 0.12)
                                        : cs.surfaceContainerHighest,
                                    textColor: venue.orderingEnabled
                                        ? cs.primary
                                        : cs.onSurface,
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          LucideIcons.externalLink,
                                          size: 20,
                                        ),
                                        color: cs.onSurfaceVariant,
                                        tooltip: 'Open Guest Link',
                                        onPressed: () => _openLink(
                                          context,
                                          guestUri.toString(),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          LucideIcons.copy,
                                          size: 20,
                                        ),
                                        color: cs.onSurfaceVariant,
                                        tooltip: 'Copy Guest Link',
                                        onPressed: () => _copyLink(
                                          context,
                                          guestUri.toString(),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          LucideIcons.qrCode,
                                          size: 20,
                                        ),
                                        color: cs.onSurfaceVariant,
                                        tooltip: 'Guest QR Code',
                                        onPressed: () => _showQrSheet(
                                          context,
                                          title: '${venue.name} guest QR',
                                          subtitle:
                                              'Guests scan this QR to open the venue menu directly.',
                                          uri: guestUri,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          LucideIcons.edit2,
                                          size: 20,
                                        ),
                                        color: cs.primary,
                                        tooltip: 'Edit Venue',
                                        onPressed: () => context.pushNamed(
                                          AppRouteNames.adminVenueDetail,
                                          pathParameters: {
                                            AppRouteParams.id: venue.id,
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
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

  Future<void> _copyLink(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied.')));
  }

  Future<void> _openLink(BuildContext context, String value) async {
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
    ).showSnackBar(const SnackBar(content: Text('Unable to open link.')));
  }

  Future<void> _showQrSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Uri uri,
  }) async {
    showBrandedQrSheet(
      context: context,
      title: title,
      helperText: subtitle,
      uri: uri,
      shareFileName: '${venueQrFileSlug(title)}_qr.png',
      shareSubject: '$title QR',
      copyFeedbackMessage: 'Venue link copied.',
      openLabel: 'venue link',
    );
  }

  void _showSearchSheet(BuildContext context, ColorScheme cs, TextTheme tt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.space6,
            AppTheme.space6,
            AppTheme.space6,
            MediaQuery.of(sheetContext).viewInsets.bottom + AppTheme.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppTheme.space5),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
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
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (v) => setState(() => _query = v.trim()),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => Navigator.pop(sheetContext),
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Search venues by name, slug, or address...',
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
              ),
            ],
          ),
        );
      },
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
      child: PressableScale(
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

String venueQrFileSlug(String raw) {
  final normalized = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return normalized.replaceAll(RegExp(r'^_+|_+$'), '');
}
