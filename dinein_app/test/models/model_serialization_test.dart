import 'package:dinein_app/core/constants/enums.dart';
import 'package:dinein_app/core/models/models.dart';
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
        'email': 'hello@harbor.mt',
        'image_url': 'https://example.com/venue.png',
        'status': 'active',
        'rating': 4.8,
        'rating_count': 210,
        'country': 'MT',
        'owner_id': 'owner_1',
      };

      final venue = Venue.fromJson(json);
      final output = venue.toJson();

      expect(output['id'], 'venue_1');
      expect(output['name'], 'Harbor Table');
      expect(output['slug'], 'harbor-table');
      expect(output['status'], 'active');
      expect(output['rating'], 4.8);
      expect(output['rating_count'], 210);
      expect(output['country'], 'MT');
      expect(output['owner_id'], 'owner_1');
      expect(output['phone'], '+356 9999 1111');
      expect(output['email'], 'hello@harbor.mt');
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
      expect(venue.rating, 0.0);
      expect(venue.ratingCount, 0);
      expect(venue.country, Country.mt);
      expect(venue.ownerId, isNull);
    });

    test('normalizeVenueCategoryLabel maps variants correctly', () {
      expect(normalizeVenueCategoryLabel('hotel'), 'Hotels');
      expect(normalizeVenueCategoryLabel('Bar & Restaurant'), 'Bar & Restaurants');
      expect(normalizeVenueCategoryLabel('bar'), 'Bar');
      expect(normalizeVenueCategoryLabel('restaurant'), 'Restaurants');
      expect(normalizeVenueCategoryLabel(null), 'Restaurants');
      expect(normalizeVenueCategoryLabel(''), 'Restaurants');
      expect(normalizeVenueCategoryLabel('  '), 'Restaurants');
    });

    test('isOpen reflects active status', () {
      const active = Venue(
        id: '1', name: 'A', slug: 'a', category: 'C',
        description: '', address: '', status: VenueStatus.active,
      );
      const inactive = Venue(
        id: '2', name: 'B', slug: 'b', category: 'C',
        description: '', address: '', status: VenueStatus.inactive,
      );

      expect(active.isOpen, isTrue);
      expect(inactive.isOpen, isFalse);
    });
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
        'image_url': 'https://example.com/ribeye.jpg',
        'image_source': 'manual',
        'image_status': 'ready',
        'image_locked': true,
        'image_storage_path': 'menu-items/venue_1/item_1/generated-123.png',
        'image_attempts': 2,
        'is_available': true,
        'tags': ['GF', "Chef's Choice"],
      };

      final item = MenuItem.fromJson(json);
      final output = item.toJson();

      expect(item.id, 'item_1');
      expect(item.venueId, 'venue_1');
      expect(item.name, 'Dry-Aged Ribeye');
      expect(item.price, 48.0);
      expect(item.imageLocked, isTrue);
      expect(item.imageSource, MenuItemImageSource.manual);
      expect(item.imageStatus, MenuItemImageStatus.ready);
      expect(item.imageStoragePath, 'menu-items/venue_1/item_1/generated-123.png');
      expect(item.imageAttempts, 2);
      expect(output['venue_id'], 'venue_1');
      expect(output['name'], 'Dry-Aged Ribeye');
      expect(output['price'], 48.0);
      expect(output['image_locked'], isTrue);
      expect(output['image_storage_path'], 'menu-items/venue_1/item_1/generated-123.png');
      expect(output['image_attempts'], 2);
    });

    test('fromJson handles missing optional fields', () {
      final item = MenuItem.fromJson({
        'id': 'item_2',
        'venue_id': 'venue_1',
        'name': 'Fries',
        'price': 6,
      });

      expect(item.description, '');
      expect(item.category, 'Uncategorized');
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
        id: 'item_1', venueId: 'v1', name: 'X', description: 'D',
        price: 10, category: 'C',
      );
      final copy = original.copyWith(price: 20, name: 'Y');

      expect(copy.price, 20);
      expect(copy.name, 'Y');
      expect(copy.id, 'item_1');
      expect(copy.description, 'D');
    });

    test('hasImage returns true only for non-empty imageUrl', () {
      const withImage = MenuItem(
        id: '1', venueId: 'v', name: 'X', description: '',
        price: 5, category: 'C', imageUrl: 'https://x.com/img.jpg',
      );
      const withEmpty = MenuItem(
        id: '2', venueId: 'v', name: 'Y', description: '',
        price: 5, category: 'C', imageUrl: '  ',
      );
      const withNull = MenuItem(
        id: '3', venueId: 'v', name: 'Z', description: '',
        price: 5, category: 'C',
      );

      expect(withImage.hasImage, isTrue);
      expect(withEmpty.hasImage, isFalse);
      expect(withNull.hasImage, isFalse);
    });

    test('needsGeneratedImage is true when no image and not locked', () {
      const item = MenuItem(
        id: '1', venueId: 'v', name: 'X', description: '',
        price: 10, category: 'C',
      );
      const locked = MenuItem(
        id: '2', venueId: 'v', name: 'Y', description: '',
        price: 10, category: 'C', imageLocked: true,
      );

      expect(item.needsGeneratedImage, isTrue);
      expect(locked.needsGeneratedImage, isFalse);
    });
  });

  // ─── OrderItem ───

  group('OrderItem serialization', () {
    test('fromJson → toJson round-trip', () {
      final json = {
        'menu_item_id': 'item_1',
        'name': 'Ribeye',
        'price': 48.0,
        'quantity': 2,
        'note': 'Medium rare',
      };

      final item = OrderItem.fromJson(json);
      expect(item.subtotal, 96.0);

      final output = item.toJson();
      expect(output['menu_item_id'], 'item_1');
      expect(output['quantity'], 2);
      expect(output['note'], 'Medium rare');
    });

    test('copyWith overrides quantity and note', () {
      const item = OrderItem(
        menuItemId: 'm1', name: 'X', price: 10, quantity: 1,
      );
      final copy = item.copyWith(quantity: 3, note: 'No salt');

      expect(copy.quantity, 3);
      expect(copy.note, 'No salt');
      expect(copy.price, 10);
    });
  });

  // ─── Order ───

  group('Order serialization', () {
    test('fromJson parses all fields including dual-key receipt token', () {
      final json = {
        'id': 'ORD-001',
        'venue_id': 'v1',
        'venue_name': 'Harbor Table',
        'user_id': 'u1',
        'user_name': 'Alex',
        'items': [
          {'menu_item_id': 'm1', 'name': 'X', 'price': 10.0, 'quantity': 2},
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
      expect(order.venueId, 'v1');
      expect(order.venueName, 'Harbor Table');
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
        'whatsapp_number': '+35612345678',
        'venue_image_url': 'https://example.com/img.jpg',
        'issued_at': '2025-01-01T10:00:00Z',
        'expires_at': '2025-01-02T10:00:00Z',
      };

      final session = VenueAccessSession.fromJson(json);
      expect(session.accessToken, 'tok-123');
      expect(session.venueId, 'v1');
      expect(session.whatsAppNumber, '+35612345678');
      expect(session.isExpired, isTrue); // past date
    });

    test('toJson → fromJson round-trip', () {
      final now = DateTime.now();
      final session = VenueAccessSession(
        accessToken: 'tok',
        venueId: 'v1',
        venueName: 'V',
        whatsAppNumber: '+356',
        issuedAt: now,
        expiresAt: now.add(const Duration(days: 1)),
      );

      final json = session.toJson();
      final restored = VenueAccessSession.fromJson(json);

      expect(restored.accessToken, session.accessToken);
      expect(restored.venueId, session.venueId);
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

  // ─── VenueClaim ───

  group('VenueClaim serialization', () {
    test('fromJson parses whatsapp_number as contactPhone', () {
      final json = {
        'id': 'claim_1',
        'venue_id': 'v1',
        'venue_name': 'Harbor Table',
        'venue_area': 'Valletta',
        'whatsapp_number': '+35679991234',
        'claimant_name': 'Jean',
        'status': 'pending',
        'created_at': '2025-01-01T12:00:00Z',
      };

      final claim = VenueClaim.fromJson(json);
      expect(claim.contactPhone, '+35679991234');
      expect(claim.claimantName, 'Jean');
      expect(claim.status, ClaimStatus.pending);
      expect(claim.displayName, 'Jean');
    });

    test('displayName falls back to phone-derived when no claimantName', () {
      final json = {
        'id': 'claim_2',
        'venue_id': 'v1',
        'whatsapp_number': '+35679991234',
        'status': 'approved',
        'created_at': '2025-01-01T12:00:00Z',
      };

      final claim = VenueClaim.fromJson(json);
      expect(claim.displayName, 'Owner 1234');
    });

    test('displayName derives username from email-like contactPhone', () {
      final json = {
        'id': 'claim_3',
        'venue_id': 'v1',
        'email': 'jean@dinein.mt',
        'status': 'rejected',
        'created_at': '2025-01-01T12:00:00Z',
      };

      final claim = VenueClaim.fromJson(json);
      expect(claim.displayName, 'jean');
    });
  });
}
