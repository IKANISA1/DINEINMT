import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─── Venue ───

  group('Venue serialization', () {
    test('fromJson → toJson round-trip preserves all fields', () {
      final json = {
        'id': 'venue_1',
        'name': 'Harbor Table',
        'slug': 'harbor-table',
        'category': 'restaurant',
        'description': 'Seafront dining.',
        'address': 'Valletta Waterfront',
        'phone': '+356 9999 1111',
        'owner_contact_phone': '+356 9999 2222',
        'owner_whatsapp_number': '+356 9999 3333',
        'email': 'hello@harbor.mt',
        'image_url': 'https://example.com/venue.png',
        'status': 'active',
        'ordering_enabled': true,
        'approved_at': '2026-04-02T08:00:00.000Z',
        'access_verified_at': '2026-04-02T08:05:00.000Z',
        'last_access_token_issued_at': '2026-04-02T08:06:00.000Z',
        'access_number_updated_at': '2026-04-02T08:07:00.000Z',
        'access_verification_method': 'otp',
        'access_verified_by': '+35699991111',
        'access_verification_note': 'Verified via OTP',
        'access_number_updated_by': 'admin-1',
        'normalized_access_phone': '+35699991111',
        'rating': 4.8,
        'rating_count': 210,
        'country': 'MT',
        'website_url': 'https://harbortable.mt',
        'supported_payment_methods': ['cash', 'revolut_link'],
        'opening_hours': {
          'Monday': {'is_open': true, 'open': '09:00', 'close': '22:00'},
        },
        'owner_id': 'owner_1',
        'wifi_ssid': 'HarborGuest',
        'wifi_password': 'seaside123',
        'wifi_security': 'WPA',
      };

      final venue = Venue.fromJson(json);
      final output = venue.toJson();

      expect(output['id'], 'venue_1');
      expect(output['name'], 'Harbor Table');
      expect(output['slug'], 'harbor-table');
      expect(output['status'], 'active');
      expect(output['ordering_enabled'], isTrue);
      expect(output['rating'], 4.8);
      expect(output['rating_count'], 210);
      expect(output['country'], 'MT');
      expect(output['website_url'], 'https://harbortable.mt');
      expect(output['supported_payment_methods'], ['cash', 'revolut_link']);
      expect(output['opening_hours'], {
        'Monday': {'is_open': true, 'open': '09:00', 'close': '22:00'},
      });
      expect(output['owner_id'], 'owner_1');
      expect(output['phone'], '+356 9999 1111');
      expect(output['owner_contact_phone'], '+356 9999 2222');
      expect(output['owner_whatsapp_number'], '+356 9999 3333');
      expect(output['email'], 'hello@harbor.mt');
      expect(output['approved_at'], '2026-04-02T08:00:00.000Z');
      expect(output['access_verified_at'], '2026-04-02T08:05:00.000Z');
      expect(output['last_access_token_issued_at'], '2026-04-02T08:06:00.000Z');
      expect(output['access_number_updated_at'], '2026-04-02T08:07:00.000Z');
      expect(output['access_verification_method'], 'otp');
      expect(output['access_verified_by'], '+35699991111');
      expect(output['access_verification_note'], 'Verified via OTP');
      expect(output['access_number_updated_by'], 'admin-1');
      expect(output['normalized_access_phone'], '+35699991111');
      expect(output['wifi_ssid'], 'HarborGuest');
      expect(output['wifi_password'], 'seaside123');
      expect(output['wifi_security'], 'WPA');
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = {
        'id': 'venue_2',
        'name': 'Morning Edit',
        'slug': 'morning-edit',
      };

      final venue = Venue.fromJson(json);

      expect(venue.description, '');
      expect(venue.address, '');
      expect(venue.phone, isNull);
      expect(venue.email, isNull);
      expect(venue.imageUrl, isNull);
      expect(venue.status, VenueStatus.active);
      expect(venue.orderingEnabled, isFalse);
      expect(venue.rating, 0.0);
      expect(venue.ratingCount, 0);
      expect(venue.country, Country.mt);
      expect(venue.ownerId, isNull);
      expect(venue.supportedPaymentMethods, [PaymentMethod.cash]);
    });

    test('effective access helpers prefer configured and verified access', () {
      final venue = Venue.fromJson({
        'id': 'venue_4',
        'name': 'Late Table',
        'slug': 'late-table',
        'status': 'active',
        'phone': '',
        'owner_contact_phone': '+35699994444',
        'normalized_access_phone': '+35699994444',
        'access_verified_at': '2026-04-02T08:05:00.000Z',
      });

      expect(venue.effectiveAccessPhone, '+35699994444');
      expect(venue.hasAssignedAccessPhone, isTrue);
      expect(venue.isAccessVerified, isTrue);
      expect(venue.isAccessReady, isTrue);
    });

    test('normalizeVenueCategoryLabel maps variants correctly', () {
      expect(normalizeVenueCategoryLabel('hotel'), 'Hotels');
      expect(
        normalizeVenueCategoryLabel('Bar & Restaurant'),
        'Bar & Restaurants',
      );
      expect(normalizeVenueCategoryLabel('bar'), 'Bar');
      expect(normalizeVenueCategoryLabel('restaurant'), 'Restaurants');
      expect(normalizeVenueCategoryLabel('seafood'), 'Seafood');
      expect(normalizeVenueCategoryLabel(null), 'Restaurants');
      expect(normalizeVenueCategoryLabel(''), 'Restaurants');
      expect(normalizeVenueCategoryLabel('  '), 'Restaurants');
    });

    test('isOpen reflects active status', () {
      const active = Venue(
        id: '1',
        name: 'A',
        slug: 'a',
        category: 'C',
        description: '',
        address: '',
        status: VenueStatus.active,
      );
      const inactive = Venue(
        id: '2',
        name: 'B',
        slug: 'b',
        category: 'C',
        description: '',
        address: '',
        status: VenueStatus.inactive,
      );

      expect(active.isOpen, isTrue);
      expect(inactive.isOpen, isFalse);
    });

    test('guest orderability is tracked separately from status', () {
      const browseOnly = Venue(
        id: '1',
        name: 'A',
        slug: 'a',
        category: 'C',
        description: '',
        address: '',
        status: VenueStatus.active,
      );
      const validated = Venue(
        id: '2',
        name: 'B',
        slug: 'b',
        category: 'C',
        description: '',
        address: '',
        status: VenueStatus.active,
        orderingEnabled: true,
      );

      expect(browseOnly.canAcceptGuestOrders, isFalse);
      expect(browseOnly.shouldHideGuestPricing, isTrue);
      expect(browseOnly.guestAvailabilityLabel, 'Browse Menu');
      expect(validated.canAcceptGuestOrders, isTrue);
      expect(validated.guestAvailabilityLabel, 'Available');
    });

    test(
      'supported payment methods are parsed without degrading unknown values',
      () {
        final venue = Venue.fromJson({
          'id': 'venue_3',
          'name': 'Revolut First',
          'slug': 'revolut-first',
          'supported_payment_methods': ['revolut_link', 'momo_ussd'],
        });

        expect(venue.supportedPaymentMethods, [PaymentMethod.revolutLink]);
        expect(venue.supportsPaymentMethod(PaymentMethod.cash), isFalse);
        expect(venue.supportsPaymentMethod(PaymentMethod.revolutLink), isTrue);
      },
    );

    test(
      'discovery metadata helpers expose maps, price, and review context',
      () {
        final venue = Venue.fromJson({
          'id': 'venue_discovery',
          'name': 'Atlas Grill',
          'slug': 'atlas-grill',
          'google_maps_uri': 'https://maps.google.com/?cid=123',
          'google_location': {'latitude': -1.9441, 'longitude': 30.0619},
          'google_price_level': 'PRICE_LEVEL_MODERATE',
          'google_review_summary':
              'Guests praise the lake views and grilled fish.',
        });

        expect(venue.latitude, closeTo(-1.9441, 0.0001));
        expect(venue.longitude, closeTo(30.0619, 0.0001));
        expect(venue.priceLevelLabel, r'$$');
        expect(
          venue.primaryReviewSnippet,
          'Guests praise the lake views and grilled fish.',
        );
        expect(venue.hasDiscoveryMetadata, isTrue);
      },
    );
  });

  // ─── Review ───

  group('Review serialization', () {
    test('fromJson handles missing fields with defaults', () {
      final review = Review.fromJson({});

      expect(review.author, 'Anonymous');
      expect(review.rating, 5.0);
      expect(review.text, '');
    });

    test('fromJson parses full data', () {
      final review = Review.fromJson({
        'author': 'Jean',
        'rating': 4.2,
        'text': 'Great place!',
      });

      expect(review.author, 'Jean');
      expect(review.rating, 4.2);
      expect(review.text, 'Great place!');
    });
  });

  // ─── MenuItem ───

  group('MenuItem serialization', () {
    test('fromJson → toJson round-trip preserves core fields', () {
      final json = {
        'id': 'item_1',
        'venue_id': 'venue_1',
        'name': 'Dry-Aged Ribeye',
        'description': 'Premium cut.',
        'price': 48.0,
        'category': 'Signature Mains',
        'class': 'food',
        'image_url': 'https://example.com/ribeye.jpg',
        'image_source': 'manual',
        'image_status': 'ready',
        'image_locked': true,
        'image_storage_path': 'menu-items/venue_1/item_1/generated-123.png',
        'image_attempts': 2,
        'price_hidden': true,
        'highlight_rank': 2,
        'is_available': true,
        'tags': ['GF', "Chef's Choice"],
      };

      final item = MenuItem.fromJson(json);
      final output = item.toJson();

      expect(item.id, 'item_1');
      expect(item.venueId, 'venue_1');
      expect(item.name, 'Dry-Aged Ribeye');
      expect(item.price, 48.0);
      expect(item.itemClass, MenuItemClass.food);
      expect(item.imageLocked, isTrue);
      expect(item.imageSource, MenuItemImageSource.manual);
      expect(item.imageStatus, MenuItemImageStatus.ready);
      expect(
        item.imageStoragePath,
        'menu-items/venue_1/item_1/generated-123.png',
      );
      expect(item.imageAttempts, 2);
      expect(item.priceHidden, isTrue);
      expect(item.highlightRank, 2);
      expect(output['venue_id'], 'venue_1');
      expect(output['name'], 'Dry-Aged Ribeye');
      expect(output['price'], 48.0);
      expect(output['class'], 'food');
      expect(output['image_locked'], isTrue);
      expect(
        output['image_storage_path'],
        'menu-items/venue_1/item_1/generated-123.png',
      );
      expect(output['image_attempts'], 2);
      expect(output['price_hidden'], isTrue);
      expect(output['highlight_rank'], 2);
    });

    test('fromJson handles missing optional fields', () {
      final item = MenuItem.fromJson({
        'id': 'item_2',
        'venue_id': 'venue_1',
        'name': 'Fries',
        'price': 6,
      });

      expect(item.description, '');
      expect(item.priceHidden, isFalse);
      expect(item.highlightRank, isNull);
      expect(item.category, 'Uncategorized');
      expect(item.itemClass, isNull);
      expect(item.imageUrl, isNull);
      expect(item.imageSource, MenuItemImageSource.unknown);
      expect(item.imageStatus, MenuItemImageStatus.pending);
      expect(item.imageLocked, isFalse);
      expect(item.imageStoragePath, isNull);
      expect(item.imageAttempts, 0);
      expect(item.isAvailable, isTrue);
      expect(item.tags, isEmpty);
    });

    test('copyWith creates independent copy with overrides', () {
      const original = MenuItem(
        id: 'item_1',
        venueId: 'v1',
        name: 'X',
        description: 'D',
        price: 10,
        category: 'C',
        itemClass: MenuItemClass.food,
        highlightRank: 1,
      );
      final copy = original.copyWith(
        price: 20,
        name: 'Y',
        itemClass: MenuItemClass.drinks,
        highlightRank: null,
      );

      expect(copy.price, 20);
      expect(copy.name, 'Y');
      expect(copy.id, 'item_1');
      expect(copy.description, 'D');
      expect(copy.highlightRank, isNull);
      expect(copy.itemClass, MenuItemClass.drinks);
    });

    test('hasImage returns true only for non-empty imageUrl', () {
      const withImage = MenuItem(
        id: '1',
        venueId: 'v',
        name: 'X',
        description: '',
        price: 5,
        category: 'C',
        itemClass: MenuItemClass.food,
        imageUrl: 'https://x.com/img.jpg',
      );
      const withEmpty = MenuItem(
        id: '2',
        venueId: 'v',
        name: 'Y',
        description: '',
        price: 5,
        category: 'C',
        itemClass: MenuItemClass.food,
        imageUrl: '  ',
      );
      const withNull = MenuItem(
        id: '3',
        venueId: 'v',
        name: 'Z',
        description: '',
        price: 5,
        category: 'C',
        itemClass: MenuItemClass.food,
      );

      expect(withImage.hasImage, isTrue);
      expect(withEmpty.hasImage, isFalse);
      expect(withNull.hasImage, isFalse);
    });

    test('needsGeneratedImage is true when no image and not locked', () {
      const item = MenuItem(
        id: '1',
        venueId: 'v',
        name: 'X',
        description: '',
        price: 10,
        category: 'C',
        itemClass: MenuItemClass.food,
      );
      const locked = MenuItem(
        id: '2',
        venueId: 'v',
        name: 'Y',
        description: '',
        price: 10,
        category: 'C',
        itemClass: MenuItemClass.food,
        imageLocked: true,
      );

      expect(item.needsGeneratedImage, isTrue);
      expect(locked.needsGeneratedImage, isFalse);
    });

    test('guest display tags show Top Pick for highlighted items', () {
      final item = MenuItem.fromJson({
        'id': 'item_4',
        'venue_id': 'venue_1',
        'name': 'Garden Bowl',
        'price': 16,
        'highlight_rank': 1,
        'tags': ['vegan', 'halal', 'Chef Pick'],
      });

      // highlightRank alone no longer makes isPopular true
      expect(item.isPopular, isFalse);
      // Instead, highlighted items show "Top Pick"
      expect(item.isGuestHighlight, isTrue);
      expect(item.guestHighlightLabel, 'Top Pick');
      expect(item.dietaryBadges, ['Vegan', 'Halal']);
      expect(
        item.guestDisplayTags,
        ['Top Pick', 'Vegan', 'Halal', 'Chef Pick'],
      );
    });

    test('isPopular requires totalOrdered >= 10 threshold', () {
      const base = MenuItem(
        id: 'pop_1',
        venueId: 'v1',
        name: 'Fries',
        description: '',
        price: 5,
        category: 'Sides',
      );

      // Default totalOrdered = 0 → not popular
      expect(base.isPopular, isFalse);
      expect(base.guestHighlightLabel, isNull);

      // Below threshold (9 orders)
      final below = base.copyWith(totalOrdered: 9);
      expect(below.isPopular, isFalse);

      // At threshold (10 orders)
      final atThreshold = base.copyWith(totalOrdered: 10);
      expect(atThreshold.isPopular, isTrue);
      expect(atThreshold.guestHighlightLabel, 'Popular');

      // Above threshold
      final above = base.copyWith(totalOrdered: 25);
      expect(above.isPopular, isTrue);
    });

    test('isPopular is true with popular-like tag regardless of orders', () {
      final item = MenuItem.fromJson({
        'id': 'pop_2',
        'venue_id': 'v1',
        'name': 'Bestselling Pasta',
        'price': 14,
        'tags': ['bestseller'],
      });

      // Tag-based popularity, no orders needed
      expect(item.isPopular, isTrue);
      expect(item.guestHighlightLabel, 'Popular');
    });

    test('guestHighlightLabel priority: Top Pick > Popular > Signature', () {
      // Case 1: both highlighted AND popular → "Top Pick" wins
      const both = MenuItem(
        id: 'prio_1',
        venueId: 'v1',
        name: 'X',
        description: '',
        price: 10,
        category: 'C',
        highlightRank: 1,
        totalOrdered: 10,
      );
      expect(both.guestHighlightLabel, 'Top Pick');

      // Case 2: popular only → "Popular"
      const popularOnly = MenuItem(
        id: 'prio_2',
        venueId: 'v1',
        name: 'Y',
        description: '',
        price: 10,
        category: 'C',
        totalOrdered: 15,
      );
      expect(popularOnly.guestHighlightLabel, 'Popular');

      // Case 3: signature only → "Signature"
      const signatureOnly = MenuItem(
        id: 'prio_3',
        venueId: 'v1',
        name: 'Z',
        description: '',
        price: 10,
        category: 'C',
        tags: ['signature'],
      );
      expect(signatureOnly.guestHighlightLabel, 'Signature');
    });
  });

  // ─── OrderItem ───

  group('OrderItem serialization', () {
    test('fromJson → toJson round-trip', () {
      final json = {
        'menu_item_id': 'item_1',
        'name': 'Ribeye',
        'description': 'Char-grilled premium ribeye',
        'image_url': 'https://example.com/ribeye.jpg',
        'price': 48.0,
        'quantity': 2,
        'note': 'Medium rare',
      };

      final item = OrderItem.fromJson(json);
      expect(item.subtotal, 96.0);

      final output = item.toJson();
      expect(output['menu_item_id'], 'item_1');
      expect(output['description'], 'Char-grilled premium ribeye');
      expect(output['image_url'], 'https://example.com/ribeye.jpg');
      expect(output['quantity'], 2);
      expect(output['note'], 'Medium rare');
    });

    test('copyWith overrides quantity and note', () {
      const item = OrderItem(
        menuItemId: 'm1',
        name: 'X',
        description: 'Original description',
        imageUrl: 'https://example.com/original.jpg',
        price: 10,
        quantity: 1,
      );
      final copy = item.copyWith(
        quantity: 3,
        note: 'No salt',
        description: 'Updated description',
      );

      expect(copy.quantity, 3);
      expect(copy.note, 'No salt');
      expect(copy.description, 'Updated description');
      expect(copy.imageUrl, 'https://example.com/original.jpg');
      expect(copy.price, 10);
    });
  });

  // ─── Order ───

  group('Order serialization', () {
    test('fromJson parses all fields including dual-key receipt token', () {
      final json = {
        'id': 'ORD-001',
        'order_number': '12345678',
        'venue_id': 'v1',
        'venue_name': 'Harbor Table',
        'venue_image_url': 'https://example.com/venue.jpg',
        'user_id': 'u1',
        'user_name': 'Alex',
        'items': [
          {
            'menu_item_id': 'm1',
            'name': 'X',
            'description': 'One-line description',
            'image_url': 'https://example.com/x.jpg',
            'price': 10.0,
            'quantity': 2,
          },
        ],
        'subtotal': 20.0,
        'service_fee': 1.0,
        'total': 21.0,
        'status': 'received',
        'created_at': '2025-01-01T12:00:00Z',
        'payment_method': 'revolut_link',
        'table_number': '5',
        'special_requests': 'Extra napkins',
        'receipt_token': 'abc-123',
      };

      final order = Order.fromJson(json);

      expect(order.id, 'ORD-001');
      expect(order.orderNumber, '12345678');
      expect(order.displayNumber, '12345678');
      expect(order.venueId, 'v1');
      expect(order.venueName, 'Harbor Table');
      expect(order.venueImageUrl, 'https://example.com/venue.jpg');
      expect(order.userId, 'u1');
      expect(order.status, OrderStatus.received);
      expect(order.paymentMethod, PaymentMethod.revolutLink);
      expect(order.tableNumber, '5');
      expect(order.specialRequests, 'Extra napkins');
      expect(order.guestReceiptToken, 'abc-123');
      expect(order.subtotal, 20.0);
      expect(order.serviceFee, 1.0);
      expect(order.total, 21.0);
      expect(order.itemCount, 2);
      expect(order.items.single.description, 'One-line description');
      expect(order.items.single.imageUrl, 'https://example.com/x.jpg');

      final output = order.toJson();
      expect(output['venue_image_url'], 'https://example.com/venue.jpg');
    });

    test('fromJson reads guest_receipt_token as fallback', () {
      final json = {
        'id': 'ORD-002',
        'venue_id': 'v1',
        'venue_name': 'V',
        'items': [],
        'total': 0.0,
        'created_at': '2025-01-01T12:00:00Z',
        'guest_receipt_token': 'fallback-token',
      };

      final order = Order.fromJson(json);
      expect(order.guestReceiptToken, 'fallback-token');
      expect(order.displayNumber, 'ORD-002');
    });

    test('computed subtotal sums items when subtotalAmount is null', () {
      final order = Order(
        id: 'ORD-003',
        venueId: 'v1',
        venueName: 'V',
        items: const [
          OrderItem(menuItemId: 'm1', name: 'A', price: 10, quantity: 2),
          OrderItem(menuItemId: 'm2', name: 'B', price: 5, quantity: 1),
        ],
        total: 25.0,
        createdAt: DateTime(2025),
        paymentMethod: PaymentMethod.cash,
      );

      expect(order.subtotal, 25.0);
      expect(order.serviceFee, 0.0);
    });
  });

  // ─── VenueAccessSession ───

  group('VenueAccessSession serialization', () {
    test('fromJson parses dual-key fields', () {
      final json = {
        'access_token': 'tok-123',
        'venue_id': 'v1',
        'venue_name': 'Harbor',
        'venue_slug': 'harbor-table',
        'whatsapp_number': '+35612345678',
        'venue_image_url': 'https://example.com/img.jpg',
        'issued_at': '2025-01-01T10:00:00Z',
        'expires_at': '2025-01-02T10:00:00Z',
      };

      final session = VenueAccessSession.fromJson(json);
      expect(session.accessToken, 'tok-123');
      expect(session.venueId, 'v1');
      expect(session.venueSlug, 'harbor-table');
      expect(session.whatsAppNumber, '+35612345678');
      expect(session.isExpired, isTrue); // past date
    });

    test('toJson → fromJson round-trip', () {
      final now = DateTime.now();
      final session = VenueAccessSession(
        accessToken: 'tok',
        venueId: 'v1',
        venueName: 'V',
        venueSlug: 'v',
        whatsAppNumber: '+356',
        issuedAt: now,
        expiresAt: now.add(const Duration(days: 1)),
      );

      final json = session.toJson();
      final restored = VenueAccessSession.fromJson(json);

      expect(restored.accessToken, session.accessToken);
      expect(restored.venueId, session.venueId);
      expect(restored.venueSlug, session.venueSlug);
      expect(restored.isExpired, isFalse);
    });
  });

  // ─── AdminAccessSession ───

  group('AdminAccessSession serialization', () {
    test('fromJson parses dual-key fields with fallbacks', () {
      final json = {
        'user_id': 'admin_1',
        'accessToken': 'admin-tok',
        'displayName': 'Super Admin',
        'whatsAppNumber': '+35600000000',
        'email': 'admin@dinein.mt',
        'expiresAt': '2025-01-02T10:00:00Z',
        'issuedAt': '2025-01-01T10:00:00Z',
      };

      final session = AdminAccessSession.fromJson(json);
      expect(session.adminUserId, 'admin_1');
      expect(session.accessToken, 'admin-tok');
      expect(session.displayName, 'Super Admin');
      expect(session.email, 'admin@dinein.mt');
    });

    test('initials extracts first + last initials', () {
      final session = AdminAccessSession(
        adminUserId: 'a1',
        accessToken: 't',
        displayName: 'Jean Bosco',
        whatsAppNumber: '+356',
        expiresAt: DateTime(2030),
        issuedAt: DateTime(2025),
      );
      expect(session.initials, 'JB');
    });

    test('initials returns single letter for single-word name', () {
      final session = AdminAccessSession(
        adminUserId: 'a2',
        accessToken: 't',
        displayName: 'Admin',
        whatsAppNumber: '+356',
        expiresAt: DateTime(2030),
        issuedAt: DateTime(2025),
      );
      expect(session.initials, 'A');
    });

    test('initials returns A for empty name', () {
      final session = AdminAccessSession(
        adminUserId: 'a3',
        accessToken: 't',
        displayName: '',
        whatsAppNumber: '+356',
        expiresAt: DateTime(2030),
        issuedAt: DateTime(2025),
      );
      expect(session.initials, 'A');
    });
  });
}
