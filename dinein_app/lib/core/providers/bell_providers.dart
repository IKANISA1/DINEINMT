import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bell_request.dart';
import '../services/bell_repository.dart';

/// Stream of ALL pending waves for a given venue. Used by venue admin.
final pendingWavesProvider = StreamProvider.family<List<BellRequest>, String>((ref, venueId) {
  return BellRepository.instance.pendingWavesStream(venueId);
});

/// Stream of ALL waves (pending + resolved) for venue history view.
final allWavesProvider = StreamProvider.family<List<BellRequest>, String>((ref, venueId) {
  return BellRepository.instance.allWavesStream(venueId);
});
