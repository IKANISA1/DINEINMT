import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/enums.dart';
import '../models/models.dart';
import '../services/order_repository.dart';
import 'auth_providers.dart';

const _orderPollInterval = Duration(seconds: 4);

/// Orders for the current user (order history).
final userOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return await OrderRepository.instance.getOrdersForUser(user.id);
});

/// Orders for a venue (venue owner view) — Supabase Realtime stream.
final venueOrdersProvider = StreamProvider.family<List<Order>, String>((
  ref,
  venueId,
) async* {
  yield await OrderRepository.instance.getOrdersForVenue(venueId);
  yield* Stream<List<Order>>.periodic(
    _orderPollInterval,
  ).asyncMap((_) => OrderRepository.instance.getOrdersForVenue(venueId));
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

/// Realtime order status stream for customer order tracking.
final orderStreamProvider = StreamProvider.family<OrderStatus, String>((
  ref,
  orderId,
) async* {
  final order = await OrderRepository.instance.getOrderById(orderId);
  if (order == null) {
    throw Exception('Order not found');
  }
  yield order.status;
  yield* Stream<OrderStatus>.periodic(_orderPollInterval).asyncMap((_) async {
    final refreshed = await OrderRepository.instance.getOrderById(orderId);
    if (refreshed == null) throw Exception('Order not found');
    return refreshed.status;
  });
});
