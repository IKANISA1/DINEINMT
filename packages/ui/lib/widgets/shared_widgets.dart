import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ui/theme/app_theme.dart';

import 'pressable_scale.dart';

export 'access_support_dialog.dart';
export 'adaptive_glass_surface.dart';
export 'brand_mark.dart';
export 'dinein_image.dart';
export 'dinein_toast.dart';
export 'guest_pwa.dart';
export 'otp_widgets.dart';
export 'permission_access_dialog.dart';
export 'pressable_scale.dart';
export 'role_switch_footer.dart';

class AppSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? radius;
  final double? width;
  final double? height;
  final Color? color;
  final Color? borderColor;
  final bool elevated;
  final String? semanticLabel;

  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius,
    this.width,
    this.height,
    this.color,
    this.borderColor,
    this.elevated = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius ?? AppTheme.radiusXl),
        border: Border.all(
          color:
              borderColor ??
              cs.outlineVariant.withValues(alpha: elevated ? 0.9 : 0.72),
        ),
        boxShadow: elevated ? AppTheme.elevatedShadow : AppTheme.ambientShadow,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return PressableScale(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: content,
    );
  }
}

class ClayCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final VoidCallback? onTap;
  final bool elevated;
  final bool accentGradient;
  final String? semanticLabel;

  const ClayCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.elevated = false,
    this.accentGradient = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppSurfaceCard(
      padding: padding,
      radius: borderRadius,
      onTap: onTap,
      elevated: elevated,
      semanticLabel: semanticLabel,
      color: accentGradient
          ? Color.alphaBlend(
              cs.primary.withValues(alpha: 0.04),
              cs.surfaceContainerLowest,
            )
          : null,
      child: child,
    );
  }
}

class GlassHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const GlassHeader({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: AppTheme.space4,
            vertical: AppTheme.space3,
          ),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.72)),
        ),
      ),
      child: child,
    );
  }
}

class PremiumButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final bool isSmall;

  const PremiumButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final content = _buildContent(
      context,
      tt.labelLarge?.copyWith(
        fontSize: isSmall ? 13 : 14,
        fontWeight: FontWeight.w700,
      ),
    );

    final style =
        (isOutlined
                ? OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmall ? 14 : 18,
                      vertical: isSmall ? 11 : 14,
                    ),
                    minimumSize: Size(0, isSmall ? 40 : 48),
                  )
                : ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmall ? 14 : 18,
                      vertical: isSmall ? 11 : 14,
                    ),
                    minimumSize: Size(0, isSmall ? 40 : 48),
                  ))
            .copyWith(
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
              ),
            );

    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: content,
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: content,
    );
  }

  Widget _buildContent(BuildContext context, TextStyle? style) {
    final cs = Theme.of(context).colorScheme;
    final color = isOutlined ? cs.onSurface : cs.onPrimary;

    if (isLoading) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }

    if (icon == null) {
      return Text(label, style: style?.copyWith(color: color));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isSmall ? 16 : 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: style?.copyWith(color: color)),
      ],
    );
  }
}

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  final String? semanticLabel;
  final Color? color;
  final double size;
  final double iconSize;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.selected = false,
    this.semanticLabel,
    this.color,
    this.size = 40,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foreground = color ?? (selected ? cs.primary : cs.onSurfaceVariant);
    return PressableScale(
      onTap: onTap,
      semanticLabel: semanticLabel,
      minTouchTargetSize: Size(size, size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
        ),
        child: Icon(icon, size: iconSize, color: foreground),
      ),
    );
  }
}

class AppPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;
  final Color? foregroundColor;
  final bool dense;

  const AppPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
    this.color,
    this.foregroundColor,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final background =
        color ?? (selected ? cs.primaryContainer : cs.surfaceContainerLowest);
    final foreground =
        foregroundColor ??
        (selected ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.92));

    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 14 : 15, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return PressableScale(onTap: onTap, semanticLabel: label, child: chip);
  }
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel!),
                const SizedBox(width: 2),
                Icon(LucideIcons.chevronRight, size: 16, color: cs.primary),
              ],
            ),
          ),
      ],
    );
  }
}

class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            AppIconButton(
              icon: LucideIcons.chevronLeft,
              size: 48,
              iconSize: 20,
              onTap: onBack,
              semanticLabel: 'Go back',
            ),
            const SizedBox(width: AppTheme.space4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.92),
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
    );
  }
}

class AppSectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;

  const AppSectionLabel({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.9),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  const AppSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasValue = controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                border: InputBorder.none,
                filled: false,
                hintText: hintText,
                isCollapsed: true,
              ),
            ),
          ),
          if (hasValue)
            AppIconButton(
              icon: LucideIcons.x,
              size: 32,
              iconSize: 16,
              onTap: onClear,
              semanticLabel: 'Clear search',
            ),
        ],
      ),
    );
  }
}

class AppListTileCard extends StatelessWidget {
  final Widget? leading;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final EdgeInsetsGeometry? padding;

  const AppListTileCard({
    super.key,
    this.leading,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AppSurfaceCard(
      onTap: onTap,
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: AppTheme.space4,
            vertical: AppTheme.space4,
          ),
      child: Row(
        children: [
          leading ??
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, size: 18, color: iconColor ?? cs.primary),
              ),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleMedium),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing ??
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
        ],
      ),
    );
  }
}

class AppMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;

  const AppMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = accent ?? cs.primary;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(AppTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: tone),
            const SizedBox(height: 10),
          ],
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class AppBottomBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppBottomBar({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            AppTheme.space4,
            AppTheme.space2,
            AppTheme.space4,
            AppTheme.space4,
          ),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.72)),
        ),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final bool isPulsing;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.isPulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPill(
      label: label,
      color: color ?? cs.primaryContainer,
      foregroundColor: textColor ?? cs.primary,
      dense: true,
    );
  }
}

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.2 + (2.2 * _controller.value), 0),
              end: Alignment(-0.2 + (2.2 * _controller.value), 0),
              colors: [
                cs.surfaceContainer,
                cs.surfaceContainerHigh,
                cs.surfaceContainer,
              ],
            ),
          ),
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space6),
          child: AppSurfaceCard(
            radius: AppTheme.radiusXxl,
            padding: const EdgeInsets.all(AppTheme.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Icon(icon, size: 24, color: cs.primary),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppTheme.space2),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.84),
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppTheme.space5),
                  PremiumButton(label: actionLabel!, onPressed: onAction),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space6),
          child: AppSurfaceCard(
            radius: AppTheme.radiusXxl,
            padding: const EdgeInsets.all(AppTheme.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Icon(
                    LucideIcons.alertCircle,
                    size: 24,
                    color: cs.error,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.space2),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.84),
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: AppTheme.space5),
                  PremiumButton(
                    label: 'Try again',
                    onPressed: onRetry,
                    isOutlined: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
