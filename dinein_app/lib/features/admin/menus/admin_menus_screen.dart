import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'admin_menu_item_screen.dart';

enum _MenuAdminTab { catalog, queue }

class AdminMenusScreen extends ConsumerStatefulWidget {
  const AdminMenusScreen({super.key});

  @override
  ConsumerState<AdminMenusScreen> createState() => _AdminMenusScreenState();
}

class _AdminMenusScreenState extends ConsumerState<AdminMenusScreen> {
  final _searchController = TextEditingController();
  _MenuAdminTab _activeTab = _MenuAdminTab.catalog;
  String _query = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const filters = ['all', 'active', 'inactive', 'pending'];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Review Queue',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'By venue status',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filters
                    .map((filter) {
                      final selected = _statusFilter == filter;
                      return ChoiceChip(
                        label: Text(
                          filter[0].toUpperCase() + filter.substring(1),
                        ),
                        selected: selected,
                        onSelected: (_) {
                          setSheetState(() {});
                          setState(() => _statusFilter = filter);
                          Navigator.of(ctx).pop();
                        },
                        selectedColor: cs.primary,
                        labelStyle: TextStyle(
                          color: selected ? cs.onPrimary : cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesStatusFilter(AdminMenuQueueEntry entry) {
    return switch (_statusFilter) {
      'active' => entry.venueStatus == VenueStatus.active,
      'inactive' =>
        entry.venueStatus == VenueStatus.inactive ||
            entry.venueStatus == VenueStatus.suspended ||
            entry.venueStatus == VenueStatus.deleted,
      'pending' => entry.venueStatus == VenueStatus.pendingActivation,
      _ => true,
    };
  }

  bool _isSameDay(DateTime? value, DateTime other) {
    if (value == null) return false;
    return value.year == other.year &&
        value.month == other.month &&
        value.day == other.day;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final catalogAsync = ref.watch(adminMenuCatalogProvider);
    final queueAsync = ref.watch(adminMenuQueueProvider);
    final catalogCount = catalogAsync.asData?.value.length ?? 0;
    final queueCount = queueAsync.asData?.value.length ?? 0;

    if (_activeTab == _MenuAdminTab.catalog &&
        catalogCount == 0 &&
        queueCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _activeTab = _MenuAdminTab.queue);
      });
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              AppTheme.space8,
              AppTheme.space8,
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
                            'Menus',
                            style: tt.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage central menu content, assignments, and review.',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.40,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_activeTab == _MenuAdminTab.queue)
                      PressableScale(
                        onTap: () => _showFilterSheet(context),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                            boxShadow: AppTheme.clayShadow,
                          ),
                          child: Icon(
                            LucideIcons.filter,
                            size: 24,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.40),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.space4),
                Wrap(
                  spacing: AppTheme.space3,
                  runSpacing: AppTheme.space3,
                  children: [
                    PremiumButton(
                      label: 'NEW ITEM',
                      icon: LucideIcons.plus,
                      isOutlined: true,
                      isSmall: true,
                      onPressed: () =>
                          context.pushNamed(AppRouteNames.adminMenuNew),
                    ),
                    const AdminMenuCsvImportAction(),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              AppTheme.space10,
              AppTheme.space8,
              0,
            ),
            child: _SearchBar(
              controller: _searchController,
              hintText: _activeTab == _MenuAdminTab.catalog
                  ? 'Search menu catalog...'
                  : 'Search menu submissions...',
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              AppTheme.space8,
              AppTheme.space8,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Catalog',
                    count: catalogCount,
                    isActive: _activeTab == _MenuAdminTab.catalog,
                    onTap: () =>
                        setState(() => _activeTab = _MenuAdminTab.catalog),
                  ),
                  const SizedBox(width: 8),
                  _TabButton(
                    label: 'Review Queue',
                    count: queueCount,
                    isActive: _activeTab == _MenuAdminTab.queue,
                    onTap: () =>
                        setState(() => _activeTab = _MenuAdminTab.queue),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_activeTab == _MenuAdminTab.catalog)
          ..._buildCatalogSlivers(context, catalogAsync, queueAsync)
        else
          ..._buildQueueSlivers(context, queueAsync),
      ],
    );
  }

