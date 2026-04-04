import 'package:flutter_test/flutter_test.dart';

import 'package:core_pkg/constants/enums.dart';

void main() {
  group('OrderStatus', () {
    test('contains exactly the four allowed statuses', () {
      expect(OrderStatus.values.length, 4);
      expect(
        OrderStatus.values.map((e) => e.name),
        containsAll(['placed', 'received', 'served', 'cancelled']),
      );
    });

    test('active vs terminal classification', () {
      expect(OrderStatus.placed.isActive, isTrue);
      expect(OrderStatus.received.isActive, isTrue);
      expect(OrderStatus.served.isTerminal, isTrue);
      expect(OrderStatus.cancelled.isTerminal, isTrue);
    });

    test('fromString round-trips correctly', () {
      for (final status in OrderStatus.values) {
        expect(OrderStatus.fromString(status.dbValue), status);
      }
    });

    test('fromString falls back to placed for unknown values', () {
      expect(OrderStatus.fromString('unknown'), OrderStatus.placed);
    });
  });

  group('PaymentMethod', () {
    test('dbValue covers all scope-boundary values', () {
      final dbValues = PaymentMethod.values.map((e) => e.dbValue).toSet();
      expect(dbValues, containsAll(['cash', 'revolut_link', 'momo_ussd']));
    });

    test('fromString round-trips correctly', () {
      for (final method in PaymentMethod.values) {
        expect(PaymentMethod.fromString(method.dbValue), method);
      }
    });
  });

  group('Country', () {
    test('only MT and RW exist', () {
      expect(Country.values.length, 2);
      expect(Country.values.map((e) => e.code), containsAll(['MT', 'RW']));
    });

    test('fromCode round-trips correctly', () {
      expect(Country.fromCode('MT'), Country.mt);
      expect(Country.fromCode('RW'), Country.rw);
    });

    test('fromCode defaults to MT for unknown', () {
      expect(Country.fromCode('XX'), Country.mt);
    });
  });
}
