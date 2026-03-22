import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Order success confirmation screen.
/// Shown after order placement — animated success icon + CTAs.
/// Matches React OrderSuccess.tsx.
class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final String? orderNumber;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    this.orderNumber,
  });

  String get _displayOrderNumber {
    final explicit = orderNumber?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return orderId.trim();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space8),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ─── Success Icon ───
              _buildSuccessIcon(cs)
                  .animate()
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: AppTheme.space12),

              // ─── Message ───
              Column(
                    children: [
                      Text(
                        'ORDER PLACED',
                        style: tt.displayMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space6),
                      Text(
                        'Your culinary journey has begun.',
                        textAlign: TextAlign.center,
                        style: tt.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),

              const SizedBox(height: AppTheme.space12),

              // ─── Order Details Card ───
              Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.space10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                      border: Border.all(color: AppColors.white5),
                      boxShadow: AppTheme.elevatedShadow,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ORDER NUMBER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.60,
                                ),
                              ),
                            ),
                            Text(
                              '#$_displayOrderNumber',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                color: cs.primary,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.space6),
                        Container(height: 1, color: AppColors.white5),
                      ],
                    ),
                  )
                  .animate(delay: 500.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),

              const Spacer(flex: 2),

              // ─── Actions ───
              Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.goNamed(
                            AppRouteNames.orderStatus,
                            pathParameters: {AppRouteParams.id: orderId},
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.secondary,
                            foregroundColor: cs.onSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusXxl,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Track Order',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(LucideIcons.arrowRight, size: 24),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              context.goNamed(AppRouteNames.discover),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.onSurface,
                            side: BorderSide(color: AppColors.white5),
                            backgroundColor: AppColors.white5,
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusXxl,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.home, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'Return Home',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                  .animate(delay: 700.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon(ColorScheme cs) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow
        Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.secondary.withValues(alpha: 0.20),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.4, end: 1, duration: 2000.ms),
        // Icon
        Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            color: cs.secondary,
            borderRadius: BorderRadius.circular(AppTheme.radius3xl),
            boxShadow: [
              BoxShadow(
                color: cs.secondary.withValues(alpha: 0.20),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(
            LucideIcons.checkCircle2,
            size: 64,
            color: cs.onSecondary,
          ),
        ),
      ],
    );
  }
}
