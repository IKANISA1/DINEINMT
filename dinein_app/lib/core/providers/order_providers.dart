import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import '../services/order_repository.dart';
import '../services/order_realtime_service.dart';
import '../services/order_receipt_service.dart';
import 'auth_providers.dart';
import 'order_history_loader.dart';

/// Orders for the current user (order history).
final userOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final user = ref.watch(currentUserProvider);
  return await loadAccessibleUserOrders(
    userId: user?.id,
    fetchOrdersForUser: OrderRepository.instance.getOrdersForUser,
    fetchTrackedOrderIds: OrderReceiptService.instance.getTrackedOrderIds,
    fetchOrderById: OrderRepository.instance.getOrderById,
    clearTrackedOrder: OrderReceiptService.instance.clearReceiptToken,
  );
});

/// Orders for a venue (venue owner view) — Supabase Realtime stream.
final venueOrdersProvider = StreamProvider.family<List<Order>, String>((
  ref,
  venueId,
) async* {
  yield* OrderRealtimeService.instance.watchVenueOrders(venueId);
});

/// Single order by ID.
final orderByIdProvider = FutureProvider.family<Order?, String>((
  ref,
  orderId,
) async {
  return await OrderRepository.instance.getOrderById(orderId);
});

/// All orders system-wide (admin view).
final allOrdersProvider = FutureProvider<List<Order>>((ref) async {
  return await OrderRepository.instance.getAllOrders();
});

/// System-wide order KPIs for the Admin Dashboard.
final adminDashboardKpisProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final timeZone = DateTime.now().timeZoneName;
  return await OrderRepository.instance.getAdminDashboardKpis(
    startOfDay: startOfDay,
    timeZone: timeZone,
  );
});

/// Realtime order status stream for customer order tracking.
final orderStreamProvider = StreamProvider.family<OrderStatus, String>((
  ref,
  orderId,
) async* {
  yield* OrderRealtimeService.instance.watchOrderStatus(orderId);
});
