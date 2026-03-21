import 'package:equatable/equatable.dart';

enum WaveStatus {
  pending,
  resolved;

  String get dbValue => name;
  static WaveStatus fromString(String val) => values.firstWhere(
        (e) => e.name == val,
        orElse: () => WaveStatus.pending,
      );
}

class BellRequest extends Equatable {
  final String id;
  final String venueId;
  final String? userId;
  final String tableNumber;
  final WaveStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const BellRequest({
    required this.id,
    required this.venueId,
    this.userId,
    required this.tableNumber,
    this.status = WaveStatus.pending,
    required this.createdAt,
    this.resolvedAt,
  });

  factory BellRequest.fromJson(Map<String, dynamic> json) {
    return BellRequest(
      id: json['id'] as String,
      venueId: json['venue_id'] as String,
      userId: json['user_id'] as String?,
      tableNumber: json['table_number'] as String,
      status: WaveStatus.fromString(json['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'venue_id': venueId,
    'user_id': userId,
    'table_number': tableNumber,
    'status': status.dbValue,
  };

  @override
  List<Object?> get props => [id, venueId, userId, tableNumber, status, createdAt, resolvedAt];
}
