import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/claim_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Admin claim detail — full-page review matching React ClaimReview.tsx.
///
/// Layout:
/// - Back button + ShieldCheck icon + "CLAIM REVIEW" label + "Review Claim" 6xl
/// - Venue Info Card (image + name + location + category)
/// - Claimant Information (avatar + name + role + submitted + contact + context alert)
/// - Verification Documents (document rows with View File CTA)
/// - Fixed bottom action bar (Reject + Approve Claim)
class AdminClaimDetailScreen extends ConsumerStatefulWidget {
  final String claimId;

  const AdminClaimDetailScreen({super.key, required this.claimId});

  @override
  ConsumerState<AdminClaimDetailScreen> createState() =>
      _AdminClaimDetailScreenState();
}

class _AdminClaimDetailScreenState
    extends ConsumerState<AdminClaimDetailScreen> {
  bool _isApproving = false;
  bool _isRejecting = false;

  bool get _isBusy => _isApproving || _isRejecting;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final claimsAsync = ref.watch(pendingClaimsProvider);

    return Scaffold(
      body: claimsAsync.when(
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 300),
        ),
        error: (_, _) => ErrorState(
          message: 'Could not load claim.',
          onRetry: () => ref.invalidate(pendingClaimsProvider),
        ),
        data: (claims) {
          final claim = claims.where((c) => c.id == widget.claimId).firstOrNull;
          if (claim == null) {
            return const Center(child: Text('Claim not found'));
          }
          return _buildContent(context, ref, cs, tt, claim);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme cs,
    TextTheme tt,
    VenueClaim claim,
  ) {
    // Documents — empty until document upload feature is implemented
    final documents = <String>[];

    return Stack(
      children: [
        // ─── Scrollable Content ───
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space8,
            AppTheme.space8,
            AppTheme.space8,
            160, // space for fixed action bar
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Back Button ───
                PressableScale(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.10),
                      ),
                      boxShadow: AppTheme.clayShadow,
                    ),
                    child: Icon(
                      LucideIcons.chevronLeft,
                      size: 28,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.60),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space8),

                // ─── Header ───
                Row(
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'CLAIM REVIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: cs.primary.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space3),
                Text(
                  'Review Claim',
                  style: tt.displayMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: AppTheme.space2),
                Text(
                  'Verify the claimant before granting administrative access. Approving this claim will also activate the venue for discovery and ordering.',
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppTheme.space10),

                // ─── Venue Info Card ───
                _buildVenueCard(
                  cs,
                  tt,
                  claim,
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: AppTheme.space10),

                // ─── Claimant Information ───
                _buildClaimantSection(cs, tt, claim)
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: AppTheme.space10),

                // ─── Verification Documents ───
                _buildDocumentsSection(cs, tt, documents)
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        ),

        // ─── Fixed Bottom Action Bar ───
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space8,
                0,
                AppTheme.space8,
                AppTheme.space6,
              ),
              child: Row(
                children: [
                  // Reject (flex-1)
                  Expanded(
                    flex: 1,
                    child: PressableScale(
                      onTap: _isBusy ? null : () => _handleReject(claim),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: cs.error.withValues(
                            alpha: _isBusy ? 0.05 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXxl,
                          ),
                          border: Border.all(
                            color: cs.error.withValues(alpha: 0.20),
                          ),
                          boxShadow: AppTheme.clayShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isRejecting)
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.error,
                                ),
                              )
                            else
                              Icon(
                                LucideIcons.xCircle,
                                size: 24,
                                color: cs.error.withValues(
                                  alpha: _isBusy ? 0.40 : 1.0,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Text(
                              'REJECT',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: cs.error.withValues(
                                  alpha: _isBusy ? 0.40 : 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space5),
                  // Approve (flex-2)
                  Expanded(
                    flex: 2,
                    child: PressableScale(
                      onTap: _isBusy ? null : () => _handleApprove(claim),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: _isBusy
                              ? cs.primary.withValues(alpha: 0.50)
                              : cs.primary,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXxl,
                          ),
                          boxShadow: AppTheme.clayShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isApproving)
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onPrimary,
                                ),
                              )
                            else
                              Icon(
                                LucideIcons.checkCircle2,
                                size: 24,
                                color: cs.onPrimary,
                              ),
                            const SizedBox(width: 12),
                            Text(
                              'APPROVE & ACTIVATE',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: cs.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleReject(VenueClaim claim) async {
    if (_isBusy) return;
    setState(() => _isRejecting = true);
    try {
      await ClaimRepository.instance.rejectClaim(widget.claimId);
      ref.invalidate(pendingClaimsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim rejected'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRejecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleApprove(VenueClaim claim) async {
    if (_isBusy) return;
    setState(() => _isApproving = true);
    try {
      final result = await ClaimRepository.instance.approveClaim(
        widget.claimId,
        claim.venueId,
      );
      ref.invalidate(pendingClaimsProvider);
      ref.invalidate(allVenuesProvider);
      if (mounted) {
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
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApproving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Venue Info Card — image (grayscale) + name + location + category.
  Widget _buildVenueCard(ColorScheme cs, TextTheme tt, VenueClaim claim) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius3xl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.10)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Row(
        children: [
          // Venue image placeholder (grayscale)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
              boxShadow: AppTheme.clayShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.saturation,
                ),
                child: Container(
                  color: cs.surfaceContainerHigh,
                  child: Icon(
                    LucideIcons.store,
                    size: 36,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  claim.venueName,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      LucideIcons.mapPin,
                      size: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        claim.venueArea,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Text(
                      'VENUE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Claimant Information — avatar + name + role + submitted + contact + context alert.
  Widget _buildClaimantSection(ColorScheme cs, TextTheme tt, VenueClaim claim) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
          child: Text(
            'Claimant Information',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space5),
        Container(
          padding: const EdgeInsets.all(AppTheme.space8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radius3xl),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.10),
            ),
            boxShadow: AppTheme.clayShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + Name
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    ),
                    child: Icon(LucideIcons.user, size: 32, color: cs.primary),
                  ),
                  const SizedBox(width: AppTheme.space6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FULL NAME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          claim.displayName,
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space8),

              // Role + Submitted (2-column)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ROLE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Owner / Manager',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'SUBMITTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(claim.createdAt),
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space8),

              // Contact Details
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTACT DETAILS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    claim.contactPhone,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space8),

              // Verification Context Alert
              Container(
                padding: const EdgeInsets.all(AppTheme.space6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.10)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Icon(
                        LucideIcons.alertCircle,
                        size: 22,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VERIFICATION CONTEXT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'The claimant is requesting full administrative access to the venue profile. They have provided documents as proof of ownership/management.',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Verification Documents section.
  Widget _buildDocumentsSection(
    ColorScheme cs,
    TextTheme tt,
    List<String> documents,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
          child: Text(
            'Verification Documents',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space5),
        if (documents.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radius3xl),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.fileX,
                  size: 24,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                ),
                const SizedBox(width: AppTheme.space5),
                Expanded(
                  child: Text(
                    'No documents uploaded yet.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...documents.map(
            (doc) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space3),
              child: PressableScale(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.10),
                    ),
                    boxShadow: AppTheme.clayShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.fileText,
                          size: 28,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space5),
                      Expanded(
                        child: Text(
                          doc,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'VIEW FILE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}
