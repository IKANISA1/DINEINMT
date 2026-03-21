import 'package:dinein_app/core/constants/enums.dart';
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
    test('has exactly 2 values (scope boundary)', () {
      expect(PaymentMethod.values, hasLength(2));
    });

    test('fromString resolves known values', () {
      expect(PaymentMethod.fromString('cash'), PaymentMethod.cash);
      expect(PaymentMethod.fromString('revolut_link'), PaymentMethod.revolutLink);
    });

    test('fromString falls back to cash for unknown', () {
      expect(PaymentMethod.fromString('momo_ussd'), PaymentMethod.cash);
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
    });

    test('descriptions are meaningful', () {
      expect(PaymentMethod.cash.description, 'Pay at the venue');
      expect(PaymentMethod.revolutLink.description, 'Pay via Revolut link');
    });
  });

  // ─── Country ───

  group('Country', () {
    test('has exactly 1 value: mt (scope boundary)', () {
      expect(Country.values, hasLength(1));
      expect(Country.values.first, Country.mt);
    });

    test('mt has correct label, code, currency', () {
      expect(Country.mt.label, 'Malta');
      expect(Country.mt.code, 'MT');
      expect(Country.mt.currency, 'EUR');
      expect(Country.mt.currencySymbol, '€');
    });

    test('paymentMethods includes only cash and revolutLink', () {
      final methods = Country.mt.paymentMethods;
      expect(methods, hasLength(2));
      expect(methods, contains(PaymentMethod.cash));
      expect(methods, contains(PaymentMethod.revolutLink));
    });

    test('fromCode always returns mt regardless of input', () {
      expect(Country.fromCode('MT'), Country.mt);
      expect(Country.fromCode('RW'), Country.mt);
      expect(Country.fromCode(''), Country.mt);
    });
  });

  // ─── VenueStatus ───

  group('VenueStatus', () {
    test('has exactly 7 values', () {
      expect(VenueStatus.values, hasLength(7));
    });

    test('fromString resolves all 7 known values', () {
      expect(VenueStatus.fromString('active'), VenueStatus.active);
      expect(VenueStatus.fromString('inactive'), VenueStatus.inactive);
      expect(VenueStatus.fromString('maintenance'), VenueStatus.maintenance);
      expect(VenueStatus.fromString('suspended'), VenueStatus.suspended);
      expect(VenueStatus.fromString('deleted'), VenueStatus.deleted);
      expect(VenueStatus.fromString('pending_claim'), VenueStatus.pendingClaim);
      expect(
        VenueStatus.fromString('pending_activation'),
        VenueStatus.pendingActivation,
      );
    });

    test('fromString falls back to active for unknown', () {
      expect(VenueStatus.fromString('archived'), VenueStatus.active);
      expect(VenueStatus.fromString(''), VenueStatus.active);
    });

    test('dbValue round-trips through fromString', () {
      for (final status in VenueStatus.values) {
        expect(VenueStatus.fromString(status.dbValue), status);
      }
    });

    test('labels are capitalised and human-readable', () {
      expect(VenueStatus.active.label, 'Active');
      expect(VenueStatus.pendingClaim.label, 'Pending Claim');
      expect(VenueStatus.pendingActivation.label, 'Pending Activation');
    });
  });

  // ─── ClaimStatus ───

  group('ClaimStatus', () {
    test('has exactly 3 values', () {
      expect(ClaimStatus.values, hasLength(3));
    });

    test('fromString resolves all known values', () {
      expect(ClaimStatus.fromString('pending'), ClaimStatus.pending);
      expect(ClaimStatus.fromString('approved'), ClaimStatus.approved);
      expect(ClaimStatus.fromString('rejected'), ClaimStatus.rejected);
    });

    test('fromString falls back to pending', () {
      expect(ClaimStatus.fromString('unknown'), ClaimStatus.pending);
      expect(ClaimStatus.fromString(''), ClaimStatus.pending);
    });

    test('dbValue round-trips through fromString', () {
      for (final status in ClaimStatus.values) {
        expect(ClaimStatus.fromString(status.dbValue), status);
      }
    });
  });

  // ─── MenuItemImageStatus ───

  group('MenuItemImageStatus', () {
    test('has exactly 4 values', () {
      expect(MenuItemImageStatus.values, hasLength(4));
    });

    test('fromString resolves known values', () {
      expect(MenuItemImageStatus.fromString('pending'), MenuItemImageStatus.pending);
      expect(MenuItemImageStatus.fromString('generating'), MenuItemImageStatus.generating);
      expect(MenuItemImageStatus.fromString('ready'), MenuItemImageStatus.ready);
      expect(MenuItemImageStatus.fromString('failed'), MenuItemImageStatus.failed);
    });

    test('fromString falls back to pending for unknown', () {
      expect(MenuItemImageStatus.fromString('queued'), MenuItemImageStatus.pending);
    });

    test('dbValue round-trips through fromString', () {
      for (final status in MenuItemImageStatus.values) {
        expect(MenuItemImageStatus.fromString(status.dbValue), status);
      }
    });
  });

  // ─── MenuItemImageSource ───

  group('MenuItemImageSource', () {
    test('has exactly 3 values', () {
      expect(MenuItemImageSource.values, hasLength(3));
    });

    test('fromString resolves known values', () {
      expect(MenuItemImageSource.fromString('manual'), MenuItemImageSource.manual);
      expect(MenuItemImageSource.fromString('ai_gemini'), MenuItemImageSource.aiGemini);
      expect(MenuItemImageSource.fromString(null), MenuItemImageSource.unknown);
    });

    test('fromString falls back to unknown', () {
      expect(MenuItemImageSource.fromString('dalle'), MenuItemImageSource.unknown);
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

    test('no MoMo payment method exists (Malta-only)', () {
      final dbValues = PaymentMethod.values.map((e) => e.dbValue).toList();

      expect(dbValues, isNot(contains('momo_ussd')));
    });

    test('no Rwanda country exists (Malta-only)', () {
      final codes = Country.values.map((e) => e.code).toList();

      expect(codes, isNot(contains('RW')));
      expect(codes, contains('MT'));
    });
  });
}
