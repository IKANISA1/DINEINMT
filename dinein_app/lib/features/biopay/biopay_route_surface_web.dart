// ignore_for_file: unused_field

import 'package:flutter/material.dart';

export 'models/biopay_models.dart';

class BiopayHomeScreen extends StatelessWidget {
  const BiopayHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _UnsupportedBioPayScreen(
      title: 'BioPay is app only',
      subtitle:
          'Face registration and face scan payments stay inside the native mobile apps.',
    );
  }
}

class BiopayRegisterScreen extends StatelessWidget {
  const BiopayRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _UnsupportedBioPayScreen(
      title: 'BioPay registration is app only',
      subtitle:
          'Browser users can continue with guest, venue, and admin flows.',
    );
  }
}

class BiopayScannerScreen extends StatelessWidget {
  const BiopayScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _UnsupportedBioPayScreen(
      title: 'BioPay scan is app only',
      subtitle:
          'The browser version does not include camera-based face matching.',
    );
  }
}

class BiopayConfirmScreen extends StatelessWidget {
  final dynamic matchResult;

  const BiopayConfirmScreen({super.key, this.matchResult});

  @override
  Widget build(BuildContext context) {
    return const _UnsupportedBioPayScreen(
      title: 'BioPay confirmation is app only',
      subtitle:
          'Face-matched payment confirmation stays in the native mobile apps.',
    );
  }
}

class BiopayReEnrollScreen extends StatelessWidget {
  const BiopayReEnrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _UnsupportedBioPayScreen(
      title: 'BioPay re-enroll is app only',
      subtitle:
          'Re-enrolling face templates is only available in the mobile apps.',
    );
  }
}

class BiopayManageScreen extends StatelessWidget {
  const BiopayManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _UnsupportedBioPayScreen(
      title: 'BioPay management is app only',
      subtitle:
          'The browser app does not manage face profiles or device tokens.',
    );
  }
}

class _UnsupportedBioPayScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const _UnsupportedBioPayScreen({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('BioPay')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.no_accounts_outlined, size: 72, color: cs.primary),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
