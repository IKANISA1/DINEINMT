import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ui/widgets/shared_widgets.dart';
import '../../core/providers/notification_inbox_provider.dart';
import 'notification_inbox_sheet.dart';

/// Bell icon button with animated unread badge dot.
///
/// Tapping opens the [NotificationInboxSheet].
/// The badge shows unread count from [notificationUnreadCountProvider].
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final unreadAsync = ref.watch(notificationUnreadCountProvider);
    final count = unreadAsync.value ?? 0;

    final label = count > 0
        ? 'Open notifications, $count unread'
        : 'Open notifications';

    return Tooltip(
      message: label,
      child: PressableScale(
        onTap: () => NotificationInboxSheet.show(context),
        semanticLabel: label,
        minTouchTargetSize: const Size(44, 44),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                LucideIcons.bell,
                size: 22,
                color: count > 0 ? cs.onSurface : cs.onSurfaceVariant,
              ),
              if (count > 0)
                Positioned(
                  top: -4,
                  right: -6,
                  child: _AnimatedBadge(count: count),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedBadge extends StatelessWidget {
  final int count;

  const _AnimatedBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayText = count > 99 ? '99+' : count.toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.surface, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cs.error.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        displayText,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: cs.onError,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}
