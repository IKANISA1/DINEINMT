import 'package:core_pkg/constants/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Country.formatPriceTabular', () {
    group('Malta (EUR)', () {
      test('formats with 2 decimal places and euro symbol', () {
        expect(Country.mt.formatPriceTabular(1234.5), '€1,234.50');
      });

      test('zero amount', () {
        expect(Country.mt.formatPriceTabular(0), '€0.00');
      });

      test('integer amount gets .00 suffix', () {
        expect(Country.mt.formatPriceTabular(500), '€500.00');
      });

      test('large value with thousands separators', () {
        expect(Country.mt.formatPriceTabular(12345.67), '€12,345.67');
      });

      test('negative value', () {
        expect(Country.mt.formatPriceTabular(-42.5), '€-42.50');
      });

      test('matches formatPrice for normal values', () {
        // MT formatPrice already uses 2 decimals, so tabular should match
        expect(
          Country.mt.formatPriceTabular(1234.5),
          Country.mt.formatPrice(1234.5),
        );
      });
    });

    group('Rwanda (RWF)', () {
      test('formats with 2 decimal places and RWF prefix', () {
        expect(Country.rw.formatPriceTabular(1234), 'RWF 1,234.00');
      });

      test('zero amount', () {
        expect(Country.rw.formatPriceTabular(0), 'RWF 0.00');
      });

      test('fractional amount gets full precision', () {
        expect(Country.rw.formatPriceTabular(500.5), 'RWF 500.50');
      });

      test('large value with thousands separators', () {
        expect(Country.rw.formatPriceTabular(12345.67), 'RWF 12,345.67');
      });

      test('negative value', () {
        expect(Country.rw.formatPriceTabular(-42), 'RWF -42.00');
      });

      test('differs from formatPrice (formatPrice uses 0 decimals)', () {
        // RW formatPrice rounds to integer: "RWF 1,234"
        // RW formatPriceTabular keeps 2 decimals: "RWF 1,234.00"
        expect(Country.rw.formatPrice(1234), 'RWF 1,234');
        expect(Country.rw.formatPriceTabular(1234), 'RWF 1,234.00');
      });
    });

    group('Cross-regional alignment', () {
      test('both countries produce same decimal trailing length', () {
        final mtResult = Country.mt.formatPriceTabular(1000);
        final rwResult = Country.rw.formatPriceTabular(1000);
        // Both should end with .00
        expect(mtResult.contains('.00'), isTrue);
        expect(rwResult.contains('.00'), isTrue);
      });
    });
  });
}
