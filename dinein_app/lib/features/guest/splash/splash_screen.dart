import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/app_bootstrap_service.dart';
import '../../../shared/widgets/brand_mark.dart';

const _splashWordmarkGold = Color(0xFF624A1F);

/// DineIn startup screen while core services hydrate in the background.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
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
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Transform.scale(
                scale: 0.985 + (_pulseController.value * 0.015),
                child: child,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: screenHeight * 0.10),
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
                  SizedBox(height: screenHeight * 0.18),
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
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: AppBootstrapService.instance,
                    builder: (context, _) {
                      final bootstrap = AppBootstrapService.instance;
                      final statusLabel = switch (bootstrap.phase) {
                        AppBootstrapPhase.failed =>
                          'STARTUP REQUIRES ATTENTION',
                        AppBootstrapPhase.ready => 'OPENING EXPERIENCE',
                        AppBootstrapPhase.running || AppBootstrapPhase.idle =>
                          kIsWeb
                              ? 'PREPARING WEB EXPERIENCE'
                              : 'PREPARING YOUR SESSION',
                      };
                      final statusCopy = switch (bootstrap.phase) {
                        AppBootstrapPhase.failed =>
                          'Startup could not complete. Check configuration or connection, then retry.',
                        AppBootstrapPhase.ready =>
                          'Finishing the last setup steps.',
                        AppBootstrapPhase.running || AppBootstrapPhase.idle =>
                          'Loading venue access, menus, and your saved session in the background.',
                      };

                      return Column(
                        children: [
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: bootstrap.hasError
                                  ? Colors.red.shade200
                                  : Colors.white.withValues(alpha: 0.62),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 320,
                            child: Text(
                              statusCopy,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 14,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (bootstrap.hasError)
                            FilledButton(
                              onPressed: () => bootstrap.retry(),
                              child: const Text('Retry startup'),
                            )
                          else
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
