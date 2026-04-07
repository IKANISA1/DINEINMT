import 'package:equatable/equatable.dart';

import 'models.dart';

class GuestVenueFeed extends Equatable {
  final List<Venue> items;
  final int totalCount;
  final bool hasMore;

  const GuestVenueFeed({
    required this.items,
    required this.totalCount,
    this.hasMore = false,
  });

  /// Kept for backward compatibility — categories are no longer differentiated.
  List<String> get categories => const [];

  factory GuestVenueFeed.fromVenues(List<Venue> items) {
    return GuestVenueFeed(
      items: items,
      totalCount: items.length,
      hasMore: false,
    );
  }

  @override
  List<Object?> get props => [items, totalCount, hasMore];
}
