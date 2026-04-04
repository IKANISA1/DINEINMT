import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:db_pkg/models/models.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class VenueAboutSection extends StatelessWidget {
  final Venue venue;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onCall;
  final VoidCallback? onWebsite;
  final VoidCallback? onMaps;
  final VoidCallback? onWifiTap;

  const VenueAboutSection({super.key, 
    required this.venue,
    required this.isExpanded,
    required this.onToggle,
    required this.onCall,
    required this.onWebsite,
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

    return Container(
      padding: const EdgeInsets.all(AppTheme.space8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: AppColors.white5),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PressableScale(
            onTap: onToggle,
            semanticLabel: 'Toggle about section',
            child: Row(
              children: [
                Expanded(child: Text('About', style: tt.headlineMedium)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isExpanded ? cs.primary : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 400),
                    turns: isExpanded ? 0.5 : 0,
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: isExpanded ? cs.onPrimary : cs.primary,
                    ),
                  ),
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
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
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
                const SizedBox(height: AppTheme.space4),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    VenueDetailChip(
                      icon: LucideIcons.clock3,
                      label: venueOpeningHoursLabel(venue),
                    ),
                    if (venue.phone != null && venue.phone!.trim().isNotEmpty)
                      VenueDetailChip(
                        icon: LucideIcons.phone,
                        label: venue.phone!,
                        onTap: onCall,
                      ),
                    if (venue.websiteUri != null)
                      VenueDetailChip(
                        icon: LucideIcons.globe,
                        label: 'Website',
                        onTap: onWebsite,
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
                        label: 'Connect to Wifi',
                        onTap: onWifiTap,
                        isPrimary: true,
                      ),
                  ],
                ),
                if (venue.primaryReviewSnippet != null) ...[
                  const SizedBox(height: AppTheme.space5),
                  Text(
                    'WHAT GUESTS NOTICE',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    venue.primaryReviewSnippet!,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.82),
                      height: 1.55,
                    ),
                  ),
                ],
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

  const VenueDetailChip({super.key, 
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isPrimary ? Colors.transparent : AppColors.white5,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.20),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return PressableScale(onTap: onTap, semanticLabel: label, child: content);
  }
}


String venueOpeningHoursLabel(Venue venue) {
  final hours = venue.openingHours;
  if (hours == null || hours.isEmpty) {
    return venue.isOpen ? 'Open Now' : 'Closed';
  }

  const weekdayNames = <int, String>{
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };

  final today = weekdayNames[DateTime.now().weekday];
  final todayHours = today == null ? null : hours[today];
  if (todayHours == null) {
    return venue.isOpen ? 'Open Now' : 'Closed';
  }
  if (!todayHours.isOpen) return 'Closed Today';
  if (todayHours.close.trim().isEmpty) return 'Open Today';
  return 'Open until ${formatHours(todayHours.close)}';
}


String formatHours(String raw) {
  final parts = raw.split(':');
  if (parts.length < 2) return raw.toUpperCase();

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return raw.toUpperCase();

  final normalizedHour = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final minutePart = minute == 0 ? '' : ':${minute.toString().padLeft(2, '0')}';
  return '$normalizedHour$minutePart $suffix';
}
