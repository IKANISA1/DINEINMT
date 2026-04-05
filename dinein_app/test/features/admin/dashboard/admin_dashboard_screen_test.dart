import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/image_health_provider.dart';
import 'package:dinein_app/core/providers/order_providers.dart';
import 'package:dinein_app/core/providers/venue_providers.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:dinein_app/features/admin/dashboard/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin dashboard renders KPI grid and overview sections', (
    tester,
  ) async {
    CountryRuntime.configure(CountryConfig.rw);
    final now = DateTime.now();
    final venues = [
      Venue(
        id: 'venue-1',
        name: 'Ubumwe Grande Hotel',
        slug: 'ubumwe-grande-hotel',
        category: 'Hotels',
        description: 'Luxury hotel venue.',
        address: 'Kigali',
        phone: '+250788767816',
        status: VenueStatus.active,
        accessVerifiedAt: now,
        country: Country.rw,
      ),
      Venue(
        id: 'venue-2',
        name: 'Torino Bar & Restaurant',
        slug: 'torino-bar-restaurant',
        category: 'Restaurants',
        description: 'Popular restaurant venue.',
        address: 'Kigali',
        status: VenueStatus.pendingActivation,
        country: Country.rw,
      ),
    ];
    final orders = [
      Order(
        id: 'order-1',
        venueId: 'venue-1',
        venueName: 'Ubumwe Grande Hotel',
        items: const [
          OrderItem(
            menuItemId: 'menu-1',
            name: 'Brochette',
            price: 2000,
            quantity: 2,
          ),
        ],
        total: 4000,
        status: OrderStatus.placed,
        createdAt: now,
        paymentMethod: PaymentMethod.cash,
      ),
      Order(
        id: 'order-2',
        venueId: 'venue-2',
        venueName: 'Torino Bar & Restaurant',
        items: const [
          OrderItem(
            menuItemId: 'menu-2',
            name: 'Pizza',
            price: 5000,
            quantity: 1,
          ),
        ],
        total: 5000,
        status: OrderStatus.cancelled,
        createdAt: now,
        paymentMethod: PaymentMethod.cash,
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(1440, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allVenuesProvider.overrideWith((ref) async => venues),
          allOrdersProvider.overrideWith((ref) async => orders),
          imageHealthProvider.overrideWith(
            (ref) async => const ImageHealthStats(
              total: 10,
              ready: 8,
              pending: 1,
              generating: 1,
              failed: 0,
            ),
          ),
        ],
        child: TickerMode(
          enabled: false,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const AdminDashboardScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Overview'), findsWidgets);
    expect(find.text('TOTAL VENUES'), findsOneWidget);
    expect(find.text('ORDERS TODAY'), findsOneWidget);
    expect(find.text('TOTAL ORDERS'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
