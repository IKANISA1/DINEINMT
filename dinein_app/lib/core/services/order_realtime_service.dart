import 'dart:async';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'order_repository.dart';
import 'supabase_config.dart';

class OrderRealtimeService {
  OrderRealtimeService({OrderRepository? repository})
    : _repository = repository ?? OrderRepository.instance;

  static final instance = OrderRealtimeService();

  final OrderRepository _repository;

  Stream<List<Order>> watchVenueOrders(
    String venueId, {
    Duration pollInterval = const Duration(seconds: 4),
  }) {
    late final StreamController<List<Order>> controller;
    SupabaseClient? realtimeClient;
    RealtimeChannel? channel;
    Timer? pollingTimer;
    Timer? refreshTimer;
    String? currentToken;
    var lastGood = <Order>[];
    var disposed = false;
    var fetchInFlight = false;

    Future<void> emitOrders() async {
      if (disposed || fetchInFlight) return;
      fetchInFlight = true;
      try {
        final orders = await _repository.getOrdersForVenue(venueId);
        lastGood = orders;
        if (!controller.isClosed) {
          controller.add(orders);
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          if (lastGood.isNotEmpty) {
            controller.add(lastGood);
          } else {
            controller.addError(error, stackTrace);
          }
        }
      } finally {
        fetchInFlight = false;
      }
    }

    void startPolling() {
      if (disposed || pollingTimer != null) return;
      pollingTimer = Timer.periodic(pollInterval, (_) {
        unawaited(emitOrders());
      });
    }

    void scheduleRefresh(
      OrderRealtimeAccessToken access,
      Future<OrderRealtimeAccessToken> Function() refreshAccess,
    ) {
      if (access.accessToken.isEmpty) {
        startPolling();
        return;
      }
      refreshTimer?.cancel();
      final refreshAt =
          access.expiresAt.difference(DateTime.now()) -
          const Duration(minutes: 2);
      final delay = refreshAt.isNegative
          ? const Duration(minutes: 1)
          : refreshAt;
      refreshTimer = Timer(delay, () async {
        if (disposed || realtimeClient == null) return;
        try {
          final refreshed = await refreshAccess();
          if (refreshed.accessToken.isEmpty) {
            startPolling();
            return;
          }
          currentToken = refreshed.accessToken;
          await realtimeClient!.realtime.setAuth(currentToken);
          realtimeClient!.rest.setAuth(currentToken);
          scheduleRefresh(refreshed, refreshAccess);
        } catch (_) {
          startPolling();
        }
      });
    }

    Future<void> configureRealtime() async {
      final access = await _repository.issueRealtimeAccess(venueId: venueId);
      if (disposed) return;
      if (access.accessToken.isEmpty) {
        startPolling();
        return;
      }

      currentToken = access.accessToken;
      realtimeClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.anonKey,
        accessToken: () async => currentToken,
      );
      await realtimeClient!.realtime.setAuth(currentToken);
      realtimeClient!.rest.setAuth(currentToken);
      scheduleRefresh(
        access,
        () => _repository.issueRealtimeAccess(venueId: venueId),
      );

      channel = realtimeClient!
          .channel('dinein-orders-venue-$venueId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'dinein_orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'venue_id',
              value: venueId,
            ),
            callback: (_) {
              unawaited(emitOrders());
            },
          )
          .subscribe((status, _) {
            if (disposed) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              return;
            }
            startPolling();
          });
    }

    Future<void> disposeResources() async {
      if (disposed) return;
      disposed = true;
      refreshTimer?.cancel();
      pollingTimer?.cancel();
      final activeChannel = channel;
      final activeClient = realtimeClient;
      channel = null;
      realtimeClient = null;
      if (activeChannel != null && activeClient != null) {
        await activeClient.removeChannel(activeChannel);
      }
      activeClient?.realtime.disconnect();
    }

    controller = StreamController<List<Order>>(
      onListen: () {
        unawaited(() async {
          await emitOrders();
          try {
            await configureRealtime();
          } catch (_) {
            startPolling();
          }
        }());
      },
      onCancel: disposeResources,
    );

    return controller.stream;
  }

  Stream<OrderStatus> watchOrderStatus(
    String orderId, {
    Duration pollInterval = const Duration(seconds: 4),
  }) {
    late final StreamController<OrderStatus> controller;
    SupabaseClient? realtimeClient;
    RealtimeChannel? channel;
    Timer? pollingTimer;
    Timer? refreshTimer;
    String? currentToken;
    OrderStatus? lastStatus;
    var disposed = false;
    var fetchInFlight = false;

    Future<void> closeStream() async {
      if (disposed) return;
      disposed = true;
      refreshTimer?.cancel();
      pollingTimer?.cancel();
      final activeChannel = channel;
      final activeClient = realtimeClient;
      channel = null;
      realtimeClient = null;
      if (activeChannel != null && activeClient != null) {
        await activeClient.removeChannel(activeChannel);
      }
      activeClient?.realtime.disconnect();
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    Future<void> emitStatus({bool force = false}) async {
      if (disposed || fetchInFlight) return;
      fetchInFlight = true;
      try {
        final order = await _repository.getOrderById(orderId);
        if (order == null) {
          if (!controller.isClosed) {
            controller.addError(Exception('Order not found'));
          }
          await closeStream();
          return;
        }

        if (force || order.status != lastStatus) {
          lastStatus = order.status;
          if (!controller.isClosed) {
            controller.add(order.status);
          }
        }

        if (order.status.isTerminal) {
          await closeStream();
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        fetchInFlight = false;
      }
    }

    void startPolling() {
      if (disposed ||
          pollingTimer != null ||
          (lastStatus?.isTerminal ?? false)) {
        return;
      }
      pollingTimer = Timer.periodic(pollInterval, (_) {
        unawaited(emitStatus());
      });
    }

    void scheduleRefresh(
      OrderRealtimeAccessToken access,
      Future<OrderRealtimeAccessToken> Function() refreshAccess,
    ) {
      if (access.accessToken.isEmpty) {
        startPolling();
        return;
      }
      refreshTimer?.cancel();
      final refreshAt =
          access.expiresAt.difference(DateTime.now()) -
          const Duration(minutes: 2);
      final delay = refreshAt.isNegative
          ? const Duration(minutes: 1)
          : refreshAt;
      refreshTimer = Timer(delay, () async {
        if (disposed || realtimeClient == null) return;
        try {
          final refreshed = await refreshAccess();
          if (refreshed.accessToken.isEmpty) {
            startPolling();
            return;
          }
          currentToken = refreshed.accessToken;
          await realtimeClient!.realtime.setAuth(currentToken);
          realtimeClient!.rest.setAuth(currentToken);
          scheduleRefresh(refreshed, refreshAccess);
        } catch (_) {
          startPolling();
        }
      });
    }

    Future<void> configureRealtime() async {
      final access = await _repository.issueRealtimeAccess(orderId: orderId);
      if (disposed) return;
      if (access.accessToken.isEmpty) {
        startPolling();
        return;
      }

      currentToken = access.accessToken;
      realtimeClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.anonKey,
        accessToken: () async => currentToken,
      );
      await realtimeClient!.realtime.setAuth(currentToken);
      realtimeClient!.rest.setAuth(currentToken);
      scheduleRefresh(
        access,
        () => _repository.issueRealtimeAccess(orderId: orderId),
      );

      channel = realtimeClient!
          .channel('dinein-order-$orderId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'dinein_orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: orderId,
            ),
            callback: (_) {
              unawaited(emitStatus());
            },
          )
          .subscribe((status, _) {
            if (disposed) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              return;
            }
            startPolling();
          });
    }

    controller = StreamController<OrderStatus>(
      onListen: () {
        unawaited(() async {
          await emitStatus(force: true);
          if (disposed || (lastStatus?.isTerminal ?? false)) {
            return;
          }
          try {
            await configureRealtime();
          } catch (_) {
            startPolling();
          }
        }());
      },
      onCancel: closeStream,
    );

    return controller.stream;
  }
}
