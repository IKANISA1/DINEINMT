import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/app_telemetry_service.dart';
import 'core/services/auth_repository.dart';
import 'core/services/supabase_config.dart';
import 'core/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppTelemetryService.initialize();
  await SupabaseConfig.initialize();
  await AuthRepository.instance.restoreVenueSession();
  await AuthRepository.instance.restoreAdminSession();
  // Pre-load saved theme BEFORE first frame to prevent flicker.
  await ThemeNotifier.loadSavedTheme();
  runApp(const ProviderScope(child: DineInApp()));
}

/// Root widget for the DineIn Malta app.
class DineInApp extends ConsumerWidget {
  const DineInApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'DINEIN MALTA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      // Keep scroll chrome visually quiet across the supported mobile app.
      scrollBehavior: const _NoScrollbarBehavior(),
    );
  }
}

/// Custom scroll behavior that suppresses scrollbars for full-screen surfaces.
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
