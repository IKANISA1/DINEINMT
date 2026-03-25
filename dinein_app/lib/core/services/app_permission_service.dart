import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

typedef PermissionStatusReader =
    Future<PermissionStatus> Function(Permission permission);
typedef PermissionRequester =
    Future<PermissionStatus> Function(Permission permission);
typedef OpenSettingsCallback = Future<bool> Function();

class AppPermissionService {
  AppPermissionService({
    PermissionStatusReader? readStatus,
    PermissionRequester? requestPermission,
    OpenSettingsCallback? openSettings,
  }) : _readStatus = readStatus ?? _defaultReadStatus,
       _requestPermission = requestPermission ?? _defaultRequestPermission,
       _openSettings = openSettings ?? openAppSettings;

  static final instance = AppPermissionService();

  final PermissionStatusReader _readStatus;
  final PermissionRequester _requestPermission;
  final OpenSettingsCallback _openSettings;

  Future<bool> isGuestLocationGranted() async {
    final status = await _safeReadStatus(Permission.locationWhenInUse);
    return status.isGranted;
  }

  Future<bool> ensureGuestWifiLocationAccess() async {
    if (Platform.isAndroid) {
      final hasLocationAccess = await _ensureActionPermission(
        Permission.locationWhenInUse,
      );
      if (!hasLocationAccess) return false;
      return _ensureActionPermission(Permission.nearbyWifiDevices);
    }

    if (Platform.isIOS) {
      return _ensureActionPermission(Permission.locationWhenInUse);
    }

    return true;
  }

  Future<bool> openAppPermissionSettings() => _openSettings();

  Future<bool> ensureVenueCameraAccess() {
    if (Platform.isAndroid) {
      return Future.value(true);
    }
    if (Platform.isIOS) {
      return _ensureActionPermission(Permission.camera);
    }
    return Future.value(true);
  }

  Future<bool> ensureBiopayCameraAccess() {
    if (Platform.isAndroid || Platform.isIOS) {
      return _ensureActionPermission(Permission.camera);
    }
    return Future.value(true);
  }

  Future<bool> ensureVenuePhotoAccess() {
    // Venue uploads use system pickers, so no broad media permission is needed.
    return Future.value(true);
  }

  Future<bool> _ensureActionPermission(Permission permission) async {
    final currentStatus = await _safeReadStatus(permission);
    if (currentStatus.isGranted || currentStatus.isLimited) {
      return true;
    }

    if (currentStatus.isPermanentlyDenied || currentStatus.isRestricted) {
      await _openSettings();
      return false;
    }

    final requestedStatus = await _safeRequestPermission(permission);
    if (requestedStatus.isGranted || requestedStatus.isLimited) {
      return true;
    }

    if (requestedStatus.isPermanentlyDenied || requestedStatus.isRestricted) {
      await _openSettings();
    }

    return false;
  }

  Future<PermissionStatus> _safeReadStatus(Permission permission) async {
    try {
      return await _readStatus(permission);
    } on MissingPluginException {
      return PermissionStatus.granted;
    } on UnimplementedError {
      return PermissionStatus.granted;
    }
  }

  Future<PermissionStatus> _safeRequestPermission(Permission permission) async {
    try {
      return await _requestPermission(permission);
    } on MissingPluginException {
      return PermissionStatus.granted;
    } on UnimplementedError {
      return PermissionStatus.granted;
    }
  }

  static Future<PermissionStatus> _defaultReadStatus(
    Permission permission,
  ) async {
    return permission.status;
  }

  static Future<PermissionStatus> _defaultRequestPermission(
    Permission permission,
  ) async {
    return permission.request();
  }
}
