import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readMigration(String filename) {
  final file = File('supabase/migrations/$filename');
  expect(file.existsSync(), isTrue, reason: 'Missing migration $filename');
  return file.readAsStringSync();
}

void main() {
  group('Database RLS isolation contracts', () {
    test('orders writes stay behind the edge API and receipt access is indexed', () {
      final secureOrders = _readMigration(
        '20260321012000_secure_orders_and_totals.sql',
      );
      final orderReceipt = _readMigration(
        '20260321001100_add_order_money_columns.sql',
      );

      expect(
        secureOrders,
        contains(
          'revoke insert, update, delete on table public.dinein_orders\n  from anon, authenticated;',
        ),
      );
      expect(
        secureOrders,
        contains(
          'drop policy if exists "Customers can insert orders" on public.dinein_orders;',
        ),
      );
      expect(
        orderReceipt,
        contains('ADD COLUMN IF NOT EXISTS guest_receipt_token TEXT;'),
      );
      expect(
        orderReceipt,
        contains('ON dinein_orders(guest_receipt_token)'),
      );
    });

    test('menu items remain publicly readable but owner-scoped for writes', () {
      final sql = _readMigration('20260320000446_create_dinein_menu_items.sql');

      expect(sql, contains('CREATE POLICY "Anyone can read menu items"'));
      expect(
        sql,
        contains('CREATE POLICY "Venue owners can insert own menu items"'),
      );
      expect(
        sql,
        contains('CREATE POLICY "Venue owners can update own menu items"'),
      );
      expect(
        sql,
        contains('CREATE POLICY "Venue owners can delete own menu items"'),
      );
      expect(sql, contains('owner_id = auth.uid()'));
    });

    test('bell requests only allow inserts for active venues', () {
      final hardening = _readMigration(
        '20260322000200_tighten_bell_and_storage_policies.sql',
      );

      expect(
        hardening,
        contains('DROP POLICY IF EXISTS "Anyone can insert bell requests"'),
      );
      expect(
        hardening,
        contains('CREATE POLICY "Insert bell requests for active venues"'),
      );
      expect(hardening, contains("WHERE id = venue_id AND status = 'active'"));
    });

    test('realtime order reads are scoped to signed JWT claims', () {
      final realtime = _readMigration(
        '20260408000100_add_scoped_order_realtime_policies.sql',
      );

      expect(
        realtime,
        contains('grant select on public.dinein_orders to authenticated;'),
      );
      expect(
        realtime,
        contains('coalesce(auth.jwt() ->> \'aud\', \'\') = \'dinein-venue-realtime\''),
      );
      expect(
        realtime,
        contains('and venue_id::text = auth.jwt() ->> \'venue_id\''),
      );
      expect(
        realtime,
        contains('coalesce(auth.jwt() ->> \'aud\', \'\') = \'dinein-order-realtime\''),
      );
      expect(
        realtime,
        contains('and id::text = auth.jwt() ->> \'order_id\''),
      );
    });
  });
}
