import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/auth_repository.dart';
import '../../../shared/widgets/brand_mark.dart';

const _splashWordmarkGold = Color(0xFF624A1F);

/// DineIn animated splash screen.
///
/// Premium brand intro: animated logo sequence → auto-navigate based on role.
/// Matches the provided reference design.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exitController;
  late final Animation<double> _exitOpacity;
  late final Animation<double> _exitScale;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Exit animation: fade out + slight zoom at 2.5s mark
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    // Schedule exit animation at 2.5s, navigate at 3s
    _navTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _exitController.forward().then((_) {
        if (!mounted) return;
        _navigateToHome();
      });
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _exitController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    final auth = AuthRepository.instance;
    if (auth.hasAdminAccess) {
      context.goNamed(AppRouteNames.adminOverview);
    } else if (auth.hasVenueAccess) {
      context.goNamed(AppRouteNames.venueDashboard);
    } else {
      context.goNamed(AppRouteNames.discover);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force light status-bar icons on dark background
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: AnimatedBuilder(
        animation: _exitController,
        builder: (context, child) => Opacity(
          opacity: _exitOpacity.value,
          child: Transform.scale(scale: _exitScale.value, child: child),
        ),
        child: Stack(
          children: [
            // ─── Subtle radial vignette glow ───
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [const Color(0xFF1A1A18), const Color(0xFF0A0A0A)],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // ─── Content ───
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Push content up from center
                  SizedBox(height: screenHeight * 0.10),

                  // ─── Single splash wordmark ───
                  const DineInLogoText(
                        fontSize: 72,
                        dineColor: _splashWordmarkGold,
                        inColor: Colors.white,
                        letterSpacing: -2,
                      )
                      .animate()
                      .fadeIn(duration: 700.ms, curve: Curves.easeOutCubic)
                      .scale(
                        begin: const Offset(0.72, 0.72),
                        end: const Offset(1.0, 1.0),
                        duration: 900.ms,
                        curve: Curves.easeOutBack,
                      )
                      .slideY(
                        begin: 0.12,
                        end: 0,
                        duration: 700.ms,
                        curve: Curves.easeOutCubic,
                      ),

                  // ─── Spacer to push tagline toward bottom ───
                  SizedBox(height: screenHeight * 0.28),

                  // ─── Divider line ───
                  Container(
                        width: 32,
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.12),
                      )
                      .animate(delay: 700.ms)
                      .fadeIn(duration: 500.ms)
                      .scaleX(
                        begin: 0.0,
                        end: 1.0,
                        duration: 500.ms,
                        curve: Curves.easeOutCubic,
                      ),

                  const SizedBox(height: 20),

                  // ─── Tagline: "DINE IN, STAND OUT." ───
                  Text(
                        'DINE IN, STAND OUT.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.30),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 5,
                          height: 1,
                        ),
                      )
                      .animate(delay: 900.ms)
                      .fadeIn(duration: 600.ms, curve: Curves.easeOut),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
