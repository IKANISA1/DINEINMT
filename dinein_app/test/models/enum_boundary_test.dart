import 'package:core_pkg/constants/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─── OrderStatus ───

  group('OrderStatus', () {
    test('has exactly 4 values (scope boundary)', () {
      expect(OrderStatus.values, hasLength(4));
    });

    test('fromString resolves all known values', () {
      expect(OrderStatus.fromString('placed'), OrderStatus.placed);
      expect(OrderStatus.fromString('received'), OrderStatus.received);
      expect(OrderStatus.fromString('served'), OrderStatus.served);
      expect(OrderStatus.fromString('cancelled'), OrderStatus.cancelled);
    });

    test('fromString falls back to placed for unknown', () {
      expect(OrderStatus.fromString('delivering'), OrderStatus.placed);
      expect(OrderStatus.fromString('preparing'), OrderStatus.placed);
      expect(OrderStatus.fromString(''), OrderStatus.placed);
    });

    test('dbValue round-trips through fromString', () {
      for (final status in OrderStatus.values) {
        expect(OrderStatus.fromString(status.dbValue), status);
      }
    });

    test('isActive is true only for placed and received', () {
      expect(OrderStatus.placed.isActive, isTrue);
      expect(OrderStatus.received.isActive, isTrue);
      expect(OrderStatus.served.isActive, isFalse);
      expect(OrderStatus.cancelled.isActive, isFalse);
    });

    test('isTerminal is true only for served and cancelled', () {
      expect(OrderStatus.placed.isTerminal, isFalse);
      expect(OrderStatus.received.isTerminal, isFalse);
      expect(OrderStatus.served.isTerminal, isTrue);
      expect(OrderStatus.cancelled.isTerminal, isTrue);
    });

    test('stepIndex follows correct progression', () {
      expect(OrderStatus.placed.stepIndex, 0);
      expect(OrderStatus.received.stepIndex, 1);
      expect(OrderStatus.served.stepIndex, 2);
      expect(OrderStatus.cancelled.stepIndex, -1);
    });

    test('label is capitalised human-readable string', () {
      expect(OrderStatus.placed.label, 'Placed');
      expect(OrderStatus.received.label, 'Received');
      expect(OrderStatus.served.label, 'Served');
      expect(OrderStatus.cancelled.label, 'Cancelled');
    });
  });

  // ─── PaymentMethod ───

  group('PaymentMethod', () {
    test('has exactly 3 values for the supported markets', () {
      expect(PaymentMethod.values, hasLength(3));
    });

    test('fromString resolves known values', () {
      expect(PaymentMethod.fromString('cash'), PaymentMethod.cash);
      expect(
        PaymentMethod.fromString('revolut_link'),
        PaymentMethod.revolutLink,
      );
      expect(PaymentMethod.fromString('momo_ussd'), PaymentMethod.momoUssd);
    });

    test('fromString falls back to cash for unknown', () {
      expect(PaymentMethod.fromString('credit_card'), PaymentMethod.cash);
      expect(PaymentMethod.fromString(''), PaymentMethod.cash);
    });

    test('dbValue round-trips through fromString', () {
      for (final method in PaymentMethod.values) {
        expect(PaymentMethod.fromString(method.dbValue), method);
      }
    });

    test('labels are user-friendly', () {
      expect(PaymentMethod.cash.label, 'Cash');
      expect(PaymentMethod.revolutLink.label, 'Revolut');
      expect(PaymentMethod.momoUssd.label, 'MoMo');
    });

    test('descriptions are meaningful', () {
      expect(PaymentMethod.cash.description, 'Pay at the venue');
      expect(PaymentMethod.revolutLink.description, 'Pay via Revolut link');
      expect(PaymentMethod.momoUssd.description, 'Pay via MoMo mobile money');
    });
  });

  // ─── Country ───

  group('Country', () {
    test('has exactly 2 supported countries', () {
      expect(Country.values, hasLength(2));
      expect(Country.values, containsAll([Country.mt, Country.rw]));
    });

    test('mt has correct label, code, currency', () {
      expect(Country.mt.label, 'Malta');
      expect(Country.mt.code, 'MT');
      expect(Country.mt.currency, 'EUR');
      expect(Country.mt.currencySymbol, '€');
    });

    test('rw has correct label, code, currency', () {
      expect(Country.rw.label, 'Rwanda');
      expect(Country.rw.code, 'RW');
      expect(Country.rw.currency, 'RWF');
      expect(Country.rw.currencySymbol, 'RWF');
    });

    test('paymentMethods match each country configuration', () {
      expect(
        Country.mt.paymentMethods,
        equals([PaymentMethod.cash, PaymentMethod.revolutLink]),
      );
      expect(
        Country.rw.paymentMethods,
        equals([PaymentMethod.cash, PaymentMethod.momoUssd]),
      );
    });

    test('fromCode resolves supported country codes and defaults to mt', () {
      expect(Country.fromCode('MT'), Country.mt);
      expect(Country.fromCode('RW'), Country.rw);
      expect(Country.fromCode(''), Country.mt);
    });
  });

  // ─── VenueStatus ───

  group('VenueStatus', () {
    test('has exactly 5 values', () {
      expect(VenueStatus.values, hasLength(5));
    });

    test('fromString resolves all known values', () {
      expect(VenueStatus.fromString('active'), VenueStatus.active);
      expect(VenueStatus.fromString('inactive'), VenueStatus.inactive);
      expect(VenueStatus.fromString('maintenance'), VenueStatus.maintenance);
      expect(VenueStatus.fromString('suspended'), VenueStatus.suspended);
      expect(VenueStatus.fromString('deleted'), VenueStatus.deleted);
    });

    test('fromString falls back to inactive for unknown', () {
      expect(VenueStatus.fromString('archived'), VenueStatus.inactive);
      expect(VenueStatus.fromString(''), VenueStatus.inactive);
    });

    test('dbValue round-trips through fromString', () {
      for (final status in VenueStatus.values) {
        expect(VenueStatus.fromString(status.dbValue), status);
      }
    });

    test('labels are capitalised and human-readable', () {
      expect(VenueStatus.active.label, 'Active');
      expect(VenueStatus.inactive.label, 'Inactive');
    });
  });

  // ─── MenuItemImageStatus ───

  group('MenuItemImageStatus', () {
    test('has exactly 4 values', () {
      expect(MenuItemImageStatus.values, hasLength(4));
    });

    test('fromString resolves known values', () {
      expect(
        MenuItemImageStatus.fromString('pending'),
        MenuItemImageStatus.pending,
      );
      expect(
        MenuItemImageStatus.fromString('generating'),
        MenuItemImageStatus.generating,
      );
      expect(
        MenuItemImageStatus.fromString('ready'),
        MenuItemImageStatus.ready,
      );
      expect(
        MenuItemImageStatus.fromString('failed'),
        MenuItemImageStatus.failed,
      );
    });

    test('fromString falls back to pending for unknown', () {
      expect(
        MenuItemImageStatus.fromString('queued'),
        MenuItemImageStatus.pending,
      );
    });

    test('dbValue round-trips through fromString', () {
      for (final status in MenuItemImageStatus.values) {
        expect(MenuItemImageStatus.fromString(status.dbValue), status);
      }
    });
  });

  // ─── MenuItemClass ───

  group('MenuItemClass', () {
    test('has exactly 2 values', () {
      expect(MenuItemClass.values, hasLength(2));
      expect(
        MenuItemClass.values,
        containsAll([MenuItemClass.food, MenuItemClass.drinks]),
      );
    });

    test('fromString resolves known values and rejects unknown', () {
      expect(MenuItemClass.fromString('food'), MenuItemClass.food);
      expect(MenuItemClass.fromString('drinks'), MenuItemClass.drinks);
      expect(MenuItemClass.fromString('drink'), isNull);
      expect(MenuItemClass.fromString(null), isNull);
    });

    test('dbValue round-trips through fromString', () {
      for (final itemClass in MenuItemClass.values) {
        expect(MenuItemClass.fromString(itemClass.dbValue), itemClass);
      }
    });

    test('labels are human-readable', () {
      expect(MenuItemClass.food.label, 'Food');
      expect(MenuItemClass.drinks.label, 'Drinks');
    });
  });

  // ─── MenuItemImageSource ───

  group('MenuItemImageSource', () {
    test('has exactly 3 values', () {
      expect(MenuItemImageSource.values, hasLength(3));
    });

    test('fromString resolves known values', () {
      expect(
        MenuItemImageSource.fromString('manual'),
        MenuItemImageSource.manual,
      );
      expect(
        MenuItemImageSource.fromString('ai_gemini'),
        MenuItemImageSource.aiGemini,
      );
      expect(MenuItemImageSource.fromString(null), MenuItemImageSource.unknown);
    });

    test('fromString falls back to unknown', () {
      expect(
        MenuItemImageSource.fromString('dalle'),
        MenuItemImageSource.unknown,
      );
      expect(MenuItemImageSource.fromString(''), MenuItemImageSource.unknown);
    });

    test('dbValue is null for unknown', () {
      expect(MenuItemImageSource.unknown.dbValue, isNull);
      expect(MenuItemImageSource.manual.dbValue, 'manual');
      expect(MenuItemImageSource.aiGemini.dbValue, 'ai_gemini');
    });
  });

  // ─── Scope Boundary Enforcement ───

  group('Scope boundary enforcement', () {
    test('no delivery-related statuses exist in OrderStatus', () {
      final names = OrderStatus.values.map((e) => e.name).toList();

      expect(names, isNot(contains('delivering')));
      expect(names, isNot(contains('preparing')));
      expect(names, isNot(contains('inTransit')));
      expect(names, isNot(contains('delivered')));
    });

    test('Rwanda scope includes the MoMo payment method', () {
      final dbValues = PaymentMethod.values.map((e) => e.dbValue).toList();

      expect(dbValues, contains('momo_ussd'));
      expect(dbValues, containsAll(['cash', 'revolut_link']));
    });

    test('scope includes both Malta and Rwanda', () {
      final codes = Country.values.map((e) => e.code).toList();

      expect(codes, containsAll(['MT', 'RW']));
    });
  });
}
