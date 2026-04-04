import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/theme/app_theme.dart';

import 'package:dinein_app/core/providers/connectivity_provider.dart';

/// A subtle top banner that appears when the device goes offline.
///
/// Place this at the top of the widget tree (e.g., in the app builder)
/// to provide a consistent offline indicator across all screens.
///
/// Design: slim, non-intrusive bar with amber/gold accent matching
/// the DineIn brand. Animates in/out smoothly.
class OfflineBanner extends ConsumerWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);

    return Column(
      children: [
        AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: isOnline ? const Offset(0, -1) : Offset.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isOnline ? 0 : null,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + AppTheme.space2,
                  bottom: AppTheme.space2,
                  left: AppTheme.space4,
                  right: AppTheme.space4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withValues(alpha: 0.9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: AppTheme.space2),
                    Text(
                      'No internet connection',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
