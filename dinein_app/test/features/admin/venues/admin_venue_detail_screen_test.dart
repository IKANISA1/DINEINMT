import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/features/admin/venues/admin_venue_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CountryRuntime.configure(CountryConfig.mt);
  });

  Venue buildVenue() {
    return Venue.fromJson({
      'id': 'venue-1',
      'name': 'Harbor Table',
      'slug': 'harbor-table',
      'category': 'restaurant',
      'description': 'Harbor-facing dining.',
      'address': '45 Tower Rd, Sliema, Malta',
      'phone': '+35699123456',

      'revolut_url': 'https://revolut.me/harbortable',
      'social_links': {
        'instagram': 'https://instagram.com/harbortable',
        'tiktok': 'https://tiktok.com/@harbortable',
      },

      'status': 'active',
      'ordering_enabled': true,
    });
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Venue venue,
    required Future<void> Function(String venueId, Map<String, dynamic> updates)
    onUpdateVenue,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: TickerMode(
          enabled: false,
          child: MaterialApp(
            home: AdminVenueDetailScreen(
              venueId: venue.id,
              initialVenueOverride: venue,
              onUpdateVenueOverride: onUpdateVenue,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('admin venue detail renders guest and venue app urls', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      venue: buildVenue(),
      onUpdateVenue: (venueId, updates) async {},
    );

    await tester.scrollUntilVisible(
      find.textContaining('https://dineinmt.ikanisa.com/v/harbor-table'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(
      find.textContaining('https://dineinmt.ikanisa.com/v/harbor-table'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'https://dineinmt.ikanisa.com/download/?slug=harbor-table',
      ),
      findsOneWidget,
    );
  });

  testWidgets('admin venue detail saves the full venue profile payload', (
    tester,
  ) async {
    Map<String, dynamic>? savedUpdates;

    await pumpScreen(
      tester,
      venue: buildVenue(),
      onUpdateVenue: (_, updates) async {
        savedUpdates = updates;
      },
    );

    await tester.tap(find.text('SAVE CHANGES'));
    await tester.pump();
    await tester.pump();

    expect(savedUpdates, isNotNull);
    expect(savedUpdates?['name'], 'Harbor Table');
    expect(savedUpdates?['slug'], 'harbor-table');
    expect(savedUpdates?['category'], 'Restaurant');
    expect(savedUpdates?['address'], '45 Tower Rd, Sliema, Malta');
    expect(savedUpdates?['ordering_enabled'], true);
    expect(savedUpdates?['status'], 'active');
  });
}
