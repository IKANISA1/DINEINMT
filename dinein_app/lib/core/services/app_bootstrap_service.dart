import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../infrastructure/app_notification_service.dart'
    if (dart.library.html) 'app_notification_service_web.dart';
import '../infrastructure/app_telemetry_service.dart'
    if (dart.library.html) 'app_telemetry_service_web.dart';
import 'auth_repository.dart';
import 'supabase_config.dart';
import 'notification_inbox_service.dart';
import 'offline_sync_listener.dart';

enum AppBootstrapPhase { idle, running, ready, failed }

/// Boots core runtime services without blocking the first frame.
class AppBootstrapService extends ChangeNotifier {
  AppBootstrapService._();

  static final instance = AppBootstrapService._();

  AppBootstrapPhase _phase = AppBootstrapPhase.idle;
  Future<void>? _bootstrapFuture;
  Object? _error;
  StackTrace? _stackTrace;

  AppBootstrapPhase get phase => _phase;
  bool get isReady => _phase == AppBootstrapPhase.ready;
  bool get isRunning => _phase == AppBootstrapPhase.running;
  bool get hasError => _phase == AppBootstrapPhase.failed;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

  Future<void> ensureStarted() {
    if (_bootstrapFuture != null) {
      return _bootstrapFuture!;
    }

    _phase = AppBootstrapPhase.running;
    _error = null;
    _stackTrace = null;
    notifyListeners();
    _bootstrapFuture = _bootstrap();
    return _bootstrapFuture!;
  }

  Future<void> retry() {
    _bootstrapFuture = null;
    return ensureStarted();
  }

  Future<void> _bootstrap() async {
    try {
      await SupabaseConfig.initialize();
      await Future.wait<void>([
        AuthRepository.instance.restoreVenueSession(),
        AuthRepository.instance.restoreAdminSession(),
      ]);

      _phase = AppBootstrapPhase.ready;
      notifyListeners();

      SchedulerBinding.instance.addPostFrameCallback((_) {
        unawaited(_finishBackgroundBoot());
      });
    } catch (error, stackTrace) {
      _phase = AppBootstrapPhase.failed;
      _error = error;
      _stackTrace = stackTrace;
      notifyListeners();
      debugPrint('[bootstrap] initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _finishBackgroundBoot() async {
    // Give the first routed screen a moment to settle before kicking off
    // heavier platform integrations that can contend on startup.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    await _runBackgroundStep(
      'notification inbox',
      NotificationInboxService.instance.init,
    );
    await Future<void>.delayed(Duration.zero);

    await _runBackgroundStep(
      'telemetry',
      AppTelemetryService.initialize,
    );
    await Future<void>.delayed(Duration.zero);

    await _runBackgroundStep(
      'push notifications',
      AppNotificationService.initialize,
    );

    // Start listening for offline sync SW messages (web only).
    OfflineSyncListener.instance.init();

    final venueSession = AuthRepository.instance.currentVenueSession;
    if (venueSession != null) {
      await _runBackgroundStep(
        'venue notification sync',
        () => AppNotificationService.handleVenueSessionUpdated(venueSession),
      );
    }
  }

  Future<void> _runBackgroundStep(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('[bootstrap] $label failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @visibleForTesting
  void resetForTest() {
    _phase = AppBootstrapPhase.idle;
    _bootstrapFuture = null;
    _error = null;
    _stackTrace = null;
    notifyListeners();
  }

  @visibleForTesting
  void markReadyForTest() {
    _phase = AppBootstrapPhase.ready;
    _bootstrapFuture = Future<void>.value();
    _error = null;
    _stackTrace = null;
    notifyListeners();
  }
}
