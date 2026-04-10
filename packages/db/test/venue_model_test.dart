import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('Venue', () {
    test('fromJson falls back to configured payment methods from country links', () {
      final maltaVenue = Venue.fromJson({
        'id': 'venue_mt',
        'name': 'Harbor Table',
        'slug': 'harbor-table',
        'category': 'Fine Dining',
        'description': 'Seafront dining.',
        'address': 'Sliema',
        'country': 'MT',
        'revolut_url': 'https://revolut.me/dineinmalta',
      });

      final rwandaVenue = Venue.fromJson({
        'id': 'venue_rw',
        'name': 'Kigali Table',
        'slug': 'kigali-table',
        'category': 'Hotels',
        'description': 'Rooftop dining.',
        'address': 'Kigali',
        'country': 'RW',
        'momo_code': '*182*8*1#',
      });

      expect(maltaVenue.supportedPaymentMethods, [
        PaymentMethod.cash,
        PaymentMethod.revolutLink,
      ]);
      expect(rwandaVenue.supportedPaymentMethods, [
        PaymentMethod.cash,
        PaymentMethod.momoUssd,
      ]);
    });

    test('guest availability derives from status and ordering flag', () {
      const activeOrdering = Venue(
        id: 'venue_active',
        name: 'Harbor Table',
        slug: 'harbor-table',
        category: 'Restaurants',
        description: 'Seafront dining.',
        address: 'Valletta Waterfront',
        status: VenueStatus.active,
        orderingEnabled: true,
      );

      const browseOnly = Venue(
        id: 'venue_browse',
        name: 'Harbor Table',
        slug: 'harbor-table',
        category: 'Restaurants',
        description: 'Seafront dining.',
        address: 'Valletta Waterfront',
        status: VenueStatus.active,
        orderingEnabled: false,
      );

      const closed = Venue(
        id: 'venue_closed',
        name: 'Harbor Table',
        slug: 'harbor-table',
        category: 'Restaurants',
        description: 'Seafront dining.',
        address: 'Valletta Waterfront',
        status: VenueStatus.maintenance,
      );

      expect(activeOrdering.canAcceptGuestOrders, isTrue);
      expect(activeOrdering.guestAvailabilityLabel, 'Available');
      expect(browseOnly.canAcceptGuestOrders, isFalse);
      expect(browseOnly.guestAvailabilityLabel, 'Browse Menu');
      expect(closed.canAcceptGuestOrders, isFalse);
      expect(closed.guestAvailabilityLabel, 'Closed');
    });

    test('toJson preserves configured fields used in release flows', () {
      const venue = Venue(
        id: 'venue_1',
        name: 'Harbor Table',
        slug: 'harbor-table',
        category: 'Restaurants',
        description: 'Seafront dining.',
        address: 'Valletta Waterfront',
        country: Country.rw,
        phone: '+250700000000',
        momoCode: '*182*8*1#',
        supportedPaymentMethods: [
          PaymentMethod.cash,
          PaymentMethod.momoUssd,
        ],
        socialLinks: {
          'instagram': 'https://instagram.com/harbortable',
        },
        promoMessage: 'Lunch special available',
        isPromoActive: true,
      );

      final json = venue.toJson();

      expect(json['country'], 'RW');
      expect(json['momo_code'], '*182*8*1#');
      expect(json['supported_payment_methods'], [
        'cash',
        'momo_ussd',
      ]);
      expect(json['promo_message'], 'Lunch special available');
      expect(json['is_promo_active'], isTrue);
    });
  });
}
