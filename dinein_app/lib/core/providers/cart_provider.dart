import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../constants/enums.dart';

/// Represents one item in the cart.
class CartItem {
  final String menuItemId;
  final String name;
  final double price;
  final int quantity;

  const CartItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  double get subtotal => price * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
    menuItemId: menuItemId,
    name: name,
    price: price,
    quantity: quantity ?? this.quantity,
  );

  /// Convert to [OrderItem] for order placement.
  OrderItem toOrderItem() => OrderItem(
    menuItemId: menuItemId,
    name: name,
    price: price,
    quantity: quantity,
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

  /// Currency symbol for the venue's country (defaults to €).
  String get currencySymbol => venueCountry?.currencySymbol ?? '€';

  /// Payment methods available for the venue's country.
  List<PaymentMethod> get paymentMethods =>
      venueCountry?.paymentMethods ?? Country.mt.paymentMethods;

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
  @override
  CartState build() => const CartState();

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
  }

  void setTableNumber(String? tableNumber) {
    final normalized = tableNumber?.trim();
    state = state.copyWith(
      tableNumber: normalized == null || normalized.isEmpty ? null : normalized,
    );
  }

  void setSpecialRequests(String? specialRequests) {
    final normalized = specialRequests?.trim();
    state = state.copyWith(
      specialRequests: normalized == null || normalized.isEmpty
          ? null
          : normalized,
    );
  }

  /// Add a menu item to the cart (or increase quantity by 1).
  void addItem(MenuItem item) {
    final existing = state.items.indexWhere((i) => i.menuItemId == item.id);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity + 1,
      );
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(menuItemId: item.id, name: item.name, price: item.price),
        ],
      );
    }
  }

  /// Remove one unit of an item (if qty reaches 0, remove entirely).
  void removeItem(String menuItemId) {
    final existing = state.items.indexWhere((i) => i.menuItemId == menuItemId);
    if (existing < 0) return;

    final updated = List<CartItem>.from(state.items);
    final current = updated[existing];
    if (current.quantity <= 1) {
      updated.removeAt(existing);
    } else {
      updated[existing] = current.copyWith(quantity: current.quantity - 1);
    }
    state = state.copyWith(items: updated);
  }

  /// Set the quantity of an item directly (used by item detail sheet).
  void setQuantity(
    String menuItemId,
    int quantity, {
    String? name,
    double? price,
  }) {
    if (quantity <= 0) {
      final updated = state.items
          .where((i) => i.menuItemId != menuItemId)
          .toList();
      state = state.copyWith(items: updated);
      return;
    }

    final existing = state.items.indexWhere((i) => i.menuItemId == menuItemId);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(quantity: quantity);
      state = state.copyWith(items: updated);
    } else if (name != null && price != null) {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            menuItemId: menuItemId,
            name: name,
            price: price,
            quantity: quantity,
          ),
        ],
      );
    }
  }

  /// Get quantity for a specific item.
  int quantityOf(String menuItemId) {
    final item = state.items
        .where((i) => i.menuItemId == menuItemId)
        .firstOrNull;
    return item?.quantity ?? 0;
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
  }
}

/// The cart provider.
final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);
