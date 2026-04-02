import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/permission_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/permission_access_dialog.dart';

class GuestLocationPermissionHost extends ConsumerStatefulWidget {
  const GuestLocationPermissionHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GuestLocationPermissionHost> createState() =>
      _GuestLocationPermissionHostState();
}

class _GuestLocationPermissionHostState
    extends ConsumerState<GuestLocationPermissionHost>
    with WidgetsBindingObserver {
  static const _guestVenueManagerSegments = {
    'claim',
    'verify',
    'onboarding',
    'order',
    'item',
    'ocr-review',
    'dashboard',
    'orders',
    'menu',
    'settings',
    'profile',
    'table-qr',
    'hours',
    'notifications',
    'language-region',
    'legal',
    'wifi',
    'waves',
  };

  bool _dialogOpen = false;
  bool _handledThisForeground = false;
  bool _checking = false;
  bool _showPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appRouter.routeInformationProvider.addListener(_handleRouteChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  @override
  void dispose() {
    appRouter.routeInformationProvider.removeListener(_handleRouteChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handledThisForeground = false;
      _maybePrompt();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _handledThisForeground = false;
    }
  }

  void _handleRouteChange() {
    _maybePrompt();
  }

  Future<void> _maybePrompt() async {
    if (!mounted || _checking || _dialogOpen || _handledThisForeground) return;

    final uri = appRouter.routeInformationProvider.value.uri;
    if (!_isGuestPromptRoute(uri)) return;

    _checking = true;
    final hasAccess = await ref
        .read(appPermissionServiceProvider)
        .isGuestLocationGranted();
    _checking = false;

    if (!mounted || hasAccess || _dialogOpen || _handledThisForeground) return;

    _handledThisForeground = true;
    setState(() {
      _dialogOpen = true;
      _showPrompt = true;
    });
  }

  bool _isGuestPromptRoute(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return false;

    switch (segments.first) {
      case 'discover':
      case 'venues':
      case 'orders':
      case 'settings':
      case 'cart':
      case 'item':
      case 'order':
      case 'v':
        return true;
      case 'venue':
        if (segments.length < 2) return false;
        return !_guestVenueManagerSegments.contains(segments[1]);
      default:
        return false;
    }
  }

  Future<void> _handlePromptAction(PermissionAccessDialogAction action) async {
    if (!mounted) return;

    setState(() {
      _dialogOpen = false;
      _showPrompt = false;
    });

    if (action != PermissionAccessDialogAction.grantAccess) {
      return;
    }

    await ref.read(appPermissionServiceProvider).openAppPermissionSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_showPrompt) ...[
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.76),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: PermissionAccessDialog(
                  config: PermissionAccessDialogConfig.guestLocation(),
                  onAction: _handlePromptAction,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
