import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_draft_models.dart';

class OnboardingDraftService {
  OnboardingDraftService._();

  static const _claimedVenueKey = 'dinein.claimed_venue';
  static const _menuDraftItemsKey = 'dinein.menu_draft_items';

  static Future<SharedPreferences> get _prefs async =>
      SharedPreferences.getInstance();

  static Future<void> saveClaimedVenue(ClaimedVenueDraft venue) async {
    final prefs = await _prefs;
    await prefs.setString(_claimedVenueKey, jsonEncode(venue.toJson()));
  }

  static Future<ClaimedVenueDraft?> loadClaimedVenue() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_claimedVenueKey);
    if (raw == null || raw.isEmpty) return null;
    return ClaimedVenueDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> clearClaimedVenue() async {
    final prefs = await _prefs;
    await prefs.remove(_claimedVenueKey);
  }

  static Future<void> saveMenuDraftItems(List<OcrDraftMenuItem> items) async {
    final prefs = await _prefs;
    await prefs.setString(
      _menuDraftItemsKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  static Future<List<OcrDraftMenuItem>> loadMenuDraftItems() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_menuDraftItemsKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => OcrDraftMenuItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> clearMenuDraftItems() async {
    final prefs = await _prefs;
    await prefs.remove(_menuDraftItemsKey);
  }
}
