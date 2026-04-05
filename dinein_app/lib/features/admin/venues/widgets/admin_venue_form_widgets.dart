import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ui/theme/app_theme.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'package:dinein_app/shared/widgets/branded_qr_tools.dart';

/// Reusable section card with an uppercased title label.
class AdminVenueSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const AdminVenueSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ClayCard(
      padding: const EdgeInsets.all(AppTheme.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          ...children,
        ],
      ),
    );
  }
}

/// Standard labeled text field for venue forms.
class AdminVenueLabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const AdminVenueLabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

/// Inline text field used within bottom sheets (e.g. time editors).
class AdminVenueInlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const AdminVenueInlineField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

/// Row displaying a URL with copy and open actions.
class AdminVenueLinkAccessRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;
  final VoidCallback onOpen;

  const AdminVenueLinkAccessRow({
    super.key,
    required this.label,
    required this.value,
    required this.onCopy,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space2),
          Column(
            children: [
              PressableScale(
                onTap: onCopy,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.copy, size: 16, color: cs.onSurface),
                ),
              ),
              const SizedBox(height: 6),
              PressableScale(
                onTap: onOpen,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.externalLink,
                    size: 16,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact QR code preview card that opens a sheet on tap.
class AdminVenueQrPreviewCard extends StatelessWidget {
  final String label;
  final Uri uri;
  final VoidCallback onTap;

  const AdminVenueQrPreviewCard({
    super.key,
    required this.label,
    required this.uri,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            IgnorePointer(child: BrandedQrPoster(uri: uri, compact: true)),
            const SizedBox(height: AppTheme.space3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Value object for a single day's opening hours.
class DayHours {
  final bool isOpen;
  final String open;
  final String close;

  const DayHours({
    required this.isOpen,
    required this.open,
    required this.close,
  });

  DayHours copyWith({bool? isOpen, String? open, String? close}) {
    return DayHours(
      isOpen: isOpen ?? this.isOpen,
      open: open ?? this.open,
      close: close ?? this.close,
    );
  }

  Map<String, dynamic> toJson() => {
    'is_open': isOpen,
    'open': open,
    'close': close,
  };
}

/// Animated status indicator dot.
class AdminStatusDot extends StatelessWidget {
  final String status;

  const AdminStatusDot({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppColors.secondary,
      'suspended' => Theme.of(context).colorScheme.error,
      'maintenance' => AppColors.warning,
      _ => Theme.of(context).colorScheme.onSurface,
    };

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.50), blurRadius: 16),
        ],
      ),
    );
  }
}

/// Individual status toggle button for venue operations.
class AdminStatusButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const AdminStatusButton({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final textColor = isSelected
        ? selectedColor
        : cs.onSurface.withValues(alpha: 0.40);

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.10)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : cs.outlineVariant.withValues(alpha: 0.10),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.10),
                    blurRadius: 32,
                  ),
                ]
              : AppTheme.clayShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.20)
                    : cs.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(icon, size: 24, color: textColor),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: textColor.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(LucideIcons.checkCircle2, size: 24, color: selectedColor),
          ],
        ),
      ),
    );
  }
}
