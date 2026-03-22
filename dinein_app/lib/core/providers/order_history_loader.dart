import '../models/models.dart';

typedef FetchOrdersForUser = Future<List<Order>> Function(String userId);
typedef FetchTrackedOrderIds = Future<List<String>> Function();
typedef FetchOrderById = Future<Order?> Function(String orderId);
typedef ClearTrackedOrder = Future<void> Function(String orderId);

Future<List<Order>> loadAccessibleUserOrders({
  required String? userId,
  required FetchOrdersForUser fetchOrdersForUser,
  required FetchTrackedOrderIds fetchTrackedOrderIds,
  required FetchOrderById fetchOrderById,
  required ClearTrackedOrder clearTrackedOrder,
}) async {
  final ordersById = <String, Order>{};

  if (userId != null && userId.trim().isNotEmpty) {
    final userOrders = await fetchOrdersForUser(userId);
    for (final order in userOrders) {
      ordersById[order.id] = order;
    }
  }

  final trackedOrderIds = await fetchTrackedOrderIds();
  if (trackedOrderIds.isNotEmpty) {
    final trackedOrders = await Future.wait(
      trackedOrderIds.map((orderId) async {
        try {
          final order = await fetchOrderById(orderId);
          if (order == null) {
            await clearTrackedOrder(orderId);
          }
          return order;
        } catch (_) {
          await clearTrackedOrder(orderId);
          return null;
        }
      }),
    );

    for (final order in trackedOrders.whereType<Order>()) {
      ordersById[order.id] = order;
    }
  }

  final orders = ordersById.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return orders;
}
