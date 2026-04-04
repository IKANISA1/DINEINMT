import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/menu_providers.dart';
import 'package:dinein_app/core/providers/venue_providers.dart';
import 'package:dinein_app/features/admin/menus/admin_menus_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin menus screen defaults to the catalog management view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const entry = AdminMenuCatalogEntry(
      groupId: 'group-1',
      representativeItemId: 'item-1',
      representativeVenueId: 'venue-1',
      name: 'Shared Burger',
      description: 'Shared admin-managed burger description.',
      category: 'Mains',
      itemClass: MenuItemClass.food,
      imageStatus: MenuItemImageStatus.ready,
      assignedVenueCount: 5,
      assignedActiveVenueCount: 4,
      tags: ['Signature'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminMenuCatalogProvider.overrideWith((ref) async => const [entry]),
          adminMenuQueueProvider.overrideWith((ref) async => const []),
          allVenuesProvider.overrideWith((ref) async => const <Venue>[]),
        ],
        child: const TickerMode(
          enabled: false,
          child: MaterialApp(home: Scaffold(body: AdminMenusScreen())),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Menus'), findsOneWidget);
    expect(find.text('Search menu catalog...'), findsOneWidget);
    expect(find.text('Search menu submissions...'), findsNothing);
    expect(find.text('UPLOAD CSV'), findsOneWidget);
  });
}
