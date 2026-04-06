import 'dart:io';
import 'dart:convert';
import 'package:supabase/supabase.dart';

void main() async {
  print('Starting E2E Guest Simulator Audit...');
  
  // 1. Read MT environment
  final String envPath = 'env/release.mt.json';
  if (!File(envPath).existsSync()) {
    print('Failed: Cannot find $envPath');
    exit(1);
  }
  
  final envData = jsonDecode(await File(envPath).readAsString());
  final url = envData['SUPABASE_URL'];
  final anonKey = envData['SUPABASE_ANON_KEY'];
  
  final client = SupabaseClient(url, anonKey);
  int passCount = 0;
  int failCount = 0;

  void reportResult(String testName, bool passed, [String extra = '']) {
    if (passed) {
      print('✅ PASS: $testName $extra');
      passCount++;
    } else {
      print('❌ FAIL: $testName $extra');
      failCount++;
    }
  }

  // TEST 1: Reading Public Venues (Guest allowed)
  try {
    final startTime = DateTime.now();
    final res = await client.from('dinein_venues').select('id, name, slug').limit(1);
    final ms = DateTime.now().difference(startTime).inMilliseconds;
    reportResult('Read public venues (Limit 1)', res.isNotEmpty, '- ${ms}ms');
    
    // Store venue ID for order test if exists
    final activeVenueId = res.isNotEmpty ? res.first['id'] as String : null;

    // TEST 2: Latency testing
    if (ms > 1000) {
      print('⚠️ WARNING: Venue query latency > 1000ms ($ms ms)');
    }
  } catch (e) {
    reportResult('Read public venues', false, '- Error: $e');
  }

  // TEST 3: RBAC Malicious Write to venues (Guest denied)
  try {
    await client.from('dinein_venues').insert({
      'name': 'Hacker Venue',
      'slug': 'hacker',
    });
    reportResult('RBAC: Write venues', false, '- Anonymous guest should not be able to write to venues table!');
  } catch (e) {
    bool isBlocked = e.toString().contains('42501') || e.toString().contains('row-level security');
    reportResult('RBAC: Write venues', isBlocked, '- Result: ${e.toString().split('\n').first}');
  }

  // TEST 4: RBAC Read from admin_kpis or sensitive tables (Guest denied)
  try {
    await client.from('admins').select('*');
    reportResult('RBAC: Read admins table', false, '- Guest successfully read admin table! DANGER!');
  } catch (e) {
    reportResult('RBAC: Read admins table', true, '- Successfully blocked admin read');
  }
  
  // TEST 5: RBAC Read orders (Guest should only see own orders... but we are anon)
  try {
    final res = await client.from('dinein_orders').select('*').limit(5);
    reportResult('RBAC: Read all orders', res.isEmpty, '- Guest returned ${res.length} orders without matching user ID!');
  } catch (e) {
    reportResult('RBAC: Read all orders', true, '- Blocked order scanning');
  }

  print('\n--- Audit Complete ---');
  print('Passed: $passCount, Failed: $failCount');
  exit(failCount == 0 ? 0 : 1);
}
