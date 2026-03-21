import 'auth_repository.dart';
import 'dinein_api_service.dart';

class MenuImageGenerationResult {
  final String status;
  final String itemId;
  final String venueId;
  final String imageStatus;
  final String? imageUrl;
  final String? reason;
  final String? model;
  final String? error;

  const MenuImageGenerationResult({
    required this.status,
    required this.itemId,
    required this.venueId,
    required this.imageStatus,
    this.imageUrl,
    this.reason,
    this.model,
    this.error,
  });

  bool get didGenerate => status == 'success';

  factory MenuImageGenerationResult.fromJson(Map<String, dynamic> json) {
    return MenuImageGenerationResult(
      status: json['status'] as String? ?? 'unknown',
      itemId: json['itemId'] as String? ?? '',
      venueId: json['venueId'] as String? ?? '',
      imageStatus: json['imageStatus'] as String? ?? 'pending',
      imageUrl: json['imageUrl'] as String?,
      reason: json['reason'] as String?,
      model: json['model'] as String?,
      error: json['error'] as String?,
    );
  }
}

class MenuImageBackfillResult {
  final String status;
  final String? venueId;
  final int attempted;
  final int generated;
  final int skipped;
  final int failed;

  const MenuImageBackfillResult({
    required this.status,
    required this.venueId,
    required this.attempted,
    required this.generated,
    required this.skipped,
    required this.failed,
  });

  factory MenuImageBackfillResult.fromJson(Map<String, dynamic> json) {
    return MenuImageBackfillResult(
      status: json['status'] as String? ?? 'unknown',
      venueId: json['venueId'] as String?,
      attempted: (json['attempted'] as num?)?.toInt() ?? 0,
      generated: (json['generated'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Client wrapper for Supabase functions that own Gemini image generation.
class MenuImageGenerationService {
  MenuImageGenerationService._();

  static final instance = MenuImageGenerationService._();

  Map<String, dynamic> _venueSessionPayload() {
    final session = AuthRepository.instance.currentVenueSession;
    if (session == null) return const {};
    final token = session.accessToken;
    if (token.isNotEmpty) {
      return {
        'venue_session': {'access_token': token},
      };
    }
    return {
      'venue_session': {
        'access_token': session.accessToken,
        'venue_id': session.venueId,
        'contact_phone': session.whatsAppNumber,
      },
    };
  }

  Future<MenuImageGenerationResult> generateForItem({
    required String itemId,
    bool forceRegenerate = false,
  }) async {
    final payload =
        await DineinApiService.invoke(
              'generate_menu_item_image',
              payload: {
                'itemId': itemId,
                'forceRegenerate': forceRegenerate,
                ..._venueSessionPayload(),
              },
            )
            as Map<String, dynamic>;
    return MenuImageGenerationResult.fromJson(payload);
  }

  Future<MenuImageBackfillResult> backfillMissingImages({
    required String venueId,
    int limit = 12,
    bool forceRegenerate = false,
  }) async {
    final payload =
        await DineinApiService.invoke(
              'backfill_menu_images',
              payload: {
                'venueId': venueId,
                'limit': limit,
                'forceRegenerate': forceRegenerate,
                ..._venueSessionPayload(),
              },
            )
            as Map<String, dynamic>;
    return MenuImageBackfillResult.fromJson(payload);
  }
}
