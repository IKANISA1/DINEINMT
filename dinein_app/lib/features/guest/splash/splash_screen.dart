import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/router/web_entry_routing.dart';
import 'package:dinein_app/core/services/app_bootstrap_service.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space6),
            child: AppSurfaceCard(
              radius: AppTheme.radiusXxl,
              padding: const EdgeInsets.all(AppTheme.space8),
              elevated: true,
              child: AnimatedBuilder(
                animation: AppBootstrapService.instance,
                builder: (context, _) {
                  final bootstrap = AppBootstrapService.instance;

                  if (bootstrap.isReady) {
                    final stateUri = _currentSplashUri(context);
                    final target = _resolveSplashTarget(stateUri);
                    _scheduleExitFromSplash(target);
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DineInLogoText(
                        fontSize: 52,
                        dineColor: Color(0xFF75663A),
                        inColor: Color(0xFF181611),
                        letterSpacing: -1.4,
                      ),
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        bootstrap.hasError
                            ? 'Could not connect right now.'
                            : 'Preparing your table-side experience.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.84),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space6),
                      if (bootstrap.hasError) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => bootstrap.retry(),
                            child: const Text('Retry'),
                          ),
                        ),
                      ] else
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
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
