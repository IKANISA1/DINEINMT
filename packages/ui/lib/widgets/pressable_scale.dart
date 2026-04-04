import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ui/theme/motion_preferences.dart';

/// Provides a press-down scale effect on any interactive element.
///
/// Matches the React reference's `whileTap={{ scale: 0.95 }}` pattern.
/// Wraps a child widget and animates to [scaleFactor] on tap-down,
/// springing back to 1.0 on tap-up/cancel.
///
/// Includes keyboard focus + Enter/Space activation for accessibility.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;
  final String? semanticLabel;
  final Size? minTouchTargetSize;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 150),
    this.semanticLabel,
    this.minTouchTargetSize,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOut,
            reverseCurve: Curves.easeOutBack,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (reduceMotionOf(context)) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (!reduceMotionOf(context)) {
      _controller.reverse();
    }
    widget.onTap?.call();
  }

  void _onTapCancel() {
    if (reduceMotionOf(context)) return;
    _controller.reverse();
  }

  void _handleKeyActivation() {
    if (reduceMotionOf(context)) {
      widget.onTap?.call();
      return;
    }
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onTap?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = reduceMotionOf(context);
    final constrainedChild = widget.minTouchTargetSize == null
        ? widget.child
        : ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minTouchTargetSize!.width,
              minHeight: widget.minTouchTargetSize!.height,
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
          );
    final semanticChild = widget.semanticLabel == null
        ? constrainedChild
        : ExcludeSemantics(child: constrainedChild);

    if (widget.onTap == null) {
      return Semantics(
        button: true,
        enabled: false,
        label: widget.semanticLabel,
        child: semanticChild,
      );
    }

    return Semantics(
      button: true,
      enabled: true,
      label: widget.semanticLabel,
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            _handleKeyActivation();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            decoration: _isFocused
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  )
                : null,
            child: reduceMotion
                ? semanticChild
                : ScaleTransition(scale: _scaleAnimation, child: semanticChild),
          ),
        ),
      ),
    );
  }
}
