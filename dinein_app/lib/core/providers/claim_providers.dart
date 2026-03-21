import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/claim_repository.dart';

/// Pending venue claims (admin view).
final pendingClaimsProvider = FutureProvider<List<VenueClaim>>((ref) async {
  return await ClaimRepository.instance.getPendingClaims();
});
