import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dinein_app/core/infrastructure/app_permission_service.dart';

final appPermissionServiceProvider = Provider<AppPermissionService>(
  (ref) => AppPermissionService.instance,
);
