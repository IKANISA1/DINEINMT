import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:core_pkg/config/country_config_provider.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/app_telemetry.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

import 'menu_item_badges.dart';

/// Full-page item detail screen.
class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  int _quantity = 1;
  final _noteController = TextEditingController();
  bool _isSaved = false;
  String? _trackedItemViewId;

  void _trackGuestEvent(
    String eventName, {
    String? venueId,
    String? menuItemId,
    Map<String, Object?> details = const {},
  }) {
    unawaited(
      AppTelemetryService.trackGuestEvent(
        eventName,
        route: '/item/${widget.itemId}',
        venueId: venueId,
        menuItemId: menuItemId,
        details: details,
      ),
    );
  }

  void _trackItemViewed(MenuItem item, Venue? venue) {
    if (_trackedItemViewId == item.id) return;
    _trackedItemViewId = item.id;
    _trackGuestEvent(
      'item_detail_viewed',
      venueId: venue?.id ?? item.venueId,
      menuItemId: item.id,
      details: {'category': item.category, 'has_venue_context': venue != null},
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _handleAddToCart(MenuItem item, Venue? venue) {
    final cartNotifier = ref.read(cartProvider.notifier);
    final cart = ref.read(cartProvider);
    if (venue != null) {
      cartNotifier.setVenue(
        venueId: venue.id,
        venueSlug: venue.slug,
        venueName: venue.name,
        venueRevolutUrl: venue.revolutUrl,
        venueCountry: venue.country,
        tableNumber: cart.tableNumber,
      );
    }

    final note = _noteController.text.trim();
    cartNotifier.addItem(
      item,
      note: note.isEmpty ? null : note,
      quantity: _quantity,
    );

    _trackGuestEvent(
      'menu_item_added',
      venueId: venue?.id ?? item.venueId,
      menuItemId: item.id,
      details: {
        'source': 'item_detail',
        'quantity': _quantity,
        'has_note': note.isNotEmpty,
      },
    );

    context.pop();
  }

  Future<void> _shareItem(MenuItem item) async {
    final config = ref.read(countryConfigProvider);
    final country = ref.read(cartProvider).effectiveCountry;
    await SharePlus.instance.share(
      ShareParams(
        title: '${item.name} on DINEIN',
        text:
            'Check out ${item.name} on ${config.appTitle}.\n'
            '${item.description}\n'
            'Price: ${country.formatPrice(item.price)}',
      ),
    );
  }

  void _toggleSavedItem(MenuItem item) {
    setState(() => _isSaved = !_isSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved
              ? '${item.name} saved for later.'
              : '${item.name} removed from saved items.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final seededItem = extra is MenuItem ? extra : null;
    final itemAsync = seededItem == null
        ? ref.watch(menuItemByIdProvider(widget.itemId))
        : AsyncValue<MenuItem?>.data(seededItem);

    return itemAsync.when(
      loading: () => const Scaffold(body: _ItemDetailLoadingState()),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: ErrorState(
            message: 'Could not load this menu item.',
            onRetry: () => ref.invalidate(menuItemByIdProvider(widget.itemId)),
          ),
        ),
      ),
      data: (item) {
        if (item == null || !item.isAvailable) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space6),
                child: GuestStatePanel(
                  icon: LucideIcons.alertCircle,
                  title: 'Item not found',
                  subtitle: 'This item is no longer on the menu.',
                  actionLabel: 'Back',
                  onAction: () {
                    if (Navigator.of(context).canPop()) {
                      context.pop();
                    } else {
                      context.goNamed(AppRouteNames.discover);
                    }
                  },
                  isError: true,
                ),
              ),
            ),
          );
        }

        final venueAsync = ref.watch(venueByIdProvider(item.venueId));
        final venue = venueAsync.asData?.value;
        _trackItemViewed(item, venue);
        final cart = ref.watch(cartProvider);
        final country = venue?.country ?? cart.effectiveCountry;
        final total = item.price * _quantity;

        return Scaffold(
          bottomNavigationBar: GuestStickyActionBar(
            child: Row(
              children: [
                _QuantityStepper(
                  quantity: _quantity,
                  onDecrease: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  onIncrease: () => setState(() => _quantity++),
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _handleAddToCart(item, venue),
                    child: Text('Add ${country.formatPrice(total)}'),
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 280,
                      width: double.infinity,
                      child: DineInImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        fallbackIcon: LucideIcons.chefHat,
                        semanticLabel: '${item.name} photo',
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.08),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: AppTheme.space4,
                      left: AppTheme.space4,
                      right: AppTheme.space4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _OverlayAction(
                            icon: LucideIcons.chevronLeft,
                            onTap: () => context.pop(),
                            semanticLabel: 'Go back',
                          ),
                          Row(
                            children: [
                              _OverlayAction(
                                icon: LucideIcons.share2,
                                onTap: () => _shareItem(item),
                                semanticLabel: 'Share item',
                              ),
                              const SizedBox(width: AppTheme.space2),
                              _OverlayAction(
                                icon: _isSaved
                                    ? LucideIcons.heart
                                    : LucideIcons.heartOff,
                                onTap: () => _toggleSavedItem(item),
                                semanticLabel: _isSaved
                                    ? 'Remove from saved'
                                    : 'Save item',
                                iconColor: _isSaved
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space6,
                    AppTheme.space5,
                    AppTheme.space6,
                    0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GuestSurfaceCard(
                            highlighted: true,
                            padding: const EdgeInsets.all(AppTheme.space5),
                            borderRadius: 28,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.guestDisplayTags.isNotEmpty) ...[
                                  MenuItemBadges(item: item),
                                  const SizedBox(height: AppTheme.space4),
                                ],
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineMedium,
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.space4),
                                    Text(
                                      country.formatPrice(item.price),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.space3),
                                Wrap(
                                  spacing: AppTheme.space2,
                                  runSpacing: AppTheme.space2,
                                  children: [
                                    GuestMetaPill(
                                      label: item.category,
                                      icon: LucideIcons.utensilsCrossed,
                                    ),
                                    if (venue != null)
                                      GuestMetaPill(
                                        label: venue.name,
                                        icon: LucideIcons.store,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.space4),
                                Text(
                                  item.description,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        height: 1.5,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.space4),
                          GuestSurfaceCard(
                            padding: const EdgeInsets.all(AppTheme.space5),
                            borderRadius: 24,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    LucideIcons.shieldAlert,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.space4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Allergy notice',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: AppTheme.space2),
                                      Text(
                                        'Please tell staff about allergies before ordering.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.space4),
                          GuestSurfaceCard(
                            padding: const EdgeInsets.all(AppTheme.space5),
                            borderRadius: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const GuestSectionHeader(
                                  title: 'Notes',
                                  subtitle: 'Optional request for this item.',
                                ),
                                const SizedBox(height: AppTheme.space4),
                                TextField(
                                  controller: _noteController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'No onions, extra spicy, sauce on the side…',
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ItemDetailLoadingState extends StatelessWidget {
  const _ItemDetailLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: const [
        SkeletonLoader(width: double.infinity, height: 280, borderRadius: 0),
        Padding(
          padding: EdgeInsets.all(AppTheme.space6),
          child: Column(
            children: [
              SkeletonLoader(
                width: double.infinity,
                height: 180,
                borderRadius: 28,
              ),
              SizedBox(height: AppTheme.space4),
              SkeletonLoader(
                width: double.infinity,
                height: 88,
                borderRadius: 24,
              ),
              SizedBox(height: AppTheme.space4),
              SkeletonLoader(
                width: double.infinity,
                height: 150,
                borderRadius: 24,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverlayAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final Color? iconColor;

  const _OverlayAction({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: iconColor ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;

  const _QuantityStepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(icon: LucideIcons.minus, onTap: onDecrease),
          SizedBox(
            width: 44,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          _StepperButton(
            icon: LucideIcons.plus,
            onTap: onIncrease,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool emphasized;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDisabled = onTap == null;

    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Change quantity',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: emphasized ? cs.primary : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: emphasized
              ? cs.onPrimary
              : isDisabled
              ? cs.onSurfaceVariant.withValues(alpha: 0.32)
              : cs.onSurface,
        ),
      ),
    );
  }
}