  List<Widget> _buildCatalogSlivers(
    BuildContext context,
    AsyncValue<List<AdminMenuCatalogEntry>> catalogAsync,
    AsyncValue<List<AdminMenuQueueEntry>> queueAsync,
  ) {
    return catalogAsync.when(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.space8),
            child: SkeletonLoader(width: double.infinity, height: 260),
          ),
        ),
      ],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: 'Failed to load admin menu catalog.',
            onRetry: () => ref.invalidate(adminMenuCatalogProvider),
          ),
        ),
      ],
      data: (catalog) {
        final normalizedQuery = _query.toLowerCase();
        final filtered = catalog
            .where((entry) {
              if (normalizedQuery.isEmpty) return true;
              return entry.name.toLowerCase().contains(normalizedQuery) ||
                  entry.description.toLowerCase().contains(normalizedQuery) ||
                  entry.category.toLowerCase().contains(normalizedQuery) ||
                  entry.tags.any(
                    (tag) => tag.toLowerCase().contains(normalizedQuery),
                  );
            })
            .toList(growable: false);
        final totalAssignments = catalog.fold<int>(
          0,
          (count, entry) => count + entry.assignedVenueCount,
        );
        final queuePending =
            queueAsync.asData?.value
                .where((entry) => entry.requiresReview)
                .length ??
            0;

        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space8,
                AppTheme.space10,
                AppTheme.space8,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Managed Items',
                      value: '${catalog.length}',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space6),
                  Expanded(
                    child: _StatCard(
                      label: 'Venue Assignments',
                      value: '$totalAssignments',
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space8 + 16,
                AppTheme.space12,
                AppTheme.space8,
                AppTheme.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Central Menu Catalog',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ),
                  if (queuePending > 0)
                    StatusBadge(
                      label: '$queuePending review pending',
                      color: AppColors.secondary.withValues(alpha: 0.14),
                      textColor: AppColors.secondary,
                    ),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: LucideIcons.chefHat,
                title: 'No managed menu items',
                subtitle: _query.isNotEmpty
                    ? 'Try a different search term.'
                    : 'Create or import menu items to manage them centrally.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space8,
                0,
                AppTheme.space8,
                AppTheme.space24,
              ),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.space4),
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  return _AdminMenuCatalogCard(entry: entry);
                },
              ),
            ),
        ];
      },
    );
  }

  List<Widget> _buildQueueSlivers(
    BuildContext context,
    AsyncValue<List<AdminMenuQueueEntry>> queueAsync,
  ) {
    return queueAsync.when(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.space8),
            child: SkeletonLoader(width: double.infinity, height: 260),
          ),
        ),
      ],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: 'Failed to load the menu review queue.',
            onRetry: () => ref.invalidate(adminMenuQueueProvider),
          ),
        ),
      ],
      data: (entries) {
        final normalizedQuery = _query.toLowerCase();
        final filtered = entries
            .where((entry) {
              final matchesQuery =
                  normalizedQuery.isEmpty ||
                  entry.venueName.toLowerCase().contains(normalizedQuery) ||
                  entry.venueId.toLowerCase().contains(normalizedQuery) ||
                  entry.venueCategory.toLowerCase().contains(normalizedQuery);
              return matchesQuery && _matchesStatusFilter(entry);
            })
            .toList(growable: false);
        final pendingReviewCount = entries
            .where((entry) => entry.requiresReview)
            .length;
        final approvedTodayCount = entries
            .where(
              (entry) =>
                  !entry.requiresReview &&
                  _isSameDay(entry.lastUpdatedAt, DateTime.now()),
            )
            .length;

        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space8,
                AppTheme.space10,
                AppTheme.space8,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Pending Review',
                      value: '$pendingReviewCount',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space6),
                  Expanded(
                    child: _StatCard(
                      label: 'Approved Today',
                      value: '$approvedTodayCount',
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space8 + 16,
                AppTheme.space12,
                AppTheme.space8,
                AppTheme.space4,
              ),
              child: Text(
                'Approval Queue',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: LucideIcons.fileText,
                title: 'No menu submissions',
                subtitle: _query.isNotEmpty
                    ? 'Try a different search term.'
                    : 'Venue menu submissions will appear here.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space8,
                0,
                AppTheme.space8,
                AppTheme.space24,
              ),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.space4),
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  return _MenuQueueCard(entry: entry);
                },
              ),
            ),
        ];
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Icon(
              LucideIcons.search,
              size: 24,
              color: cs.onSurfaceVariant.withValues(alpha: 0.20),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                hintStyle: tt.titleLarge?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.10),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
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
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: color.withValues(alpha: 0.10)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: color,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            value,
            style: tt.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuCatalogCard extends StatelessWidget {
  final AdminMenuCatalogEntry entry;

  const _AdminMenuCatalogCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final imageBadge = switch (entry.imageStatus) {
      MenuItemImageStatus.ready => 'Image Ready',
      MenuItemImageStatus.generating => 'Generating',
      MenuItemImageStatus.failed => 'Retry Image',
      MenuItemImageStatus.pending => 'Needs Image',
    };

    return ClayCard(
      onTap: () => context.pushNamed(
        AppRouteNames.adminMenuItem,
        pathParameters: {AppRouteParams.id: entry.groupId},
      ),
      padding: const EdgeInsets.all(AppTheme.space5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: SizedBox(
              width: 88,
              height: 88,
              child: DineInImage(
                imageUrl: entry.imageUrl,
                fit: BoxFit.cover,
                fallbackIcon: LucideIcons.chefHat,
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
                        entry.name,
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space2),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.description.isEmpty
                      ? 'Shared content for centrally assigned venues.'
                      : entry.description,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.space3),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: entry.category,
                      color: cs.surfaceContainerHighest,
                      textColor: cs.onSurface,
                    ),
                    if (entry.itemClass != null)
                      StatusBadge(
                        label: entry.itemClass!.label,
                        color: cs.primary.withValues(alpha: 0.12),
                        textColor: cs.primary,
                      ),
                    StatusBadge(
                      label: '${entry.assignedVenueCount} venues',
                      color: cs.secondary.withValues(alpha: 0.12),
                      textColor: cs.secondary,
                    ),
                    StatusBadge(
                      label: imageBadge,
                      color: entry.imageStatus == MenuItemImageStatus.ready
                          ? cs.secondary.withValues(alpha: 0.12)
                          : cs.tertiary.withValues(alpha: 0.12),
                      textColor: entry.imageStatus == MenuItemImageStatus.ready
                          ? cs.secondary
                          : cs.tertiary,
                    ),
                  ],
                ),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space3),
                  Text(
                    entry.tags.take(4).join(' • '),
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuQueueCard extends StatelessWidget {
  final AdminMenuQueueEntry entry;

  const _MenuQueueCard({required this.entry});

  String _summaryLabel() {
    final segments = <String>['${entry.totalItems} items'];
    if (entry.categoryCount > 0) {
      segments.add('${entry.categoryCount} categories');
    }
    return segments.join(' • ');
  }

  String _statusDetailLabel() {
    if (entry.requiresReview) {
      final segments = <String>['${entry.pendingReviewCount} pending'];
      if (entry.failedReviewCount > 0) {
        segments.add('${entry.failedReviewCount} failed');
      }
      return segments.join(' • ');
    }
    return '${entry.readyCount} ready';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isParsed = !entry.requiresReview;
    final statusLabel = isParsed ? 'Parsed' : 'Review Required';

    return PressableScale(
      onTap: () => context.pushNamed(
        AppRouteNames.adminMenuReview,
        pathParameters: {AppRouteParams.id: entry.venueId},
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(48),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: AppTheme.clayShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.clayShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    if (entry.venueImageUrl != null)
                      Positioned.fill(
                        child: DineInImage(
                          imageUrl: entry.venueImageUrl,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                        ),
                      ),
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.50),
                      ),
                    ),
                    Center(
                      child: Icon(
                        LucideIcons.fileText,
                        size: 32,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.40),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.venueName,
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space2),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 20,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.40),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _summaryLabel(),
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppTheme.space2),
                  Text(
                    entry.venueAddress.isEmpty
                        ? entry.venueCategory
                        : entry.venueAddress,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.70),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.space3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusBadge(
                        label: statusLabel,
                        color: isParsed
                            ? cs.secondary.withValues(alpha: 0.12)
                            : cs.error.withValues(alpha: 0.12),
                        textColor: isParsed ? cs.secondary : cs.error,
                      ),
                      StatusBadge(
                        label: _statusDetailLabel(),
                        color: cs.surfaceContainerHighest,
                        textColor: cs.onSurface,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
