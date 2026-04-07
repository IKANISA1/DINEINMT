import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/router/web_entry_routing.dart';
import 'package:dinein_app/core/services/app_bootstrap_service.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:ui/widgets/brand_mark.dart';

const _splashWordmarkGold = Color(0xFF624A1F);

/// DineIn startup screen — minimal brand mark + spinner.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigationScheduled = false;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DineInLogoText(
              fontSize: 72,
              dineColor: _splashWordmarkGold,
              inColor: Colors.white,
              letterSpacing: -2,
            ),
            const SizedBox(height: 48),
            AnimatedBuilder(
              animation: AppBootstrapService.instance,
              builder: (context, _) {
                final bootstrap = AppBootstrapService.instance;
                final statusLabel = bootstrap.hasError
                    ? 'COULD NOT CONNECT'
                    : 'LOADING…';

                if (bootstrap.isReady) {
                  final stateUri = _currentSplashUri(context);
                  final target = _resolveSplashTarget(stateUri);
                  _scheduleExitFromSplash(target);
                }

                return Column(
                  children: [
                    if (bootstrap.hasError) ...[
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: Colors.red.shade200,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.8,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => bootstrap.retry(),
                        child: const Text('Retry'),
                      ),
                    ] else
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.50),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleExitFromSplash(String? target) {
    if (_navigationScheduled || !mounted) return;
    if (target == null) return;
    _navigationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(target);
    });
  }

  String? _resolveSplashTarget(Uri stateUri) {
    final pendingReturnTo = _resolvePendingReturnTo(stateUri);
    if (pendingReturnTo != null) {
      return pendingReturnTo;
    }

    if (kIsWeb) {
      return resolveCurrentWebRootRoute(Uri.base) ?? AppRoutePaths.discover;
    }

    if (AuthRepository.instance.hasAdminAccess) {
      return AppRoutePaths.adminOverview;
    }
    if (AuthRepository.instance.hasVenueAccess) {
      return AppRoutePaths.venueDashboard;
    }
    return AppRoutePaths.discover;
  }

  String? _resolvePendingReturnTo(Uri uri) {
    final raw = uri.queryParameters[AppRouteParams.returnTo];
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final resolved = Uri.tryParse(raw);
    if (resolved == null || resolved.path.isEmpty) {
      return null;
    }
    if (resolved.path == AppRoutePaths.splash) {
      return null;
    }
    return resolved.toString();
  }

  Uri _currentSplashUri(BuildContext context) {
    try {
      return GoRouterState.of(context).uri;
    } catch (_) {
      return Uri(path: AppRoutePaths.splash);
    }
  }
}
