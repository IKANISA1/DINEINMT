import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/guest_wifi_service.dart'
    if (dart.library.js_interop) '../services/guest_wifi_service_web.dart';

final guestWifiServiceProvider = Provider<GuestWifiService>((ref) {
  return GuestWifiService.instance;
});
