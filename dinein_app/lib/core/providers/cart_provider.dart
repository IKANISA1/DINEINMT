import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:db_pkg/models/models.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:dinein_app/core/services/cart_persistence_service.dart';
import 'package:dinein_app/core/services/pwa_install_service.dart';

const _cartItemNoChange = Object();

String? _normalizeCartNote(String? note) {
  final normalized = note?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _cartLineId(String menuItemId, String? note) {
  final normalizedNote = _normalizeCartNote(note);
  if (normalizedNote == null) return menuItemId;
  return '$menuItemId::$normalizedNote';
}

String _menuItemIdFromCartKey(String itemKey) {
  final separatorIndex = itemKey.indexOf('::');
  if (separatorIndex < 0) return itemKey;
  return itemKey.substring(0, separatorIndex);
}

/// Represents one item in the cart.
class CartItem {
  final String menuItemId;
  final String name;
  final String description;
  final String? imageUrl;
  final double price;
  final int quantity;
  final String? note;

  const CartItem({
    required this.menuItemId,
    required this.name,
    this.description = '',
    this.imageUrl,
    required this.price,
    this.quantity = 1,
    this.note,
  });

  double get subtotal => price * quantity;
  String get lineId => _cartLineId(menuItemId, note);

  CartItem copyWith({
    String? name,
    String? description,
    String? imageUrl,
    double? price,
    int? quantity,
    Object? note = _cartItemNoChange,
  }) => CartItem(
    menuItemId: menuItemId,
    name: name ?? this.name,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    price: price ?? this.price,
    quantity: quantity ?? this.quantity,
    note: identical(note, _cartItemNoChange) ? this.note : note as String?,
  );

  /// Convert to [OrderItem] for order placement.
  OrderItem toOrderItem() => OrderItem(
    menuItemId: menuItemId,
    name: name,
    description: description,
    imageUrl: imageUrl,
    price: price,
    quantity: quantity,
    note: note,
  );
}

/// Cart state: items + venue context.
class CartState {
  final String? venueId;
  final String? venueSlug;
  final String? venueName;
  final String? venueRevolutUrl;
  final Country? venueCountry;
  final List<CartItem> items;
  final String? tableNumber;
  final String? specialRequests;

  /// Service fee rate (0.0 – 1.0). Defaults to 5% (0.05).
  /// Can be overridden per venue via venue config.
  final double serviceFeeRate;

  const CartState({
    this.venueId,
    this.venueSlug,
    this.venueName,
    this.venueRevolutUrl,
    this.venueCountry,
    this.items = const [],
    this.tableNumber,
    this.specialRequests,
    this.serviceFeeRate = 0.05,
  });

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);
  double get serviceFee => subtotal * serviceFeeRate;
  double get total => subtotal + serviceFee;
  bool get isEmpty => items.isEmpty;

  /// Currency symbol for the venue's country (defaults to the active app country).
  String get currencySymbol =>
      venueCountry?.currencySymbol ??
      CountryRuntime.config.country.currencySymbol;

  /// The effective country for this cart (venue country or app default).
  Country get effectiveCountry =>
      venueCountry ?? CountryRuntime.config.country;

  /// Format an amount with the correct currency symbol and locale rules.
  String formatPrice(double amount) => effectiveCountry.formatPrice(amount);

  /// Payment methods available for the venue's country.
  List<PaymentMethod> get paymentMethods =>
      venueCountry?.paymentMethods ??
      CountryRuntime.config.country.paymentMethods;

  CartState copyWith({
    String? venueId,
    String? venueSlug,
    String? venueName,
    String? venueRevolutUrl,
    Country? venueCountry,
    List<CartItem>? items,
    String? tableNumber,
    String? specialRequests,
    double? serviceFeeRate,
  }) => CartState(
    venueId: venueId ?? this.venueId,
    venueSlug: venueSlug ?? this.venueSlug,
    venueName: venueName ?? this.venueName,
    venueRevolutUrl: venueRevolutUrl ?? this.venueRevolutUrl,
    venueCountry: venueCountry ?? this.venueCountry,
    items: items ?? this.items,
    tableNumber: tableNumber ?? this.tableNumber,
    specialRequests: specialRequests ?? this.specialRequests,
    serviceFeeRate: serviceFeeRate ?? this.serviceFeeRate,
  );
}

/// Cart provider using Riverpod Notifier.
class CartNotifier extends Notifier<CartState> {
  bool _restoredFromStorage = false;

  @override
  CartState build() {
    // Restore persisted cart on first build (async, fire-and-forget).
    // The initial state is empty; once storage resolves, state updates.
    if (!_restoredFromStorage) {
      _restoredFromStorage = true;
      _restoreCart();
    }
    return const CartState();
  }

  Future<void> _restoreCart() async {
    final restored = await CartPersistenceService.restore();
    if (restored != null && restored.items.isNotEmpty) {
      state = restored;
      PwaInstallService.updateCartBadgeCount(state.itemCount);
    }
  }

  /// Persist the current state to localStorage.
  void _persist() {
    CartPersistenceService.save(state);
  }

