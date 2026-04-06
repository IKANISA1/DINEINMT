import 'package:flutter/material.dart';

import 'package:db_pkg/models/models.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: tone.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: tone.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.9,
        ),
      ),
    );
  }
}

class _MenuItemBadgeTone {
  final Color background;
  final Color border;
  final Color foreground;

  const _MenuItemBadgeTone({
    required this.background,
    required this.border,
    required this.foreground,
  });
}

_MenuItemBadgeTone _toneForBadge(String label) {
  final normalized = label.trim().toLowerCase();
  if (normalized == 'popular') {
    return _MenuItemBadgeTone(
      background: AppColors.primary.withValues(alpha: 0.14),
      border: AppColors.primary.withValues(alpha: 0.30),
      foreground: AppColors.primary,
    );
  }
  if (normalized == 'top pick' || normalized == 'signature') {
    return _MenuItemBadgeTone(
      background: AppColors.warning.withValues(alpha: 0.16),
      border: AppColors.warning.withValues(alpha: 0.32),
      foreground: AppColors.warning,
    );
  }
  if (normalized == 'featured') {
    return _MenuItemBadgeTone(
      background: AppColors.tertiary.withValues(alpha: 0.14),
      border: AppColors.tertiary.withValues(alpha: 0.28),
      foreground: AppColors.tertiary,
    );
  }
  if (normalized == 'vegetarian' || normalized == 'vegan') {
    return _MenuItemBadgeTone(
      background: AppColors.secondary.withValues(alpha: 0.14),
      border: AppColors.secondary.withValues(alpha: 0.26),
      foreground: AppColors.secondary,
    );
  }
  if (normalized == 'halal' || normalized == 'kosher') {
    return _MenuItemBadgeTone(
      background: AppColors.tertiary.withValues(alpha: 0.14),
      border: AppColors.tertiary.withValues(alpha: 0.26),
      foreground: AppColors.tertiary,
    );
  }
  if (normalized.endsWith('-free') || normalized == 'gluten-free') {
    return _MenuItemBadgeTone(
      background: AppColors.warning.withValues(alpha: 0.14),
      border: AppColors.warning.withValues(alpha: 0.22),
      foreground: AppColors.warning,
    );
  }
  if (normalized.startsWith('contains ') || normalized == 'spicy') {
    return _MenuItemBadgeTone(
      background: AppColors.error.withValues(alpha: 0.14),
      border: AppColors.error.withValues(alpha: 0.22),
      foreground: AppColors.error,
    );
  }
  return _MenuItemBadgeTone(
    background: AppColors.surfaceContainerHigh,
    border: AppColors.white10,
    foreground: AppColors.onSurfaceVariant,
  );
}
