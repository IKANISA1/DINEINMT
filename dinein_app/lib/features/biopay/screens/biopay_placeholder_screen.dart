import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/widgets/shared_widgets.dart';

class BiopayPlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const BiopayPlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: LucideIcons.sparkles,
        title: title,
        subtitle: subtitle,
        actionLabel: 'GO BACK',
        onAction: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
