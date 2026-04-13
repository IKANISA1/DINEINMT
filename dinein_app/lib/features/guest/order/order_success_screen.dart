import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:url_launcher/url_launcher.dart';

/// Order success confirmation screen.
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
    final momoCode = CountryRuntime.config.momoUssdCode;

    return Scaffold(
      bottomNavigationBar: GuestStickyActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.goNamed(
                  AppRouteNames.orderStatus,
                  pathParameters: {AppRouteParams.id: orderId},
                ),
                icon: const Icon(LucideIcons.arrowRight, size: 18),
                label: const Text('Track order'),
              ),
            ),
            const SizedBox(height: AppTheme.space3),
            Row(
              children: [
                if (momoCode != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _launchMomo(momoCode),
                      icon: const Icon(LucideIcons.smartphone, size: 18),
                      label: const Text('Pay'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space3),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.goNamed(AppRouteNames.discover),
                    icon: const Icon(LucideIcons.home, size: 18),
                    label: const Text('Home'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space6,
            AppTheme.space6,
            AppTheme.space6,
            AppTheme.space12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GuestHeroCard(
                    eyebrow: 'Order confirmed',
                    title: 'You’re all set.',
                    subtitle:
                        'We received order #$_displayOrderNumber and your venue can update you live from the status screen.',
                    trailing: _buildSuccessIcon(cs),
                  ),
                  const SizedBox(height: AppTheme.space5),
                  GuestSurfaceCard(
                    padding: const EdgeInsets.all(AppTheme.space5),
                    borderRadius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GuestSectionHeader(
                          title: 'Order details',
                          subtitle: 'Reference and next steps.',
                        ),
                        const SizedBox(height: AppTheme.space4),
                        Wrap(
                          spacing: AppTheme.space3,
                          runSpacing: AppTheme.space3,
                          children: [
                            GuestMetaPill(
                              label: '#$_displayOrderNumber',
                              icon: Icons.receipt_long_rounded,
                              emphasized: true,
                            ),
                            const GuestMetaPill(
                              label: 'Live updates',
                              icon: LucideIcons.clock3,
                            ),
                            const GuestMetaPill(
                              label: 'Table order',
                              icon: LucideIcons.utensilsCrossed,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (momoCode != null) ...[
                    const SizedBox(height: AppTheme.space5),
                    GuestSurfaceCard(
                      padding: const EdgeInsets.all(AppTheme.space5),
                      borderRadius: 24,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              LucideIcons.smartphone,
                              size: 20,
                              color: cs.secondary,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Need to finish payment?',
                                  style: tt.titleSmall,
                                ),
                                const SizedBox(height: AppTheme.space2),
                                Text(
                                  'Open MoMo from here if you chose that method at checkout.',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.82,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon(ColorScheme cs) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: cs.secondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        boxShadow: [
          BoxShadow(
            color: cs.secondary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(LucideIcons.checkCircle2, size: 30, color: cs.onSecondary),
    );
  }

  Future<void> _launchMomo(String code) async {
    final url = Uri.parse('tel:$code');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
