import 'package:core_pkg/constants/enums.dart';
import 'package:dinein_app/core/services/venue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/mock_api_invoker.dart';

/// Venue JSON payloads that match Venue.fromJson expectations.
Map<String, dynamic> _venueJson({
  String id = 'v1',
  String name = 'Test Venue',
  String slug = 'test-venue',
  String status = 'active',
  bool orderingEnabled = true,
}) =>
    {
      'id': id,
      'name': name,
      'slug': slug,
      'category': 'Cafe',
      'description': 'A test venue',
      'address': '1 Main St',
      'status': status,
      'ordering_enabled': orderingEnabled,
      'country': 'MT',
    };

void main() {
  late MockApiInvoker mock;
  late VenueRepository repo;

  setUp(() {
    mock = MockApiInvoker();
    repo = VenueRepository.forTesting(invoker: mock.invoke);
  });

  group('getVenues', () {
    test('returns parsed Venue list from API response', () async {
      mock.registerResponse('get_venues', [
        _venueJson(id: 'v1', name: 'Alpha'),
        _venueJson(id: 'v2', name: 'Beta'),
      ]);

      final venues = await repo.getVenues();

      expect(venues, hasLength(2));
      expect(venues[0].id, 'v1');
      expect(venues[0].name, 'Alpha');
      expect(venues[1].id, 'v2');
      expect(venues[1].name, 'Beta');
      expect(mock.wasCalled('get_venues'), isTrue);
    });

    test('passes pagination params', () async {
      mock.registerResponse('get_venues', <dynamic>[]);

      await repo.getVenues(limit: 10, offset: 5);

      final inv = mock.lastInvocation('get_venues')!;
      expect(inv.payload?['limit'], 10);
      expect(inv.payload?['offset'], 5);
    });

    test('passes query and category filters', () async {
      mock.registerResponse('get_venues', <dynamic>[]);

      await repo.getVenues(query: 'pizza', category: 'Italian');

      final inv = mock.lastInvocation('get_venues')!;
      expect(inv.payload?['query'], 'pizza');
      expect(inv.payload?['category'], 'Italian');
    });

    test('passes ordering_only flag', () async {
      mock.registerResponse('get_venues', <dynamic>[]);

      await repo.getVenues(orderingOnly: true);

      final inv = mock.lastInvocation('get_venues')!;
      expect(inv.payload?['ordering_only'], isTrue);
    });

    test('returns empty list when API returns empty', () async {
      mock.registerResponse('get_venues', <dynamic>[]);

      final venues = await repo.getVenues();

      expect(venues, isEmpty);
    });

    test('throws when API fails', () async {
      mock.registerError('get_venues', Exception('Network error'));

      expect(() => repo.getVenues(), throwsException);
    });
  });

  group('getAllVenues', () {
    test('uses admin session', () async {
      mock.registerResponse('get_all_venues', <dynamic>[]);

      await repo.getAllVenues();

      final inv = mock.lastInvocation('get_all_venues')!;
      expect(inv.useAdminSession, isTrue);
    });

    test('returns parsed venue list', () async {
      mock.registerResponse('get_all_venues', [
        _venueJson(id: 'a1', status: 'inactive'),
      ]);

      final venues = await repo.getAllVenues();

      expect(venues, hasLength(1));
      expect(venues[0].id, 'a1');
      expect(venues[0].status, VenueStatus.inactive);
    });
  });

  group('getVenueBySlug', () {
    test('returns parsed venue', () async {
      mock.registerResponse(
        'get_venue_by_slug',
        _venueJson(id: 'slug-1', slug: 'test-slug'),
      );

      final venue = await repo.getVenueBySlug('test-slug');

      expect(venue, isNotNull);
      expect(venue!.slug, 'test-slug');
      final inv = mock.lastInvocation('get_venue_by_slug')!;
      expect(inv.payload?['slug'], 'test-slug');
    });

    test('returns null when not found', () async {
      mock.registerResponse('get_venue_by_slug', null);

      final venue = await repo.getVenueBySlug('nonexistent');

      expect(venue, isNull);
    });
  });

  group('getVenueById', () {
    test('returns parsed venue with correct payload', () async {
      mock.registerResponse(
        'get_venue_by_id',
        _venueJson(id: 'id-42'),
      );

      final venue = await repo.getVenueById('id-42');

      expect(venue, isNotNull);
      expect(venue!.id, 'id-42');
      final inv = mock.lastInvocation('get_venue_by_id')!;
      expect(inv.payload?['venueId'], 'id-42');
    });
  });

  group('createVenue', () {
    test('sends venue data with admin session', () async {
      mock.registerResponse(
        'create_venue',
        _venueJson(id: 'new-1', name: 'New Place'),
      );

      final venue = await repo.createVenue({'name': 'New Place'});

      expect(venue.id, 'new-1');
      expect(venue.name, 'New Place');
      final inv = mock.lastInvocation('create_venue')!;
      expect(inv.useAdminSession, isTrue);
      expect(inv.payload?['venue'], {'name': 'New Place'});
    });
  });

  group('getVenueForOwner', () {
    test('returns venue for given owner ID', () async {
      mock.registerResponse(
        'get_venue_for_owner',
        _venueJson(id: 'owned-1'),
      );

      final venue = await repo.getVenueForOwner('owner-abc');

      expect(venue?.id, 'owned-1');
      final inv = mock.lastInvocation('get_venue_for_owner')!;
      expect(inv.payload?['ownerId'], 'owner-abc');
    });

    test('returns null when owner has no venue', () async {
      mock.registerResponse('get_venue_for_owner', null);

      final venue = await repo.getVenueForOwner('no-venue-owner');

      expect(venue, isNull);
    });
  });

  group('updateVenue', () {
    test('sends update payload', () async {
      mock.registerResponse('update_venue', null);

      await repo.updateVenue('v-1', {'name': 'Updated Name'});

      final inv = mock.lastInvocation('update_venue')!;
      expect(inv.payload?['venueId'], 'v-1');
      expect((inv.payload?['updates'] as Map)['name'], 'Updated Name');
    });
  });

  group('searchGoogleMaps', () {
    test('parses array results', () async {
      mock.registerResponse('search_google_maps', [
        {'name': 'Place A', 'address': '1 St'},
        {'name': 'Place B', 'address': '2 Ave'},
      ]);

      final results = await repo.searchGoogleMaps('coffee');

      expect(results, hasLength(2));
      expect(results[0]['name'], 'Place A');
      final inv = mock.lastInvocation('search_google_maps')!;
      expect(inv.payload?['query'], 'coffee');
    });

    test('parses wrapped results object', () async {
      mock.registerResponse('search_google_maps', {
        'results': [
          {'name': 'Wrapped Place'},
        ],
      });

      final results = await repo.searchGoogleMaps('tea');

      expect(results, hasLength(1));
      expect(results[0]['name'], 'Wrapped Place');
    });
  });
}
