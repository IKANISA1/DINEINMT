import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dinein_app/core/services/notification_inbox_service.dart';

/// Provides a stream of unread notification count.
final notificationUnreadCountProvider = StreamProvider<int>((ref) {
  final service = NotificationInboxService.instance;
  // Emit current value immediately then listen for changes
  return service.unreadCountStream;
});

/// Provides the full list of inbox notifications.
final notificationInboxItemsProvider =
    FutureProvider<List<InboxNotification>>((ref) async {
  // Watch the unread count to trigger rebuilds when items change
  ref.watch(notificationUnreadCountProvider);
  await NotificationInboxService.instance.init();
  return NotificationInboxService.instance.items;
});
