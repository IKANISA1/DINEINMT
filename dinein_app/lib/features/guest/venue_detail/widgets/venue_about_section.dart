import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:db_pkg/models/models.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class VenueAboutSection extends StatelessWidget {
  final Venue venue;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onCall;
  final VoidCallback? onMaps;
  final VoidCallback? onWifiTap;

  const VenueAboutSection({
    super.key,
    required this.venue,
    required this.isExpanded,
    required this.onToggle,
    required this.onCall,
    required this.onMaps,
    required this.onWifiTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final description = venue.description.trim().isEmpty
        ? 'Venue details coming soon.'
        : venue.description.trim();

    return GuestSurfaceCard(
      padding: const EdgeInsets.all(AppTheme.space5),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PressableScale(
            onTap: onToggle,
            semanticLabel: 'Toggle about section',
            child: Row(
              children: [
                Expanded(
                  child: GuestSectionHeader(
                    title: 'About',
                    subtitle: venue.guestAvailabilityReason,
                  ),
                ),
                AppIconButton(
                  icon: LucideIcons.chevronDown,
                  selected: isExpanded,
                  onTap: onToggle,
                  semanticLabel: 'Toggle about section',
                  size: 36,
                  iconSize: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white.withValues(alpha: 0)],
                stops: const [0.52, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.74),
                  height: 1.6,
                ),
              ),
            ),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppTheme.space3),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (venue.phone != null && venue.phone!.trim().isNotEmpty)
                      VenueDetailChip(
                        icon: LucideIcons.phone,
                        label: venue.phone!,
                        onTap: onCall,
                      ),

                    if (venue.googleMapsUri != null)
                      VenueDetailChip(
                        icon: LucideIcons.mapPin,
                        label: 'Map',
                        onTap: onMaps,
                      ),
                    if (venue.priceLevelLabel != null)
                      VenueDetailChip(
                        icon: LucideIcons.badgeDollarSign,
                        label: venue.priceLevelLabel!,
                      ),
                    if (venue.hasWifi && !kIsWeb)
                      VenueDetailChip(
                        icon: LucideIcons.wifi,
                        label: 'Connect Wi-Fi',
                        onTap: onWifiTap,
                        isPrimary: true,
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
}

class VenueDetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  const VenueDetailChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final background = isPrimary ? cs.primary : cs.surfaceContainerHigh;
    final foreground = isPrimary ? cs.onPrimary : cs.primary;
    final textColor = isPrimary ? cs.onPrimary : cs.onSurface;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isPrimary
              ? Colors.transparent
              : cs.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return PressableScale(onTap: onTap, semanticLabel: label, child: content);
  }
}
