import 'package:core_pkg/constants/enums.dart';
import 'package:dinein_app/core/providers/order_status_polling.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pollOrderStatus emits only changes and stops on terminal status',
    () async {
      final fetchedStatuses = <OrderStatus>[
        OrderStatus.placed,
        OrderStatus.placed,
        OrderStatus.received,
        OrderStatus.received,
        OrderStatus.served,
        OrderStatus.served,
      ];

      var fetchCount = 0;
      final emitted = await pollOrderStatus(
        pollInterval: const Duration(milliseconds: 1),
        fetchStatus: () async {
          final index = fetchCount < fetchedStatuses.length
              ? fetchCount
              : fetchedStatuses.length - 1;
          fetchCount += 1;
          return fetchedStatuses[index];
        },
      ).toList();

      expect(emitted, [
        OrderStatus.placed,
        OrderStatus.received,
        OrderStatus.served,
      ]);
      expect(fetchCount, 5);
    },
  );

  test(
    'pollOrderStatus throws when the order cannot be fetched initially',
    () async {
      expect(
        () => pollOrderStatus(
          pollInterval: const Duration(milliseconds: 1),
          fetchStatus: () async => null,
        ).drain<void>(),
        throwsException,
      );
    },
  );
}
