import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../infrastructure/app_notification_service.dart'
    if (dart.library.js_interop) 'app_notification_service_web.dart';
import '../infrastructure/app_telemetry_service.dart'
    if (dart.library.js_interop) 'app_telemetry_service_web.dart';
import 'auth_repository.dart';
import 'supabase_config.dart';
import 'offline_sync_listener.dart';

enum AppBootstrapPhase { idle, running, ready, failed }

class AppStartupProfile {
  final bool restoreVenueSession;
  final bool restoreAdminSession;
  final bool initializeTelemetry;
  final bool enableOfflineSyncListener;
  final Duration backgroundBootDelay;

  const AppStartupProfile({
    required this.restoreVenueSession,
    required this.restoreAdminSession,
    required this.initializeTelemetry,
    required this.enableOfflineSyncListener,
    required this.backgroundBootDelay,
  });

  const AppStartupProfile.defaultProfile()
    : this(
        restoreVenueSession: true,
        restoreAdminSession: true,
        initializeTelemetry: true,
        enableOfflineSyncListener: true,
        backgroundBootDelay: const Duration(milliseconds: 250),
      );

  const AppStartupProfile.guestWeb()
    : this(
        restoreVenueSession: false,
        restoreAdminSession: false,
        initializeTelemetry: false,
        enableOfflineSyncListener: false,
        backgroundBootDelay: const Duration(milliseconds: 1500),
      );

  const AppStartupProfile.venueWeb()
    : this(
        restoreVenueSession: true,
        restoreAdminSession: false,
        initializeTelemetry: false,
        enableOfflineSyncListener: false,
        backgroundBootDelay: const Duration(milliseconds: 600),
      );

  const AppStartupProfile.adminWeb()
    : this(
        restoreVenueSession: false,
        restoreAdminSession: true,
        initializeTelemetry: false,
        enableOfflineSyncListener: false,
        backgroundBootDelay: const Duration(milliseconds: 600),
      );
}

/// Boots core runtime services without blocking the first frame.
class AppBootstrapService extends ChangeNotifier {
  AppBootstrapService._();

  static final instance = AppBootstrapService._();

  AppBootstrapPhase _phase = AppBootstrapPhase.idle;
  Future<void>? _bootstrapFuture;
  Object? _error;
  StackTrace? _stackTrace;
  AppStartupProfile _profile = const AppStartupProfile.defaultProfile();

  AppBootstrapPhase get phase => _phase;
  bool get isReady => _phase == AppBootstrapPhase.ready;
  bool get isRunning => _phase == AppBootstrapPhase.running;
  bool get hasError => _phase == AppBootstrapPhase.failed;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

  Future<void> ensureStarted({
    AppStartupProfile profile = const AppStartupProfile.defaultProfile(),
  }) {
    if (_bootstrapFuture != null) {
      return _bootstrapFuture!;
    }

    _profile = profile;
    _phase = AppBootstrapPhase.running;
    _error = null;
    _stackTrace = null;
    notifyListeners();
    _bootstrapFuture = _bootstrap();
    return _bootstrapFuture!;
  }

  Future<void> retry() {
    _bootstrapFuture = null;
    return ensureStarted(profile: _profile);
  }

  Future<void> _bootstrap() async {
    try {
      await SupabaseConfig.initialize();
      final restoreSteps = <Future<void>>[];
      if (_profile.restoreVenueSession) {
        restoreSteps.add(AuthRepository.instance.restoreVenueSession());
      }
      if (_profile.restoreAdminSession) {
        restoreSteps.add(AuthRepository.instance.restoreAdminSession());
      }
      if (restoreSteps.isNotEmpty) {
        await Future.wait<void>(restoreSteps);
      }

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
    // Let the first routed screen settle before any non-critical startup work.
    await Future<void>.delayed(_profile.backgroundBootDelay);

    if (_profile.initializeTelemetry) {
      await _runBackgroundStep('telemetry', AppTelemetryService.initialize);
      await Future<void>.delayed(Duration.zero);
    }

    if (_profile.enableOfflineSyncListener) {
      OfflineSyncListener.instance.init();
    }

    final venueSession = AuthRepository.instance.currentVenueSession;
    if (_profile.restoreVenueSession && venueSession != null) {
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
    _profile = const AppStartupProfile.defaultProfile();
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
