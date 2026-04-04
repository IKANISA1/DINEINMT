import 'dart:io';

import 'package:op_wifi_utils/op_wifi_utils.dart';

import 'package:db_pkg/models/models.dart';
import 'app_permission_service.dart';

enum GuestWifiConnectStatus { connected, fallbackRequired, unavailable }

class GuestWifiConnectResult {
  final GuestWifiConnectStatus status;
  final String message;

  const GuestWifiConnectResult._({required this.status, required this.message});

  const GuestWifiConnectResult.connected(String message)
    : this._(status: GuestWifiConnectStatus.connected, message: message);

  const GuestWifiConnectResult.fallback(String message)
    : this._(status: GuestWifiConnectStatus.fallbackRequired, message: message);

  const GuestWifiConnectResult.unavailable(String message)
    : this._(status: GuestWifiConnectStatus.unavailable, message: message);

  bool get shouldShowManualFallback =>
      status == GuestWifiConnectStatus.fallbackRequired;
}

class GuestWifiService {
  GuestWifiService();

  static final instance = GuestWifiService();

  Future<GuestWifiConnectResult> connectToVenueWifi(Venue venue) async {
    final ssid = venue.wifiSsid?.trim() ?? '';
    if (ssid.isEmpty) {
      return const GuestWifiConnectResult.unavailable(
        'This venue has not shared a WiFi network name yet.',
      );
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      return const GuestWifiConnectResult.fallback(
        'Auto-connect is not available on this device. Use the WiFi details instead.',
      );
    }

    final hasLocationAccess = await AppPermissionService.instance
        .ensureGuestWifiLocationAccess();
    if (!hasLocationAccess) {
      return const GuestWifiConnectResult.fallback(
        'Allow location and nearby WiFi access if you want DineIn to join venue WiFi automatically, or use the WiFi details instead.',
      );
    }

    final availability = await OpWifiUtils.isAvailable();
    if (availability.isFailure || availability.data == false) {
      return const GuestWifiConnectResult.fallback(
        'Automatic WiFi connection is unavailable right now. Use the WiFi details instead.',
      );
    }

    final password = venue.wifiPassword?.trim();
    final security = (venue.wifiSecurity ?? 'WPA').trim().toUpperCase();
    final usesOpenNetwork = security == 'OPEN';

    if (!usesOpenNetwork && (password == null || password.isEmpty)) {
      return const GuestWifiConnectResult.fallback(
        'This venue WiFi is missing a password. Use the WiFi details instead.',
      );
    }

    final result = await OpWifiUtils.connectToWifi(
      ssid: ssid,
      password: usesOpenNetwork ? null : password,
      joinOnce: true,
    );

    if (result.isSuccess) {
      return GuestWifiConnectResult.connected('Connected to $ssid.');
    }

    final errorType = result.error.type;
    if (errorType is! OpWifiUtilsError) {
      return const GuestWifiConnectResult.fallback(
        'Could not join automatically. Use the WiFi details instead.',
      );
    }

    final message = switch (errorType) {
      OpWifiUtilsError.alreadyConnected => 'Already connected to $ssid.',
      OpWifiUtilsError.invalidPassword =>
        'The saved WiFi password looks invalid. Use the WiFi details instead.',
      OpWifiUtilsError.permissionRequired =>
        'Allow location and nearby WiFi access if you want DineIn to join venue WiFi automatically, or use the WiFi details instead.',
      OpWifiUtilsError.deviceLocationDisabled =>
        'Turn on Location Services if you want DineIn to join venue WiFi automatically, or use the WiFi details instead.',
      OpWifiUtilsError.unavailable ||
      OpWifiUtilsError.readyTimeout ||
      OpWifiUtilsError.osUnknown ||
      OpWifiUtilsError.neHotspotUnknown ||
      OpWifiUtilsError.unknownError =>
        'Could not join automatically. Use the WiFi details instead.',
      OpWifiUtilsError.unsupportedPlatform =>
        'Auto-connect is not available on this device. Use the WiFi details instead.',
      OpWifiUtilsError.invalidSsid || OpWifiUtilsError.ssidMissing =>
        'This venue WiFi setup is incomplete. Use the WiFi details instead.',
      OpWifiUtilsError.unknownCurrentSsid =>
        'Joined the network, but the device could not confirm the current WiFi.',
    };

    if (errorType == OpWifiUtilsError.unknownCurrentSsid) {
      return GuestWifiConnectResult.connected(message);
    }

    return GuestWifiConnectResult.fallback(message);
  }
}
