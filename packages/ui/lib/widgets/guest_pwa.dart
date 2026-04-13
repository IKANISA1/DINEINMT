import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

class GuestSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool highlighted;

  const GuestSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.space5),
    this.borderRadius = 28,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = highlighted
        ? Color.lerp(cs.surfaceContainerLowest, cs.primaryContainer, 0.22)!
        : cs.surfaceContainerLowest;

    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: highlighted ? 0.92 : 0.72),
        ),
        boxShadow: highlighted
            ? AppTheme.elevatedShadow
            : AppTheme.ambientShadow,
      ),
      child: child,
    );

    if (onTap == null) return container;

    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Open card',
      child: container,
    );
  }
}

class GuestHeroCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? footer;

  const GuestHeroCard({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GuestSurfaceCard(
      highlighted: true,
      padding: const EdgeInsets.all(AppTheme.space6),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space3),
                    Text(
                      title,
                      style: tt.headlineLarge?.copyWith(height: 1.06),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTheme.space3),
                      Text(
                        subtitle!,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.82),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppTheme.space4),
                trailing!,
              ],
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: AppTheme.space5),
            footer!,
          ],
        ],
      ),
    );
  }
}

class GuestSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const GuestSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: tt.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          PressableScale(
            onTap: onAction,
            semanticLabel: actionLabel!,
            minTouchTargetSize: const Size(72, 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: tt.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 18, color: cs.primary),
              ],
            ),
          ),
      ],
    );
  }
}

class GuestSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String hintText;
  final bool readOnly;
  final Widget? trailing;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  const GuestSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onTap,
    this.hintText = 'Search',
    this.readOnly = false,
    this.trailing,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final field = Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space4,
          vertical: AppTheme.space3,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onTap: onTap,
                readOnly: readOnly,
                autofocus: autofocus,
                focusNode: focusNode,
                textInputAction: textInputAction,
                onSubmitted: onSubmitted,
                style: tt.bodyLarge,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  filled: false,
                  hintText: hintText,
                  hintStyle: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppTheme.space2),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (onTap == null || !readOnly) return field;

    return PressableScale(onTap: onTap, semanticLabel: hintText, child: field);
  }
}

class GuestQuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool emphasized;

  const GuestQuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GuestSurfaceCard(
      onTap: onTap,
      highlighted: emphasized,
      padding: const EdgeInsets.all(AppTheme.space4),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: emphasized
                  ? cs.primary.withValues(alpha: 0.14)
                  : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 20,
              color: emphasized ? cs.primary : cs.onSurface,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(label, style: tt.titleSmall),
          if (value != null) ...[
            const SizedBox(height: 4),
            Text(
              value!,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.84),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GuestMetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const GuestMetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GuestSurfaceCard(
      padding: const EdgeInsets.all(AppTheme.space4),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: tt.titleLarge),
                Text(
                  label,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GuestFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const GuestFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: onTap,
      semanticLabel: label,
      minTouchTargetSize: const Size(44, 36),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GuestMetaPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool emphasized;

  const GuestMetaPill({
    super.key,
    required this.label,
    this.icon,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: emphasized
            ? cs.primary.withValues(alpha: 0.12)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: emphasized ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: emphasized ? cs.primary : cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class GuestStickyActionBar extends StatelessWidget {
  final Widget child;

  const GuestStickyActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space4,
        AppTheme.space2,
        AppTheme.space4,
        AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.14)),
        ),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class GuestStatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const GuestStatePanel({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tone = isError ? cs.error : cs.primary;

    return GuestSurfaceCard(
      padding: const EdgeInsets.all(AppTheme.space6),
      borderRadius: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 24, color: tone),
          ),
          const SizedBox(height: AppTheme.space5),
          Text(title, style: tt.headlineSmall, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: AppTheme.space2),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTheme.space5),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
