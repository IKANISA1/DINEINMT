import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:db_pkg/models/bell_request.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/services/bell_repository.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class VenueWavesScreen extends ConsumerWidget {
  const VenueWavesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(currentVenueProvider);

    return venueAsync.when(
      loading: () => const Center(
        child: SkeletonLoader(width: double.infinity, height: 200),
      ),
      error: (_, _) => ErrorState(
        message: 'Could not load venue data.',
        onRetry: () => ref.invalidate(currentVenueProvider),
      ),
      data: (venue) {
        if (venue == null) {
          return const Scaffold(body: Center(child: Text('No venue session')));
        }

        return DefaultTabController(
          length: 2,
          child: _WavesBody(venueId: venue.id),
        );
      },
    );
  }
}

class _WavesBody extends ConsumerStatefulWidget {
  final String venueId;
  const _WavesBody({required this.venueId});

  @override
  ConsumerState<_WavesBody> createState() => _WavesBodyState();
}

class _WavesBodyState extends ConsumerState<_WavesBody> {
  static const _pollInterval = Duration(seconds: 4);

  Timer? _pollTimer;
  List<BellRequest> _allWaves = const [];
  Object? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadWaves());
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_loadWaves(background: true));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWaves({bool background = false}) async {
    if (!mounted) return;
    if (!background) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final waves = await BellRepository.instance.getBellRequests(
        widget.venueId,
      );
      if (!mounted) return;
      setState(() {
        _allWaves = waves;
        _loadError = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (_allWaves.isEmpty) {
          _loadError = error;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Waves',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          indicatorColor: cs.primary,
          indicatorWeight: 3,
          labelColor: cs.onSurface,
          unselectedLabelColor: cs.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
          tabs: const [
            Tab(text: 'ACTIVE'),
            Tab(text: 'RESOLVED'),
          ],
        ),
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(AppTheme.space6),
              child: Column(
                children: List.generate(
                  4,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: AppTheme.space4),
                    child: SkeletonLoader(width: double.infinity, height: 80),
                  ),
                ),
              ),
            )
          : _loadError != null
          ? ErrorState(message: 'Could not load waves.', onRetry: _loadWaves)
          : (() {
              final active = _allWaves
                  .where((w) => w.status == WaveStatus.pending)
                  .toList();
              final resolved = _allWaves
                  .where((w) => w.status == WaveStatus.resolved)
                  .toList();

              return TabBarView(
                children: [
                  _WavesList(
                    waves: active,
                    emptyIcon: LucideIcons.checkCircle2,
                    emptyTitle: 'All clear',
                    emptySubtitle: 'No pending guest requests right now.',
                    showResolveAction: true,
                  ),
                  _WavesList(
                    waves: resolved,
                    emptyIcon: LucideIcons.history,
                    emptyTitle: 'No history',
                    emptySubtitle: 'Resolved waves will appear here.',
                    showResolveAction: false,
                  ),
                ],
              );
            })(),
    );
  }
}

class _WavesList extends StatelessWidget {
  final List<BellRequest> waves;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final bool showResolveAction;

  const _WavesList({
    required this.waves,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.showResolveAction,
  });

  @override
  Widget build(BuildContext context) {
    if (waves.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.space6),
      itemCount: waves.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.space4),
      itemBuilder: (context, index) {
        final wave = waves[index];
        return _WaveCard(wave: wave, showResolveAction: showResolveAction);
      },
    );
  }
}

class _WaveCard extends ConsumerStatefulWidget {
  final BellRequest wave;
  final bool showResolveAction;

  const _WaveCard({required this.wave, required this.showResolveAction});

  @override
  ConsumerState<_WaveCard> createState() => _WaveCardState();
}

class _WaveCardState extends ConsumerState<_WaveCard> {
  bool _isResolving = false;

  Future<void> _handleResolve() async {
    setState(() => _isResolving = true);
    try {
      await BellRepository.instance.resolveWave(widget.wave.id);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        setState(() => _isResolving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to resolve wave')));
      }
    }
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isPending = widget.wave.status == WaveStatus.pending;
    final duration = DateTime.now().difference(widget.wave.createdAt);
    final isUrgent = isPending && duration.inMinutes >= 5;

    return ClayCard(
      accentGradient: isUrgent,
      child: Row(
        children: [
          // Table badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPending
                  ? (isUrgent
                        ? cs.error.withValues(alpha: 0.1)
                        : cs.primaryContainer.withValues(alpha: 0.5))
                  : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                widget.wave.tableNumber,
                style: tt.titleLarge?.copyWith(
                  color: isPending
                      ? (isUrgent ? cs.error : cs.onPrimaryContainer)
                      : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space4),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Table ${widget.wave.tableNumber}',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  isPending
                      ? 'Waiting for ${duration.inMinutes}m'
                      : _formatDuration(duration),
                  style: tt.bodySmall?.copyWith(
                    color: isUrgent ? cs.error : cs.onSurfaceVariant,
                    fontWeight: isUrgent ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),

          // Action
          if (widget.showResolveAction && isPending)
            _isResolving
                ? const Padding(
                    padding: EdgeInsets.all(AppTheme.space4),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : PremiumButton(
                    label: 'RESOLVE',
                    isSmall: true,
                    onPressed: _handleResolve,
                  )
          else if (!isPending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'CLOSED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppColors.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
