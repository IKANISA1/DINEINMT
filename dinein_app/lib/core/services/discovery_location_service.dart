import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class DiscoveryCoordinates {
  final double latitude;
  final double longitude;

  const DiscoveryCoordinates({required this.latitude, required this.longitude});
}

class DiscoveryLocationService {
  DiscoveryLocationService._();

  static final instance = DiscoveryLocationService._();

  Future<DiscoveryCoordinates?> getCurrentLocation({
    bool requestIfNeeded = false,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestIfNeeded) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );

    return DiscoveryCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}

final discoveryLocationServiceProvider = Provider<DiscoveryLocationService>((
  ref,
) {
  return DiscoveryLocationService.instance;
});

final discoveryLocationProvider = FutureProvider<DiscoveryCoordinates?>((ref) {
  return ref
      .watch(discoveryLocationServiceProvider)
      .getCurrentLocation(requestIfNeeded: false);
});
