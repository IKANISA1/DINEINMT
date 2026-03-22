import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_permission_service.dart';

final appPermissionServiceProvider = Provider<AppPermissionService>(
  (ref) => AppPermissionService.instance,
);
