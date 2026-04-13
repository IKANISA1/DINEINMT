import 'package:flutter/material.dart';
import 'package:ui/widgets/shared_widgets.dart';

class VenueHeroAction extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const VenueHeroAction({
    super.key,
    required this.icon,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: icon,
      onTap: onTap,
      color: iconColor ?? Colors.white,
      semanticLabel: 'Hero action',
      size: 44,
      iconSize: 18,
    );
  }
}
