import 'package:core_pkg/constants/enums.dart';

typedef FetchOrderStatus = Future<OrderStatus?> Function();

Stream<OrderStatus> pollOrderStatus({
  required FetchOrderStatus fetchStatus,
  required Duration pollInterval,
}) async* {
  final initialStatus = await fetchStatus();
  if (initialStatus == null) {
    throw Exception('Order not found');
  }

  var lastStatus = initialStatus;
  yield lastStatus;

  while (!lastStatus.isTerminal) {
    await Future<void>.delayed(pollInterval);

    final nextStatus = await fetchStatus();
    if (nextStatus == null) {
      throw Exception('Order not found');
    }
    if (nextStatus == lastStatus) {
      continue;
    }

    lastStatus = nextStatus;
    yield lastStatus;
  }
}
