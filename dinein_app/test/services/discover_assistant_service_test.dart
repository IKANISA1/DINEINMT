import 'package:dinein_app/core/constants/enums.dart';
import 'package:dinein_app/core/models/models.dart';
import 'package:dinein_app/core/services/discover_assistant_service.dart';
import 'package:dinein_app/core/services/google_places_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscoverAssistantService', () {
    test(
      'prioritizes local DineIn venues and deduplicates Google references',
      () async {
        final sut = DiscoverAssistantService(
          googleMapsEnabled: true,
          placesSearch: (_) async => const [
            GooglePlaceCandidate(
              placeId: 'place_1',
              name: 'Harbor Table',
              address: 'Valletta Waterfront',
              category: 'Seafood restaurant',
              rating: 4.7,
              ratingCount: 120,
            ),
            GooglePlaceCandidate(
              placeId: 'place_2',
              name: 'Blue Fin Bistro',
              address: 'Sliema Seafront',
              category: 'Seafood restaurant',
              rating: 4.5,
              ratingCount: 88,
            ),
          ],
        );

        const venues = [
          Venue(
            id: 'venue_1',
            name: 'Harbor Table',
            slug: 'harbor-table',
            category: 'Seafood',
            description: 'Seafront seafood dining with sunset views.',
            address: 'Valletta Waterfront',
            rating: 4.8,
            ratingCount: 210,
          ),
          Venue(
            id: 'venue_2',
            name: 'Morning Edit',
            slug: 'morning-edit',
            category: 'Cafe',
            description: 'Coffee and brunch studio.',
            address: 'St Julian\'s',
            rating: 4.3,
            ratingCount: 75,
          ),
        ];

        final result = await sut.explore(
          query: 'seafood by the water',
          venues: venues,
        );

        expect(result.dineInMatches, isNotEmpty);
        expect(result.dineInMatches.first.title, 'Harbor Table');
        expect(result.googleMapsMatches, hasLength(1));
        expect(result.googleMapsMatches.first.title, 'Blue Fin Bistro');
        expect(result.summary, contains('Google Maps'));
      },
    );

    test(
      'falls back cleanly when Google Maps data is not configured',
      () async {
        final sut = DiscoverAssistantService(
          googleMapsEnabled: false,
          placesSearch: (_) async => throw Exception('should not be called'),
        );

        const venues = [
          Venue(
            id: 'venue_1',
            name: 'Late Table',
            slug: 'late-table',
            category: 'Bistro',
            description: 'Open late for dinner and drinks.',
            address: 'Gzira',
            rating: 4.4,
            ratingCount: 90,
          ),
        ];

        final result = await sut.explore(query: 'open now', venues: venues);

        expect(result.dineInMatches, hasLength(1));
        expect(result.googleMapsMatches, isEmpty);
        expect(result.provenanceNote, contains('not configured'));
      },
    );

    test(
      'includes active browse-only venues in local DineIn matches',
      () async {
        final sut = DiscoverAssistantService(
          googleMapsEnabled: false,
          placesSearch: (_) async => throw Exception('should not be called'),
        );

        const venues = [
          Venue(
            id: 'venue_1',
            name: 'Preview Lounge',
            slug: 'preview-lounge',
            category: 'Cocktail Bar',
            description: 'Menu preview is live before validation completes.',
            address: 'Sliema',
            status: VenueStatus.active,
            orderingEnabled: false,
            rating: 4.6,
            ratingCount: 112,
          ),
        ];

        final result = await sut.explore(
          query: 'preview lounge',
          venues: venues,
        );

        expect(result.dineInMatches, hasLength(1));
        expect(result.dineInMatches.first.title, 'Preview Lounge');
      },
    );
  });

  group('DiscoverAssistantMatch links', () {
    test('builds Google Maps, phone, and website URIs for references', () {
      const match = DiscoverAssistantMatch(
        id: 'place_123',
        title: 'Blue Fin Bistro',
        subtitle: 'Seafood restaurant',
        source: DiscoverAssistantSource.googleMaps,
        address: 'Sliema Seafront',
        phoneNumber: '+356 9999 1111',
        websiteUrl: 'bluefin.example.com',
      );

      expect(
        match.googleMapsUri?.toString(),
        'https://www.google.com/maps/search/?api=1&query=Blue+Fin+Bistro+Sliema+Seafront&query_place_id=place_123',
      );
      expect(match.phoneUri?.toString(), 'tel:+35699991111');
      expect(match.websiteUri?.toString(), 'https://bluefin.example.com');
    });

    test('does not expose external URIs for local DineIn matches', () {
      const match = DiscoverAssistantMatch(
        id: 'venue_1',
        title: 'Harbor Table',
        subtitle: 'Seafront dining',
        source: DiscoverAssistantSource.dineIn,
        address: 'Valletta Waterfront',
      );

      expect(match.googleMapsUri, isNull);
      expect(match.phoneUri, isNull);
      expect(match.websiteUri, isNull);
    });
  });
}
