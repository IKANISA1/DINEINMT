import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinein_app/core/services/notification_inbox_service.dart';

/// Provides a stream of unread notification count.
final notificationUnreadCountProvider = StreamProvider<int>((ref) async* {
  final service = NotificationInboxService.instance;
  await service.init();
  yield service.unreadCount;
  yield* service.unreadCountStream;
});

/// Provides the full list of inbox notifications.
final notificationInboxItemsProvider = FutureProvider<List<InboxNotification>>((
  ref,
) async {
  // Watch the unread count to trigger rebuilds when items change
  ref.watch(notificationUnreadCountProvider);
  await NotificationInboxService.instance.init();
  return NotificationInboxService.instance.items;
});
