// This screen has been deprecated and removed.
// Opening hours are no longer supported in DineIn.
// Kept as a stub to avoid broken imports during cleanup.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VenueHoursScreen extends ConsumerWidget {
  const VenueHoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('This feature is no longer available.')),
    );
  }
}
