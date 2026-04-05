import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import '../../core/services/notification_inbox_service.dart';
import '../../core/providers/notification_inbox_provider.dart';

/// Bottom sheet displaying the notification inbox.
///
/// Shows all recent notifications with unread indicators, timestamps,
/// and supports tap-to-navigate and mark-all-read actions.
class NotificationInboxSheet extends ConsumerWidget {
  const NotificationInboxSheet({super.key});

  /// Show the inbox sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.3,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXxl),
          ),
          child: _SheetBody(scrollController: scrollController),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}

class _SheetBody extends ConsumerWidget {
  final ScrollController scrollController;

  const _SheetBody({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final inbox = NotificationInboxService.instance;
    final itemsAsync = ref.watch(notificationInboxItemsProvider);

    return Container(
      color: cs.surface,
      child: Column(
        children: [
          // ─── Handle ───
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ─── Header ───
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space6,
              vertical: AppTheme.space3,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.inbox, size: 18, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'RECENT UPDATES',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (inbox.unreadCount > 0)
                  PressableScale(
                    onTap: () async {
                      await inbox.markAllRead();
                      ref.invalidate(notificationInboxItemsProvider);
                    },
                    semanticLabel: 'Mark all notifications as read',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        'MARK ALL READ',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.1),
          ),

          // ─── List ───
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(
                child: SkeletonLoader(width: double.infinity, height: 80),
              ),
              error: (_, _) => ErrorState(
                message: 'Could not load notifications.',
                onRetry: () =>
                    ref.invalidate(notificationInboxItemsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: LucideIcons.bellOff,
                    title: "You're all caught up",
                    subtitle: 'No notifications yet.',
                  );
                }

                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space4,
                    vertical: AppTheme.space3,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.space2),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotificationRow(
                      item: item,
                      onTap: () async {
                        await inbox.markRead(item.id);
                        ref.invalidate(notificationInboxItemsProvider);
                        if (context.mounted && item.url != null) {
                          Navigator.of(context).pop();
                          context.go(item.url!);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final InboxNotification item;
  final VoidCallback onTap;

  const _NotificationRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final icon = _iconForType(item.type);
    final iconColor = _colorForType(item.type, cs);

    return PressableScale(
      onTap: onTap,
      semanticLabel: '${item.read ? "" : "Unread: "}${item.title}',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.read
              ? cs.surfaceContainerLow
              : cs.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: item.read
                ? Colors.white.withValues(alpha: 0.04)
                : cs.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(item.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),

            // Unread dot
            if (!item.read)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'order' => LucideIcons.shoppingBag,
      'bell' => LucideIcons.bellRing,
      'sync' => LucideIcons.refreshCw,
      'promo' => LucideIcons.gift,
      _ => LucideIcons.bell,
    };
  }

  Color _colorForType(String type, ColorScheme cs) {
    return switch (type) {
      'order' => const Color(0xFF1D9E75),
      'bell' => const Color(0xFFBA7517),
      'sync' => const Color(0xFF185FA5),
      'promo' => cs.primary,
      _ => cs.onSurfaceVariant,
    };
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
