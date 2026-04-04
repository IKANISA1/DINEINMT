import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ShellScrollNotificationHost extends StatelessWidget {
  final Widget child;
  final ValueChanged<bool> onTopBarVisibilityChanged;
  final double hideAfterPixels;

  const ShellScrollNotificationHost({
    super.key,
    required this.child,
    required this.onTopBarVisibilityChanged,
    this.hideAfterPixels = 24,
  });

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification.metrics.pixels <= 0) {
      onTopBarVisibilityChanged(true);
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 0 && notification.metrics.pixels > hideAfterPixels) {
        onTopBarVisibilityChanged(false);
      } else if (delta < 0) {
        onTopBarVisibilityChanged(true);
      }
      return false;
    }

    if (notification is OverscrollNotification && notification.overscroll < 0) {
      onTopBarVisibilityChanged(true);
      return false;
    }

    if (notification is UserScrollNotification) {
      switch (notification.direction) {
        case ScrollDirection.forward:
          onTopBarVisibilityChanged(true);
          break;
        case ScrollDirection.reverse:
          if (notification.metrics.pixels > hideAfterPixels) {
            onTopBarVisibilityChanged(false);
          }
          break;
        case ScrollDirection.idle:
          break;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: child,
    );
  }
}

class CollapsibleShellBar extends StatelessWidget {
  final bool visible;
  final Widget child;
  final Duration duration;

  const CollapsibleShellBar({
    super.key,
    required this.visible,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: visible ? 1 : 0),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, bar) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: value,
            child: Opacity(
              opacity: value.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(0, -18 * (1 - value)),
                child: bar,
              ),
            ),
          ),
        );
      },
    );
  }
}
