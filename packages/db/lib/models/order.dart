part of 'models.dart';

/// A single item in a cart or order.
class OrderItem extends Equatable {
  final String menuItemId;
  final String name;
  final String description;
  final String? imageUrl;
  final double price;
  final int quantity;
  final String? note;

  const OrderItem({
    required this.menuItemId,
    required this.name,
    this.description = '',
    this.imageUrl,
    required this.price,
    required this.quantity,
    this.note,
  });

  double get subtotal => price * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      menuItemId: json['menu_item_id'] as String,
      name: json['name'] as String,
      description:
          json['description'] as String? ??
          json['menu_item_description'] as String? ??
          '',
      imageUrl:
          json['image_url'] as String? ??
          json['imageUrl'] as String? ??
          json['menu_item_image_url'] as String?,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      note: json['note'] as String?,
    );
  }

  OrderItem copyWith({
    String? menuItemId,
    String? name,
    String? description,
    String? imageUrl,
    double? price,
    int? quantity,
    String? note,
  }) {
    return OrderItem(
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    'menu_item_id': menuItemId,
    'name': name,
    'description': description,
    'image_url': imageUrl,
    'price': price,
    'quantity': quantity,
    'note': note,
  };

  @override
  List<Object?> get props => [
    menuItemId,
    name,
    description,
    imageUrl,
    price,
    quantity,
    note,
  ];
}

/// A placed order.
class Order extends Equatable {
  final String id;
  final String? orderNumber;
  final Country country;
  final String venueId;
  final String venueName;
  final String? venueImageUrl;
  final String? userId;
  final String? userName;
  final List<OrderItem> items;
  final double? subtotalAmount;
  final double? serviceFeeAmount;
  final double total;
  final OrderStatus status;
  final DateTime createdAt;
  final PaymentMethod paymentMethod;
  final String? tableNumber;
  final String? specialRequests;
  final String? guestReceiptToken;

  const Order({
    required this.id,
    this.orderNumber,
    this.country = Country.mt,
    required this.venueId,
    required this.venueName,
    this.venueImageUrl,
    this.userId,
    this.userName,
    required this.items,
    this.subtotalAmount,
    this.serviceFeeAmount,
    required this.total,
    this.status = OrderStatus.placed,
    required this.createdAt,
    this.paymentMethod = PaymentMethod.cash,
    this.tableNumber,
    this.specialRequests,
    this.guestReceiptToken,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      orderNumber:
          json['order_number'] as String? ?? json['orderNumber'] as String?,
      country: Country.fromCode(
        json['country'] as String? ?? json['venue_country'] as String? ?? 'MT',
      ),
      venueId: json['venue_id'] as String,
      venueName: json['venue_name'] as String,
      venueImageUrl: json['venue_image_url'] as String?,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String?,
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotalAmount: (json['subtotal'] as num?)?.toDouble(),
      serviceFeeAmount: (json['service_fee'] as num?)?.toDouble(),
      total: (json['total'] as num).toDouble(),
      status: OrderStatus.fromString(json['status'] as String? ?? 'placed'),
      createdAt: DateTime.parse(json['created_at'] as String),
      paymentMethod: PaymentMethod.fromString(
        json['payment_method'] as String? ?? 'cash',
      ),
      tableNumber: json['table_number'] as String?,
      specialRequests: json['special_requests'] as String?,
      guestReceiptToken:
          json['receipt_token'] as String? ??
          json['guest_receipt_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'country': country.code,
    'venue_id': venueId,
    'venue_name': venueName,
    'venue_image_url': venueImageUrl,
    'user_id': userId,
    'user_name': userName,
    'items': items.map((e) => e.toJson()).toList(),
    'subtotal': subtotal,
    'service_fee': serviceFee,
    'total': total,
    'status': status.dbValue,
    'payment_method': paymentMethod.dbValue,
    'table_number': tableNumber,
    'special_requests': specialRequests,
  };

  String get displayNumber {
    final explicit = orderNumber?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return '';
    if (normalizedId.length <= 8) return normalizedId.toUpperCase();
    return normalizedId.substring(0, 8).toUpperCase();
  }

  double get subtotal =>
      subtotalAmount ?? items.fold(0.0, (sum, item) => sum + item.subtotal);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get serviceFee {
    if (serviceFeeAmount != null) return serviceFeeAmount!;
    final derived = total - subtotal;
    return derived > 0 ? derived : 0;
  }

  /// Currency symbol derived from the order venue country.
  String get currencySymbol => country.currencySymbol;

  @override
  List<Object?> get props => [
    id,
    orderNumber,
    country,
    venueId,
    venueImageUrl,
    total,
    status,
    createdAt,
    specialRequests,
  ];
}
