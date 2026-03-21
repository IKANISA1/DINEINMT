import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/bell_request.dart';
import '../../../core/providers/bell_providers.dart';
import '../../../core/services/bell_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

class BellRequestsSheet extends ConsumerWidget {
  final String venueId;

  const BellRequestsSheet({super.key, required this.venueId});

  static Future<void> show(BuildContext context, String venueId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: BellRequestsSheet(venueId: venueId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final wavesAsync = ref.watch(pendingWavesProvider(venueId));

    return Column(
      children: [
        GlassHeader(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.bellRing, size: 20, color: AppColors.secondary),
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Requests', style: tt.titleLarge),
                    Text(
                      'Tap to resolve requests',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: wavesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading requests: $err')),
            data: (waves) {
              if (waves.isEmpty) {
                return const EmptyState(
                  icon: LucideIcons.checkCircle2,
                  title: 'All clear',
                  subtitle: 'No pending guest requests right now.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppTheme.space6),
                itemCount: waves.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppTheme.space4),
                itemBuilder: (context, index) {
                  final wave = waves[index];
                  return _WaveRequestCard(wave: wave);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WaveRequestCard extends ConsumerStatefulWidget {
  final BellRequest wave;

  const _WaveRequestCard({required this.wave});

  @override
  ConsumerState<_WaveRequestCard> createState() => _WaveRequestCardState();
}

class _WaveRequestCardState extends ConsumerState<_WaveRequestCard> {
  bool _isResolving = false;

  Future<void> _handleResolve() async {
    setState(() => _isResolving = true);
    try {
      await BellRepository.instance.resolveWave(widget.wave.id);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        setState(() => _isResolving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resolve request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final duration = DateTime.now().difference(widget.wave.createdAt);
    final isUrgent = duration.inMinutes >= 5;

    return ClayCard(
      accentGradient: isUrgent,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUrgent
                  ? cs.error.withValues(alpha: 0.1)
                  : cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                widget.wave.tableNumber,
                style: tt.titleLarge?.copyWith(
                  color: isUrgent ? cs.error : cs.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Table ${widget.wave.tableNumber}',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Waiting for ${duration.inMinutes}m',
                  style: tt.bodySmall?.copyWith(
                    color: isUrgent ? cs.error : cs.onSurfaceVariant,
                    fontWeight: isUrgent ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
          if (_isResolving)
            const Padding(
              padding: EdgeInsets.all(AppTheme.space4),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PremiumButton(
              label: 'RESOLVE',
              isSmall: true,
              onPressed: _handleResolve,
            ),
        ],
      ),
    );
  }
}
