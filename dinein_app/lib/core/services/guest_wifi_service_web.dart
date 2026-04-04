import 'package:db_pkg/models/models.dart';

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
    return const GuestWifiConnectResult.fallback(
      'Automatic WiFi connection is not available in the browser. Use the WiFi details instead.',
    );
  }
}
