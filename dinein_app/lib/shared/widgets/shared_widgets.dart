import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'pressable_scale.dart';
export 'pressable_scale.dart';
export 'adaptive_glass_surface.dart';
export 'dinein_image.dart';
export 'brand_mark.dart';
export 'permission_access_dialog.dart';
export 'wave_bottom_sheet.dart';
export 'otp_widgets.dart';
export 'role_switch_footer.dart';
export 'access_support_dialog.dart';

/// Claymorphic card — the signature DineIn interactive surface.
///
/// Design spec: tonal fill, no borders, ambient shadow (4% blur 32px).
/// Optional gradient accent from primary.
/// When [onTap] is provided, wraps in [PressableScale] for whileTap feel
/// and animates shadow between ambient → elevated on press.
class ClayCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final VoidCallback? onTap;
  final bool elevated;
  final bool accentGradient;

  const ClayCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.elevated = false,
    this.accentGradient = false,
  });

  @override
  State<ClayCard> createState() => _ClayCardState();
}

class _ClayCardState extends State<ClayCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = widget.borderRadius ?? AppTheme.radiusXl;

    // Shadow shifts on press: ambient → elevated (clay hover effect)
    final shadow = widget.elevated || _isPressed
        ? AppTheme.elevatedShadow
        : AppTheme.ambientShadow;

    final container = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: widget.padding ?? const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
        gradient: widget.accentGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.surfaceContainerLowest,
                  cs.primary.withValues(alpha: 0.03),
                ],
              )
            : null,
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: PressableScale(onTap: widget.onTap, child: container),
      );
    }

    return container;
  }
}

/// Glass-style header for overlays and sticky bars.
///
/// Design spec: 70% surface opacity, backdrop blur feel via border.
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
            horizontal: AppTheme.space6,
            vertical: AppTheme.space4,
          ),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.08)),
        ),
      ),
      child: child,
    );
  }
}

/// Premium pill button — branded CTA with optional icon.
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final verticalPad = isSmall ? 12.0 : 18.0;
    final horizontalPad = isSmall ? 20.0 : 32.0;
    final fontSize = isSmall ? 10.0 : 12.0;

    final textStyle = tt.labelSmall?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: 3,
      fontSize: fontSize,
    );

    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15)),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPad,
            vertical: verticalPad,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
        ),
        child: _buildContent(textStyle, cs.onSurface),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPad,
          vertical: verticalPad,
        ),
      ),
      child: _buildContent(textStyle, cs.onPrimary),
    );
  }

  Widget _buildContent(TextStyle? style, Color color) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style?.copyWith(color: color)),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: color),
        ],
      );
    }

    return Text(label, style: style?.copyWith(color: color));
  }
}

/// Status badge chip for order/venue status.
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
    final bgColor = color ?? cs.primaryContainer.withValues(alpha: 0.20);
    final fgColor = textColor ?? cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: fgColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Skeleton shimmer loader for content placeholders.
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
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 1, 0),
              colors: [
                cs.surfaceContainerHigh,
                cs.surfaceContainerHighest,
                cs.surfaceContainerHigh,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Empty state placeholder widget.
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
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.space6),
            Text(title, style: tt.headlineSmall, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.space2),
              Text(
                subtitle!,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.space6),
              PremiumButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state placeholder widget.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_rounded, size: 36, color: cs.error),
            ),
            const SizedBox(height: AppTheme.space6),
            Text(
              'Something went wrong',
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space2),
            Text(
              message,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.space6),
              PremiumButton(
                label: 'TRY AGAIN',
                onPressed: onRetry,
                isOutlined: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
