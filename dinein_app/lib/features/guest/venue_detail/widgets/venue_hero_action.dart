import 'package:flutter/material.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/widgets/shared_widgets.dart';

class VenueHeroAction extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const VenueHeroAction({super.key, required this.icon, this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Hero action',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.white10),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
      ),
    );
  }
}

