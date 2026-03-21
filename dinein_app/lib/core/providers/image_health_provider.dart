import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/dinein_api_service.dart';

/// Aggregated image generation health stats.
class ImageHealthStats {
  final int total;
  final int ready;
  final int pending;
  final int generating;
  final int failed;

  const ImageHealthStats({
    required this.total,
    required this.ready,
    required this.pending,
    required this.generating,
    required this.failed,
  });

  double get readyPercent => total > 0 ? ready / total * 100 : 0;

  factory ImageHealthStats.fromJson(Map<String, dynamic> json) {
    return ImageHealthStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      ready: (json['ready'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      generating: (json['generating'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Provider for image generation health stats (admin-only).
final imageHealthProvider = FutureProvider<ImageHealthStats>((ref) async {
  final data = await DineinApiService.invoke(
    'image_health',
    useAdminSession: true,
  );
  return ImageHealthStats.fromJson(data as Map<String, dynamic>);
});
