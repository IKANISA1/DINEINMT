import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/guest_wifi_service.dart';

final guestWifiServiceProvider = Provider<GuestWifiService>((ref) {
  return GuestWifiService.instance;
});
