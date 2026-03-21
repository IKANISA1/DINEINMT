import '../models/bell_request.dart';
import 'auth_repository.dart';
import 'dinein_api_service.dart';

class BellRepository {
  static final BellRepository instance = BellRepository._();
  BellRepository._();

  static const _pollInterval = Duration(seconds: 4);

  Map<String, dynamic> _venueSessionPayload() {
    final session = AuthRepository.instance.currentVenueSession;
    if (session == null || session.accessToken.isEmpty) return const {};
    return {
      'venue_session': {'access_token': session.accessToken},
    };
  }

  Future<void> sendWave({
    required String venueId,
    required String tableNumber,
    String? userId,
  }) async {
    await DineinApiService.invoke(
      'send_wave',
      payload: {
        'venueId': venueId,
        'tableNumber': tableNumber,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      },
    );
  }

  Future<void> resolveWave(String requestId) async {
    await DineinApiService.invoke(
      'resolve_bell_request',
      payload: {'requestId': requestId, ..._venueSessionPayload()},
    );
  }

  Future<List<BellRequest>> getBellRequests(
    String venueId, {
    WaveStatus? status,
  }) async {
    final data =
        await DineinApiService.invoke(
              'get_bell_requests',
              payload: {
                'venueId': venueId,
                if (status != null) 'status': status.dbValue,
                ..._venueSessionPayload(),
              },
            )
            as List<dynamic>;
    return data
        .map((row) => BellRequest.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Stream<List<BellRequest>> pendingWavesStream(String venueId) =>
      _pollBellRequests(venueId, status: WaveStatus.pending);

  Stream<List<BellRequest>> allWavesStream(String venueId) =>
      _pollBellRequests(venueId);

  Stream<List<BellRequest>> _pollBellRequests(
    String venueId, {
    WaveStatus? status,
  }) async* {
    yield await getBellRequests(venueId, status: status);
    yield* Stream<List<BellRequest>>.periodic(
      _pollInterval,
    ).asyncMap((_) => getBellRequests(venueId, status: status));
  }
}
