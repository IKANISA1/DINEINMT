import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/services/app_telemetry.dart';
import 'package:dinein_app/core/services/order_repository.dart';
import 'package:dinein_app/core/services/notification_inbox_service.dart';
import 'package:dinein_app/core/services/pwa_install_service.dart';
import 'package:dinein_app/shared/widgets/safari_install_guide.dart';
import 'package:dinein_app/core/services/venue_repository.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// Cart / Order Summary screen — exact match of React OrderSummary.tsx.
///
/// Features: item cards with qty +/-, table number input, special requests,
/// service fee calculation, payment buttons (Revolut + Cash).
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _tableController = TextEditingController();
  final _requestsController = TextEditingController();
  final _tableFocusNode = FocusNode();
  final _requestsFocusNode = FocusNode();
  late final CartNotifier _cartNotifier;
  bool _isPlacing = false;
  bool _tableError = false;
  String? _error;
  final _tableCardKey = GlobalKey();
  bool _animateCartItems = true;
  bool _queuedCartAnimationSettle = false;
  String _persistedTableNumber = '';
  String _persistedSpecialRequests = '';
  bool _trackedCartView = false;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _cartNotifier = ref.read(cartProvider.notifier);
    _tableController.text = cart.tableNumber ?? '';
    _requestsController.text = cart.specialRequests ?? '';
    _persistedTableNumber = cart.tableNumber ?? '';
    _persistedSpecialRequests = cart.specialRequests ?? '';
    _tableFocusNode.addListener(_handleTableFocusChange);
    _requestsFocusNode.addListener(_handleRequestsFocusChange);
  }

  @override
  void dispose() {
    _tableFocusNode.removeListener(_handleTableFocusChange);
    _requestsFocusNode.removeListener(_handleRequestsFocusChange);
    _tableFocusNode.dispose();
    _requestsFocusNode.dispose();
    _tableController.dispose();
    _requestsController.dispose();
    super.dispose();
  }

  void _handleTableFocusChange() {
    if (!_tableFocusNode.hasFocus) {
      _syncTableNumber();
    }
  }

  void _handleRequestsFocusChange() {
    if (!_requestsFocusNode.hasFocus) {
      _syncSpecialRequests();
    }
  }

  void _syncDraftFields({bool clearError = true}) {
    _syncTableNumber(clearError: clearError);
    _syncSpecialRequests();
  }

  void _syncTableNumber({bool clearError = true}) {
    final normalized = _tableController.text.trim();
    if (normalized != _persistedTableNumber) {
      _cartNotifier.setTableNumber(normalized);
      _persistedTableNumber = normalized;
    }

    if (clearError && normalized.isNotEmpty && _tableError && mounted) {
      setState(() => _tableError = false);
    }
  }

  void _syncSpecialRequests() {
    final normalized = _requestsController.text.trim();
    if (normalized == _persistedSpecialRequests) return;
    _cartNotifier.setSpecialRequests(normalized);
    _persistedSpecialRequests = normalized;
  }

  void _queueCartAnimationSettle() {
    if (!_animateCartItems || _queuedCartAnimationSettle) return;
    _queuedCartAnimationSettle = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queuedCartAnimationSettle = false;
      if (!mounted || !_animateCartItems) return;
      setState(() => _animateCartItems = false);
    });
  }

  void _trackGuestEvent(
    String eventName, {
    String? venueId,
    String? orderId,
    Map<String, Object?> details = const {},
  }) {
    unawaited(
      AppTelemetryService.trackGuestEvent(
        eventName,
        route: AppRoutePaths.cart,
        venueId: venueId,
        orderId: orderId,
        details: details,
      ),
    );
  }

  Future<void> _placeOrder(PaymentMethod method) async {
    // Validate table number
    if (_tableController.text.trim().isEmpty) {
      setState(() => _tableError = true);
      // Trigger haptic + shake
      HapticFeedback.mediumImpact();
      return;
    }

    final cartNotifier = _cartNotifier;
    _syncDraftFields(clearError: false);
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    setState(() {
      _isPlacing = true;
      _error = null;
    });

    try {
      final venueId = cart.venueId?.trim();
      if (venueId == null || venueId.isEmpty) {
        throw Exception('Select a venue before placing the order.');
      }
      final venue = await VenueRepository.instance.getVenueById(venueId);
      if (venue == null || !venue.canAcceptGuestOrders) {
        throw Exception(
          'This venue is unavailable. You can browse the menu, but ordering is disabled until validation is complete.',
        );
      }
      final user = ref.read(currentUserProvider);
      final order = cartNotifier.buildOrder(
        paymentMethod: method,
        userId: user?.id,
      );
      _trackGuestEvent(
        'checkout_started',
        venueId: venueId,
        details: {
          'payment_method': method.dbValue,
          'item_count': cart.itemCount,
          'cart_total': cart.total,
          'table_number': cart.tableNumber,
        },
      );

      final placed = await OrderRepository.instance.placeOrder(order);
      _trackGuestEvent(
        'order_placed',
        venueId: venueId,
        orderId: placed.id,
        details: {
          'payment_method': method.dbValue,
          'item_count': cart.itemCount,
          'cart_total': cart.total,
          'order_number': placed.displayNumber,
        },
      );

      if (method == PaymentMethod.revolutLink) {
        final config = ref.read(countryConfigProvider);
        final rawUrl = cart.venueRevolutUrl?.trim().isNotEmpty == true
            ? cart.venueRevolutUrl!.trim()
            : (config.revolutPayUrl ?? 'https://revolut.me/dinein');
        final url = Uri.parse(rawUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } else if (method == PaymentMethod.momoUssd) {
        final config = ref.read(countryConfigProvider);
        final ussdCode = config.momoUssdCode;
        if (ussdCode != null) {
          final url = Uri.parse('tel:$ussdCode');
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        }
      }

      cartNotifier.clear();

      // Show success toast + inbox entry
      DineInToast.instance.success('Order placed! Track your order status.');
      NotificationInboxService.instance.add(
        id: 'order-placed-${placed.id}',
        title: 'Order placed',
        body: 'Order #${placed.displayNumber} has been placed successfully.',
        type: 'order',
      );

      // G-21: Trigger PWA install prompt after successful order
      PwaInstallService.triggerIfEligible(reason: 'order_placed');

      // iOS Safari install guide (no beforeinstallprompt on iOS)
      if (mounted) {
        SafariInstallGuide.showIfEligible(context);
      }

      if (mounted) {
        ref.invalidate(userOrdersProvider);
        context.goNamed(
          AppRouteNames.orderSuccess,
          queryParameters: {
            AppRouteParams.id: placed.id,
            AppRouteParams.orderNumber: placed.displayNumber,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlacing = false;
          final msg = e.toString().replaceFirst('Exception: ', '');
          _error = msg.isNotEmpty
              ? msg
              : 'Could not place order. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final venueAsync = cart.venueId == null
        ? const AsyncData<Venue?>(null)
        : ref.watch(venueByIdProvider(cart.venueId!));
    final venue = venueAsync.asData?.value;
    final orderingUnavailable = venue != null && !venue.canAcceptGuestOrders;
    final venueRevolutUrl = venue?.revolutUrl?.trim().isNotEmpty == true
        ? venue!.revolutUrl!.trim()
        : cart.venueRevolutUrl?.trim() ?? '';
    final hasRevolutLink = venueRevolutUrl.isNotEmpty;
    final supportedPaymentMethods = venue?.supportedPaymentMethods;
    final supportsCash =
        supportedPaymentMethods?.contains(PaymentMethod.cash) ?? true;
    final supportsRevolut =
        hasRevolutLink &&
        (supportedPaymentMethods?.contains(PaymentMethod.revolutLink) ?? true);

    if (cart.itemCount > 0 && !_trackedCartView) {
      _trackedCartView = true;
      _trackGuestEvent(
        'cart_viewed',
        venueId: cart.venueId,
        details: {
          'item_count': cart.itemCount,
          'cart_total': cart.total,
          'table_number_present': (cart.tableNumber ?? '').trim().isNotEmpty,
        },
      );
    }

    // Empty cart
    if (cart.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.shoppingBag,
                      size: 48,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space6),
                  Text(
                    'Your cart is empty',
                    style: tt.headlineLarge,
                  ), // text-3xl font-black
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    "Looks like you haven't added\nanything to your order yet.",
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  ElevatedButton(
                    onPressed: () => context.goNamed(AppRouteNames.discover),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Explore Venues',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final finalTotal = cart.total;
    _queueCartAnimationSettle();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _syncDraftFields(clearError: false);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.space8),
            children: [
              // ─── Header ───
              Row(
                children: [
                  PressableScale(
                    semanticLabel: 'Go back',
                    onTap: () {
                      _syncDraftFields(clearError: false);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Icon(LucideIcons.chevronLeft, size: 28),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space6),
                  Text('Your Order', style: tt.displaySmall), // text-4xl = 36px
                ],
              ),

              const SizedBox(height: AppTheme.space10),

              // ─── Cart Items ───
              ...cart.items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final card = _CartItemCard(
                  key: ValueKey('cart-item-${item.menuItemId}'),
                  item: item,
                  country: cart.effectiveCountry,
                  onUpdateQty: (newQty) =>
                      cartNotifier.setQuantity(item.menuItemId, newQty),
                  onRemove: () => cartNotifier.setQuantity(item.menuItemId, 0),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space6),
                  child: _animateCartItems
                      ? card
                            .animate(delay: (100 * idx).ms)
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1)
                      : card,
                );
              }),

              const SizedBox(height: AppTheme.space8),

              // ─── Compact Action Bar ───
              Row(
                children: [
                  // Table number icon
                  Expanded(
                    child: _CompactActionChip(
                      key: _tableCardKey,
                      icon: LucideIcons.hash,
                      label: _tableController.text.trim().isEmpty
                          ? 'Table #'
                          : 'Table ${_tableController.text.trim()}',
                      isError: _tableError,
                      onTap: () => _showTableNumberSheet(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Special requests icon
                  Expanded(
                    child: _CompactActionChip(
                      icon: LucideIcons.messageSquare,
                      label: _requestsController.text.trim().isEmpty
                          ? 'Notes'
                          : 'Notes ✓',
                      iconColor: AppColors.secondary,
                      onTap: () => _showSpecialRequestsSheet(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Add more items
                  Expanded(
                    child: _CompactActionChip(
                      icon: LucideIcons.plus,
                      label: 'Add more',
                      onTap: () {
                        _syncDraftFields(clearError: false);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              )
                  .animate(target: _tableError ? 1 : 0)
                  .shimmer(
                    duration: 400.ms,
                    color: cs.error.withValues(alpha: 0.15),
                  )
                  .shake(
                    hz: 8,
                    rotation: 0,
                    offset: const Offset(6, 0),
                    duration: 400.ms,
                  ),

              const SizedBox(height: AppTheme.space10),

              if (orderingUnavailable) ...[
                Container(
                  padding: const EdgeInsets.all(AppTheme.space5),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.alertTriangle,
                        size: 18,
                        color: cs.primary,
                      ),
                      const SizedBox(width: AppTheme.space3),
                      Expanded(
                        child: Text(
                          venue.guestAvailabilityReason,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
              ],

              // ─── Error message ───
              if (_error != null) ...[
                Text(
                  _error!,
                  style: tt.bodySmall?.copyWith(color: cs.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.space4),
              ],

              // ─── Order Total Card ───
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.40),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Total row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Total',
                          style: tt.titleMedium,
                        ),
                        Text(
                          cart.formatPrice(finalTotal),
                          style: tt.headlineMedium?.copyWith(
                            color: cs.primary,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space4),

                    // ─── Payment Buttons (country-aware) ───
                    ..._buildPaymentButtons(
                      cs: cs,
                      orderingUnavailable: orderingUnavailable,
                      supportsCash: supportsCash,
                      supportsRevolut: supportsRevolut,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.space16),
            ],
          ),
        ),
      ),
    );
  }

  void _showTableNumberSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Table Number', style: tt.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _tableController,
              focusNode: _tableFocusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              style: tt.headlineSmall,
              onChanged: (v) {
                if (v.trim().isNotEmpty && _tableError) {
                  setState(() => _tableError = false);
                }
              },
              onSubmitted: (_) {
                _syncTableNumber();
                Navigator.of(ctx).pop();
              },
              decoration: InputDecoration(
                hintText: 'Enter your table number',
                hintStyle: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                ),
                prefixIcon: Icon(LucideIcons.hash, color: cs.primary),
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _syncTableNumber();
                  Navigator.of(ctx).pop();
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _showSpecialRequestsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Special Requests', style: tt.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _requestsController,
              focusNode: _requestsFocusNode,
              autofocus: true,
              maxLines: 3,
              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText:
                    'Any allergies or preferences?\n(e.g. No onions, extra spicy)',
                hintStyle: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                ),
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _syncSpecialRequests();
                  Navigator.of(ctx).pop();
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => setState(() {}));
  }

  /// Build country-aware payment buttons.
  /// MT: Revolut (primary) + Cash
  /// RW: MoMo (primary) + Cash
  List<Widget> _buildPaymentButtons({
    required ColorScheme cs,
    required bool orderingUnavailable,
    required bool supportsCash,
    required bool supportsRevolut,
  }) {
    final country = CountryRuntime.config.country;
    final methods = country.paymentMethods;
    final widgets = <Widget>[];

    for (var i = 0; i < methods.length; i++) {
      final method = methods[i];
      final isPrimary = i == 0 && method != PaymentMethod.cash;

      bool isEnabled;
      switch (method) {
        case PaymentMethod.revolutLink:
          isEnabled = supportsRevolut;
          break;
        case PaymentMethod.momoUssd:
          isEnabled = true; // MoMo USSD always available (handoff only)
          break;
        case PaymentMethod.cash:
          isEnabled = supportsCash;
          break;
      }

      if (i > 0) widgets.add(const SizedBox(height: AppTheme.space2));

      final icon = switch (method) {
        PaymentMethod.revolutLink => LucideIcons.creditCard,
        PaymentMethod.momoUssd => LucideIcons.smartphone,
        PaymentMethod.cash => LucideIcons.banknote,
      };

      widgets.add(
        SizedBox(
          width: double.infinity,
          child: isPrimary
              ? ElevatedButton.icon(
                  onPressed:
                      _isPlacing || orderingUnavailable || !isEnabled
                      ? null
                      : () => _placeOrder(method),
                  icon: Icon(icon, size: 18),
                  label: Text(
                    method.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                )
              : OutlinedButton.icon(
                  onPressed:
                      _isPlacing || orderingUnavailable || !isEnabled
                      ? null
                      : () => _placeOrder(method),
                  icon: Icon(icon, size: 18),
                  label: Text(
                    method.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
        ),
      );
    }
    return widgets;
  }
}

/// Cart item card — matches React OrderSummary item card.
/// w-24 h-24 image, name, note, price, qty +/-, delete button.
class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final Country country;
  final ValueChanged<int> onUpdateQty;
  final VoidCallback onRemove;

  const _CartItemCard({
    super.key,
    required this.item,
    required this.country,
    required this.onUpdateQty,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 72,
              height: 72,
              child: DineInImage(
                imageUrl: item.imageUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                fallbackIcon: LucideIcons.chefHat,
                semanticLabel: '${item.name} photo',
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space5),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Delete
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: tt.headlineSmall?.copyWith(
                          letterSpacing: -0.5,
                        ), // text-xl font-black
                      ),
                    ),
                    PressableScale(
                      onTap: onRemove,
                      semanticLabel: 'Remove ${item.name}',
                      minTouchTargetSize: const Size(44, 44),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          LucideIcons.trash2,
                          size: 20,
                          color: cs.error.withValues(alpha: 0.60),
                        ),
                      ),
                    ),
                  ],
                ),

                if (item.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                      height: 1.3,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Price + Quantity controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price
                    Text(
                      country.formatPrice(item.price),
                      style: tt.titleLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),

                    // Qty controls — compact
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PressableScale(
                            onTap: () => onUpdateQty(item.quantity - 1),
                            semanticLabel: 'Decrease quantity',
                            minTouchTargetSize: const Size(44, 44),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                LucideIcons.minus,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${item.quantity}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          PressableScale(
                            onTap: () => onUpdateQty(item.quantity + 1),
                            semanticLabel: 'Increase quantity',
                            minTouchTargetSize: const Size(44, 44),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                LucideIcons.plus,
                                size: 18,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
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

/// Compact chip-style action button for the cart checkout bar.
class _CompactActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isError;
  final Color? iconColor;

  const _CompactActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isError = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isError
                ? cs.error
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isError
                  ? cs.error
                  : (iconColor ?? cs.primary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isError ? cs.error : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
