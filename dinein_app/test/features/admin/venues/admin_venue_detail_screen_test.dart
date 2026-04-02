import 'package:dinein_app/core/config/country_config.dart';
import 'package:dinein_app/core/config/country_runtime.dart';
import 'package:dinein_app/core/models/models.dart';
import 'package:dinein_app/core/providers/venue_providers.dart';
import 'package:dinein_app/features/admin/venues/admin_venue_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CountryRuntime.configure(CountryConfig.mt);
  });

  Venue buildVenue({String? phone, String? accessVerifiedAt}) {
    return Venue.fromJson({
      'id': 'venue-1',
      'name': 'Harbor Table',
      'slug': 'harbor-table',
      'category': 'restaurant',
      'status': 'active',
      'phone': phone,
      'normalized_access_phone': phone,
      'access_verified_at': accessVerifiedAt,
    });
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Venue venue,
    required Future<void> Function(String venueId, Map<String, dynamic> updates)
    onUpdateVenue,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueByIdProvider(venue.id).overrideWith((ref) async => venue),
        ],
        child: MaterialApp(
          home: AdminVenueDetailScreen(
            venueId: venue.id,
            onUpdateVenueOverride: onUpdateVenue,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('admin can assign a venue WhatsApp access number', (
    tester,
  ) async {
    Map<String, dynamic>? savedUpdates;

    await pumpScreen(
      tester,
      venue: buildVenue(),
      onUpdateVenue: (venueId, updates) async {
        savedUpdates = updates;
      },
    );

    await tester.ensureVisible(find.text('Add WhatsApp Number'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add WhatsApp Number'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '99123456');
    await tester.pump();
    await tester.tap(find.text('SAVE WHATSAPP NUMBER'));
    await tester.pumpAndSettle();

    expect(savedUpdates?['phone'], '+35699123456');
    expect(find.text('Venue WhatsApp access updated'), findsOneWidget);
  });

  testWidgets('duplicate venue access numbers surface a clear admin error', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      venue: buildVenue(phone: '+35699123456'),
      onUpdateVenue: (venueId, updates) async {
        throw Exception(
          'This WhatsApp number is already assigned to another venue.',
        );
      },
    );

    await tester.ensureVisible(find.text('Edit WhatsApp Number'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit WhatsApp Number'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '99222333');
    await tester.pump();
    await tester.tap(find.text('SAVE WHATSAPP NUMBER'));
    await tester.pumpAndSettle();

    expect(
      find.text('This WhatsApp number is already assigned to another venue.'),
      findsOneWidget,
    );
  });
}
