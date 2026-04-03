import 'package:equatable/equatable.dart';

import 'models.dart';

class GuestVenueFeed extends Equatable {
  final List<Venue> items;
  final List<String> categories;
  final int totalCount;
  final bool hasMore;

  const GuestVenueFeed({
    required this.items,
    this.categories = const [],
    required this.totalCount,
    this.hasMore = false,
  });

  factory GuestVenueFeed.fromVenues(List<Venue> items) {
    final categories =
        items
            .map((venue) => venue.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return GuestVenueFeed(
      items: items,
      categories: categories,
      totalCount: items.length,
      hasMore: false,
    );
  }

  @override
  List<Object?> get props => [items, categories, totalCount, hasMore];
}
