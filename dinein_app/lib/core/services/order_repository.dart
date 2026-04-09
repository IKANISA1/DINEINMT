import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'api_invoker.dart';
import 'auth_repository.dart';
import 'dinein_api_service.dart';
import 'order_receipt_service.dart';

/// Repository for order data access via the DineIn edge API.
class OrderRepository {
  OrderRepository._() : _invoke = DineinApiService.invoke;
  static final instance = OrderRepository._();

  /// Test-only constructor: inject a mock [ApiInvoker].
  OrderRepository.forTesting({required ApiInvoker invoker}) : _invoke = invoker;

  final ApiInvoker _invoke;

  Future<OrderRealtimeAccessToken> issueRealtimeAccess({
    String? orderId,
    String? venueId,
  }) async {
    assert(
      (orderId != null && venueId == null) ||
          (orderId == null && venueId != null),
      'Provide exactly one realtime access scope.',
    );

    final payload = <String, dynamic>{
      ...?orderId == null ? null : {'orderId': orderId},
      ...?venueId == null ? null : {'venueId': venueId},
    };
    if (venueId != null) {
      payload.addAll(await _venueSessionPayload());
    }

    if (orderId != null) {
      final receiptToken = await OrderReceiptService.instance.getReceiptToken(
        orderId,
      );
      if (receiptToken != null && receiptToken.trim().isNotEmpty) {
        payload['receiptToken'] = receiptToken;
      }
    }

    final data = await _invoke('issue_order_realtime_access', payload: payload);
    return OrderRealtimeAccessToken.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _venueSessionPayload() async {
    final session = await AuthRepository.instance.ensureVenueSession();
    if (session == null || session.accessToken.isEmpty) return const {};
    return {
      'venue_session': {'access_token': session.accessToken},
    };
  }

  /// Place a new order.
  Future<Order> placeOrder(Order order) async {
    final data = await _invoke(
      'place_order',
      payload: {'order': order.toJson()},
    );
    final placedOrder = Order.fromJson(data as Map<String, dynamic>);
    final receiptToken = placedOrder.guestReceiptToken;
    if (receiptToken != null && receiptToken.trim().isNotEmpty) {
      await OrderReceiptService.instance.saveReceiptToken(
        placedOrder.id,
        receiptToken,
      );
    }
    return placedOrder;
  }

  /// Fetch orders for a venue (venue owner view).
  ///
  /// Use [limit] and [offset] for pagination. Omit both to fetch all.
  Future<List<Order>> getOrdersForVenue(
    String venueId, {
    int? limit,
    int? offset,
  }) async {
    final data =
        await _invoke(
              'get_orders_for_venue',
              payload: {
                'venueId': venueId,
                ...await _venueSessionPayload(),
                'limit': ?limit,
                'offset': ?offset,
              },
            )
            as List<dynamic>;
    return data.map((e) => Order.fromJson(e)).toList();
  }

  /// Fetch orders for the current user (order history).
  ///
  /// Use [limit] and [offset] for pagination. Omit both to fetch all.
  Future<List<Order>> getOrdersForUser(
    String userId, {
    int? limit,
    int? offset,
  }) async {
    final data =
        await _invoke(
              'get_orders_for_user',
              payload: {'userId': userId, 'limit': ?limit, 'offset': ?offset},
            )
            as List<dynamic>;
    return data.map((e) => Order.fromJson(e)).toList();
  }

  /// Fetch all orders system-wide (admin view).
  ///
  /// Use [limit] and [offset] for pagination. Omit both to fetch all.
  Future<List<Order>> getAllOrders({int? limit, int? offset}) async {
    final data =
        await _invoke(
              'get_all_orders',
              useAdminSession: true,
              payload: {'limit': ?limit, 'offset': ?offset},
            )
            as List<dynamic>;
    return data.map((e) => Order.fromJson(e)).toList();
  }

  /// Fetch a single order by ID.
  Future<Order?> getOrderById(String orderId) async {
    final receiptToken = await OrderReceiptService.instance.getReceiptToken(
      orderId,
    );
    final data = await _invoke(
      'get_order_by_id',
      payload: {
        'orderId': orderId,
        ...?receiptToken == null ? null : {'receiptToken': receiptToken},
      },
    );
    return data != null ? Order.fromJson(data) : null;
  }

  /// Get aggregated KPIs for the Admin Dashboard.
  Future<Map<String, dynamic>> getAdminDashboardKpis({
    required DateTime startOfDay,
    required String timeZone,
  }) async {
    final data = await _invoke(
      'get_admin_dashboard_kpis',
      useAdminSession: true,
      payload: {
        'startOfDay': startOfDay.toUtc().toIso8601String(),
        'timeZone': timeZone,
      },
    );
    return data != null ? Map<String, dynamic>.from(data) : {};
  }

  /// Update order status (venue owner action).
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _invoke(
      'update_order_status',
      payload: {
        'orderId': orderId,
        'status': status.dbValue,
        ...await _venueSessionPayload(),
      },
    );
  }
}

class OrderRealtimeAccessToken {
  final String accessToken;
  final DateTime expiresAt;

  const OrderRealtimeAccessToken({
    required this.accessToken,
    required this.expiresAt,
  });

  factory OrderRealtimeAccessToken.fromJson(Map<String, dynamic> json) {
    return OrderRealtimeAccessToken(
      accessToken:
          json['access_token'] as String? ??
          json['accessToken'] as String? ??
          '',
      expiresAt: DateTime.parse(
        json['expires_at'] as String? ?? json['expiresAt'] as String? ?? '',
      ),
    );
  }
}
