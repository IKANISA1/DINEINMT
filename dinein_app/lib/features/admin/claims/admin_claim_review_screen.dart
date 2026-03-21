import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/claim_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Admin claim review screen — approve or reject venue claims from live data.
/// Uses [pendingClaimsProvider] and [ClaimRepository] for actions.
class AdminClaimReviewScreen extends ConsumerWidget {
  const AdminClaimReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final claimsAsync = ref.watch(pendingClaimsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Claim Review', style: tt.headlineMedium)),
      body: claimsAsync.when(
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 300),
        ),
        error: (_, _) => ErrorState(
          message: 'Could not load claims.',
          onRetry: () => ref.invalidate(pendingClaimsProvider),
        ),
        data: (claims) {
          if (claims.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.shieldCheck,
              title: 'No pending claims',
              subtitle: 'All venue claims have been reviewed.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.space6),
            itemCount: claims.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTheme.space3),
            itemBuilder: (context, index) {
              final claim = claims[index];
              return _ClaimCard(
                claim: claim,
                onApprove: () async {
                  final result = await ClaimRepository.instance.approveClaim(
                    claim.id,
                    claim.venueId,
                  );
                  ref.invalidate(pendingClaimsProvider);
                  ref.invalidate(allVenuesProvider);
                  if (context.mounted) {
                    final activated =
                        result['venue_status'] == 'active' ||
                        result['venueStatus'] == 'active' ||
                        result['activated'] == true ||
                        result['approved'] == true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          activated
                              ? 'Claim approved — venue is now active'
                              : 'Claim approved',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                onReject: () async {
                  await ClaimRepository.instance.rejectClaim(claim.id);
                  ref.invalidate(pendingClaimsProvider);
                },
              ).animate(delay: (80 * index).ms).fadeIn(duration: 300.ms);
            },
          );
        },
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final VenueClaim claim;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ClaimCard({
    required this.claim,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: () => context.pushNamed(
        AppRouteNames.adminClaimDetail,
        pathParameters: {AppRouteParams.id: claim.id},
      ),
      child: ClayCard(
        padding: const EdgeInsets.all(AppTheme.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(
                    LucideIcons.store,
                    size: 22,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(claim.venueName, style: tt.titleSmall),
                      Text(
                        claim.venueArea,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: 'Pending',
                  color: AppColors.warning.withValues(alpha: 0.12),
                  textColor: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space4),
            Row(
              children: [
                Icon(LucideIcons.phone, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  claim.contactPhone,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                Icon(
                  LucideIcons.calendar,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, y').format(claim.createdAt),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space4),
            Row(
              children: [
                Expanded(
                  child: PremiumButton(
                    label: 'GO LIVE',
                    isSmall: true,
                    onPressed: onApprove,
                  ),
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: PremiumButton(
                    label: 'REJECT',
                    isSmall: true,
                    isOutlined: true,
                    onPressed: onReject,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
