import 'package:flutter/material.dart';

import 'package:db_pkg/models/models.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/widgets/shared_widgets.dart';

class MenuItemBadges extends StatelessWidget {
  final MenuItem item;
  final int maxBadges;

  const MenuItemBadges({super.key, required this.item, this.maxBadges = 4});

  @override
  Widget build(BuildContext context) {
    final badges = item.guestDisplayTags
        .take(maxBadges)
        .toList(growable: false);
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final badge in badges)
          _MenuItemBadge(label: badge, tone: _toneForBadge(badge)),
      ],
    );
  }
}

class _MenuItemBadge extends StatelessWidget {
  final String label;
  final _MenuItemBadgeTone tone;

  const _MenuItemBadge({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return AppPill(
      label: label,
      dense: true,
      color: tone.background,
      foregroundColor: tone.foreground,
    );
  }
}

class _MenuItemBadgeTone {
  final Color background;
  final Color foreground;

  const _MenuItemBadgeTone({
    required this.background,
    required this.foreground,
  });
}

_MenuItemBadgeTone _toneForBadge(String label) {
  final normalized = label.trim().toLowerCase();

  if (normalized == 'vegetarian' || normalized == 'vegan') {
    return _MenuItemBadgeTone(
      background: AppColors.secondary.withValues(alpha: 0.14),
      foreground: AppColors.secondary,
    );
  }
  if (normalized == 'halal' || normalized == 'kosher') {
    return _MenuItemBadgeTone(
      background: AppColors.tertiary.withValues(alpha: 0.14),
      foreground: AppColors.tertiary,
    );
  }
  if (normalized.endsWith('-free') || normalized == 'gluten-free') {
    return _MenuItemBadgeTone(
      background: AppColors.warning.withValues(alpha: 0.14),
      foreground: AppColors.warning,
    );
  }
  if (normalized.startsWith('contains ') || normalized == 'spicy') {
    return _MenuItemBadgeTone(
      background: AppColors.error.withValues(alpha: 0.14),
      foreground: AppColors.error,
    );
  }
  return _MenuItemBadgeTone(
    background: AppColors.surfaceContainerHigh,
    foreground: AppColors.onSurfaceVariant,
  );
}
