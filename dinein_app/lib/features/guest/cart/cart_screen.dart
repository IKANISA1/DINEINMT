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
import 'package:core_pkg/constants/enums.dart';
import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/services/app_telemetry.dart';
import 'package:dinein_app/core/services/order_repository.dart';
import 'package:dinein_app/core/services/venue_repository.dart';
import 'package:ui/widgets/pressable_scale.dart';

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
      }

      cartNotifier.clear();

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
                  currencySymbol: cart.currencySymbol,
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

              // ─── Table Number Card ───
              Container(
                    key: _tableCardKey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _tableError
                            ? cs.error
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.hash,
                          size: 24,
                          color: _tableError ? cs.error : cs.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _tableController,
                            focusNode: _tableFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.done,
                            onChanged: (v) {
                              if (v.trim().isNotEmpty && _tableError) {
                                setState(() => _tableError = false);
                              }
                            },
                            onSubmitted: (_) {
                              _syncTableNumber();
                              FocusScope.of(context).unfocus();
                            },
                            style: tt.headlineSmall, // text-xl font-black
                            decoration: InputDecoration(
                              hintText: 'Table Number (Required)',
                              hintStyle: tt.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.30,
                                ),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
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

              const SizedBox(height: AppTheme.space8),

              // ─── Special Requests Card ───
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: Icon(
                      LucideIcons.messageSquare,
                      size: 24,
                      color: AppColors.secondary,
                    ),
                    title: Text(
                      'Special Requests',
                      style: tt.headlineSmall?.copyWith(fontSize: 18),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: TextField(
                          controller: _requestsController,
                          focusNode: _requestsFocusNode,
                          maxLines: 3,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Any allergies or preferences?\n(e.g. No onions, extra spicy)',
                            hintStyle: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.30,
                              ),
                            ),
                            filled: true,
                            fillColor: cs.surfaceContainerHigh,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.space8),

              // ─── Add More Items CTA ───
              PressableScale(
                onTap: () {
                  _syncDraftFields(clearError: false);
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignCenter,
                    ),
                    color: Colors.white.withValues(alpha: 0.02),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.plus,
                        size: 24,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Add more items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
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
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(48),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.40),
                      blurRadius: 60,
                      offset: const Offset(0, 30),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Total row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: tt.headlineSmall,
                        ), // text-xl font-black
                        Text(
                          '${cart.currencySymbol}${finalTotal.toStringAsFixed(2)}',
                          style: tt.displaySmall?.copyWith(
                            color: cs.primary,
                            letterSpacing: -2,
                          ), // text-4xl primary
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space8),

                    // Revolut button (primary)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isPlacing ||
                                orderingUnavailable ||
                                !supportsRevolut
                            ? null
                            : () => _placeOrder(PaymentMethod.revolutLink),
                        icon: Icon(LucideIcons.creditCard, size: 24),
                        label: Text(
                          'Pay with Revolut',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),

                    // Cash button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isPlacing || orderingUnavailable || !supportsCash
                            ? null
                            : () => _placeOrder(PaymentMethod.cash),
                        icon: Icon(LucideIcons.banknote, size: 24),
                        label: Text(
                          'Pay Cash',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.onSurface,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
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
}

/// Cart item card — matches React OrderSummary item card.
/// w-24 h-24 image, name, note, price, qty +/-, delete button.
class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final String currencySymbol;
  final ValueChanged<int> onUpdateQty;
  final VoidCallback onRemove;

  const _CartItemCard({
    super.key,
    required this.item,
    required this.currencySymbol,
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
          // Image placeholder
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Icon(
                LucideIcons.chefHat,
                size: 32,
                color: cs.onSurfaceVariant.withValues(alpha: 0.30),
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

                // Note (if any)
                if (item.name.isNotEmpty) ...[
                  // placeholder for note
                ],

                const SizedBox(height: 8),

                // Price + Quantity controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price
                    Text(
                      '$currencySymbol${item.price.toStringAsFixed(2)}',
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