  /// Set the venue context (called when entering a menu screen).
  void setVenue({
    required String venueId,
    required String venueSlug,
    required String venueName,
    String? venueRevolutUrl,
    Country? venueCountry,
    String? tableNumber,
  }) {
    // If switching venues, clear the cart
    if (state.venueId != null && state.venueId != venueId) {
      state = CartState(
        venueId: venueId,
        venueSlug: venueSlug,
        venueName: venueName,
        venueRevolutUrl: venueRevolutUrl,
        venueCountry: venueCountry,
        tableNumber: tableNumber,
      );
    } else {
      state = state.copyWith(
        venueId: venueId,
        venueSlug: venueSlug,
        venueName: venueName,
        venueRevolutUrl: venueRevolutUrl,
        venueCountry: venueCountry,
        tableNumber: tableNumber,
      );
    }
    _persist();
  }

  void setTableNumber(String? tableNumber) {
    final normalized = tableNumber?.trim();
    state = state.copyWith(
      tableNumber: normalized == null || normalized.isEmpty ? null : normalized,
    );
    _persist();
  }

  void setSpecialRequests(String? specialRequests) {
    final normalized = specialRequests?.trim();
    state = state.copyWith(
      specialRequests: normalized == null || normalized.isEmpty
          ? null
          : normalized,
    );
    _persist();
  }

  int _indexForLine(String itemKey) {
    final lineMatch = state.items.indexWhere((item) => item.lineId == itemKey);
    if (lineMatch >= 0) return lineMatch;
    return state.items.indexWhere((item) => item.menuItemId == itemKey);
  }

  /// Add a menu item to the cart or increase the quantity of the same
  /// note-specific line item.
  void addItem(
    MenuItem item, {
    String? note,
    int quantity = 1,
  }) {
    final normalizedNote = _normalizeCartNote(note);
    final safeQuantity = quantity < 1 ? 1 : quantity;
    final existing = state.items.indexWhere(
      (cartItem) => cartItem.lineId == _cartLineId(item.id, normalizedNote),
    );
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity + safeQuantity,
      );
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            menuItemId: item.id,
            name: item.name,
            description: item.description,
            imageUrl: item.imageUrl,
            price: item.price,
            quantity: safeQuantity,
            note: normalizedNote,
          ),
        ],
      );
    }

    // G-21: Trigger PWA install prompt when 2+ items are in cart
    if (state.items.length >= 2) {
      PwaInstallService.triggerIfEligible(reason: 'cart_2_items');
    }
    PwaInstallService.updateCartBadgeCount(state.itemCount);
    _persist();
  }

  /// Remove one unit of an item (if qty reaches 0, remove entirely).
  void removeItem(String itemKey) {
    final existing = _indexForLine(itemKey);
    if (existing < 0) return;

    final updated = List<CartItem>.from(state.items);
    final current = updated[existing];
    if (current.quantity <= 1) {
      updated.removeAt(existing);
    } else {
      updated[existing] = current.copyWith(quantity: current.quantity - 1);
    }
    state = state.copyWith(items: updated);
    PwaInstallService.updateCartBadgeCount(state.itemCount);
    _persist();
  }

  /// Set the quantity of an item directly (used by item detail sheet).
  void setQuantity(
    String itemKey,
    int quantity, {
    String? name,
    String? description,
    String? imageUrl,
    double? price,
    String? note,
  }) {
    if (quantity <= 0) {
      final existing = _indexForLine(itemKey);
      if (existing < 0) return;
      final updated = List<CartItem>.from(state.items)..removeAt(existing);
      state = state.copyWith(items: updated);
      PwaInstallService.updateCartBadgeCount(state.itemCount);
      _persist();
      return;
    }

    final existing = _indexForLine(itemKey);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(quantity: quantity);
      state = state.copyWith(items: updated);
    } else if (name != null && price != null) {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            menuItemId: _menuItemIdFromCartKey(itemKey),
            name: name,
            description: description ?? '',
            imageUrl: imageUrl,
            price: price,
            quantity: quantity,
            note: _normalizeCartNote(note),
          ),
        ],
      );
    }
    PwaInstallService.updateCartBadgeCount(state.itemCount);
    _persist();
  }

  /// Get quantity for a specific item.
  int quantityOf(String menuItemId) {
    return state.items
        .where((item) => item.menuItemId == menuItemId)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  /// Build an Order object for placement.
  Order buildOrder({required PaymentMethod paymentMethod, String? userId}) {
    return Order(
      id: '', // Will be assigned by Supabase
      venueId: state.venueId ?? '',
      venueName: state.venueName ?? '',
      userId: userId,
      items: state.items.map((i) => i.toOrderItem()).toList(),
      subtotalAmount: state.subtotal,
      serviceFeeAmount: state.serviceFee,
      total: state.total,
      status: OrderStatus.placed,
      createdAt: DateTime.now(),
      paymentMethod: paymentMethod,
      tableNumber: state.tableNumber,
      specialRequests: state.specialRequests,
    );
  }

  /// Clear the cart after order placement.
  void clear() {
    state = const CartState();
    PwaInstallService.updateCartBadgeCount(0);
    CartPersistenceService.clear();
  }
}

/// The cart provider.
final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);
