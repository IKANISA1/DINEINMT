import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

/// Toast notification type.
enum ToastType { success, error, warning, info }

/// A single toast request.
class _ToastRequest {
  final String message;
  final ToastType type;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ToastRequest({
    required this.message,
    required this.type,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });
}

/// Global toast manager. Access via [DineInToast.instance].
///
/// Must be initialized by placing [DineInToastOverlay] in the widget tree
/// (typically wrapping the root [MaterialApp]).
class DineInToast {
  DineInToast._();

  static final DineInToast instance = DineInToast._();

  static const int _maxVisible = 3;

  OverlayState? _overlay;
  final Queue<_ToastRequest> _queue = Queue();
  final List<_ToastEntry> _active = [];

  /// Call once from [DineInToastOverlay] to bind the overlay.
  void _attach(OverlayState overlay) {
    _overlay = overlay;
  }

  /// Show a toast notification.
  ///
  /// If [maxVisible] toasts are already showing, the request is enqueued.
  void show({
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(milliseconds: 3500),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final request = _ToastRequest(
      message: message,
      type: type,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );

    if (_active.length >= _maxVisible) {
      _queue.add(request);
      return;
    }

    _present(request);
  }

  /// Convenience shortcuts.
  void success(String message, {String? actionLabel, VoidCallback? onAction}) =>
      show(
        message: message,
        type: ToastType.success,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  void error(String message, {String? actionLabel, VoidCallback? onAction}) =>
      show(
        message: message,
        type: ToastType.error,
        duration: const Duration(milliseconds: 5000),
        actionLabel: actionLabel,
        onAction: onAction,
      );

  void warning(String message, {String? actionLabel, VoidCallback? onAction}) =>
      show(
        message: message,
        type: ToastType.warning,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  void info(String message, {String? actionLabel, VoidCallback? onAction}) =>
      show(
        message: message,
        type: ToastType.info,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  void _present(_ToastRequest request) {
    final overlay = _overlay;
    if (overlay == null) return;

    late final _ToastEntry entry;
    final overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        request: request,
        index: _active.indexOf(entry),
        onDismiss: () => _dismiss(entry),
      ),
    );

    entry = _ToastEntry(
      request: request,
      overlayEntry: overlayEntry,
    );

    _active.add(entry);
    overlay.insert(overlayEntry);
    _rebuildAll();

    if (request.duration > Duration.zero) {
      entry.timer = Timer(request.duration, () => _dismiss(entry));
    }
  }

  void _dismiss(_ToastEntry entry) {
    if (!_active.contains(entry)) return;
    _active.remove(entry);
    entry.timer?.cancel();
    entry.overlayEntry.remove();
    _rebuildAll();

    if (_queue.isNotEmpty && _active.length < _maxVisible) {
      _present(_queue.removeFirst());
    }
  }

  void _rebuildAll() {
    for (final entry in _active) {
      entry.overlayEntry.markNeedsBuild();
    }
  }
}

class _ToastEntry {
  final _ToastRequest request;
  final OverlayEntry overlayEntry;
  Timer? timer;

  _ToastEntry({required this.request, required this.overlayEntry});
}

/// Place this widget at the root of your app tree to enable toasts.
///
/// ```dart
/// DineInToastOverlay(
///   child: MaterialApp.router(...),
/// )
/// ```
class DineInToastOverlay extends StatefulWidget {
  final Widget child;

  const DineInToastOverlay({super.key, required this.child});

  @override
  State<DineInToastOverlay> createState() => _DineInToastOverlayState();
}

class _DineInToastOverlayState extends State<DineInToastOverlay> {
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final overlay = _overlayKey.currentState;
      if (overlay != null) {
        DineInToast.instance._attach(overlay);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Overlay(
        key: _overlayKey,
        initialEntries: [
          OverlayEntry(builder: (_) => widget.child),
        ],
      ),
    );
  }
}

// ─── Toast Widget ────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  final _ToastRequest request;
  final int index;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.request,
    required this.index,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateOut() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final index = widget.index < 0 ? 0 : widget.index;
    final bottomOffset = bottomPadding + 16 + (index * 64);

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomOffset,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.horizontal,
                onDismissed: (_) => widget.onDismiss(),
                child: Semantics(
                  liveRegion: true,
                  label: widget.request.message,
                  child: _ToastCard(
                    request: widget.request,
                    onDismiss: _animateOut,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  final _ToastRequest request;
  final VoidCallback onDismiss;

  const _ToastCard({required this.request, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final scheme = _colorScheme(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: scheme.iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(scheme.icon, size: 14, color: scheme.iconColor),
            ),
            const SizedBox(width: 10),

            // Message
            Expanded(
              child: Text(
                request.message,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: scheme.text,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Action button
            if (request.actionLabel != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  request.onAction?.call();
                  onDismiss();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.actionLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scheme.iconColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],

            // Close
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: scheme.text.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ToastColorScheme _colorScheme(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return switch (request.type) {
      ToastType.success => _ToastColorScheme(
          background: isDark
              ? const Color(0xFF0D2818)
              : const Color(0xFFE8F5E9),
          border: isDark
              ? const Color(0xFF1D9E75).withValues(alpha: 0.3)
              : const Color(0xFF1D9E75).withValues(alpha: 0.4),
          text: isDark ? const Color(0xFFB8E6D0) : const Color(0xFF085041),
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF1D9E75),
          iconBg: const Color(0xFF1D9E75).withValues(alpha: 0.15),
        ),
      ToastType.error => _ToastColorScheme(
          background: isDark
              ? const Color(0xFF2D0E0E)
              : const Color(0xFFFCEBEB),
          border: isDark
              ? const Color(0xFFA32D2D).withValues(alpha: 0.3)
              : const Color(0xFFA32D2D).withValues(alpha: 0.4),
          text: isDark ? const Color(0xFFEAB4B4) : const Color(0xFF501313),
          icon: Icons.error_rounded,
          iconColor: const Color(0xFFA32D2D),
          iconBg: const Color(0xFFA32D2D).withValues(alpha: 0.15),
        ),
      ToastType.warning => _ToastColorScheme(
          background: isDark
              ? const Color(0xFF2B1D06)
              : const Color(0xFFFAEEDA),
          border: isDark
              ? const Color(0xFFBA7517).withValues(alpha: 0.3)
              : const Color(0xFFBA7517).withValues(alpha: 0.4),
          text: isDark ? const Color(0xFFE6CB94) : const Color(0xFF412402),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFBA7517),
          iconBg: const Color(0xFFBA7517).withValues(alpha: 0.15),
        ),
      ToastType.info => _ToastColorScheme(
          background: isDark
              ? const Color(0xFF0B1D2E)
              : const Color(0xFFE6F1FB),
          border: isDark
              ? const Color(0xFF185FA5).withValues(alpha: 0.3)
              : const Color(0xFF185FA5).withValues(alpha: 0.4),
          text: isDark ? const Color(0xFFA4C8E8) : const Color(0xFF042C53),
          icon: Icons.info_rounded,
          iconColor: const Color(0xFF185FA5),
          iconBg: const Color(0xFF185FA5).withValues(alpha: 0.15),
        ),
    };
  }
}

class _ToastColorScheme {
  final Color background;
  final Color border;
  final Color text;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const _ToastColorScheme({
    required this.background,
    required this.border,
    required this.text,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
}
