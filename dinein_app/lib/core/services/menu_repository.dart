import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

import '../models/models.dart';
import '../models/onboarding_draft_models.dart';
import 'auth_repository.dart';
import 'dinein_api_service.dart';
import 'menu_image_generation_service.dart';

/// Repository for menu item data access via Supabase.
class MenuRepository {
  MenuRepository._();
  static final instance = MenuRepository._();

  static const _localMenuPrefix = 'dinein.local_menu.';

  String _localMenuKey(String venueId) => '$_localMenuPrefix$venueId';

  Map<String, dynamic> _venueSessionPayload() {
    final session = AuthRepository.instance.currentVenueSession;
    if (session == null) return const {};
    final token = session.accessToken;
    if (token.isNotEmpty) {
      return {
        'venue_session': {'access_token': token},
      };
    }
    return {
      'venue_session': {
        'access_token': session.accessToken,
        'venue_id': session.venueId,
        'contact_phone': session.whatsAppNumber,
      },
    };
  }

  /// Fetch all menu items for a venue.
  Future<List<MenuItem>> getMenuItems(String venueId) async {
    final data =
        await DineinApiService.invoke(
              'get_menu_items',
              payload: {'venueId': venueId},
            )
            as List<dynamic>;
    final items = data.map((e) => MenuItem.fromJson(e)).toList();
    await _persistLocalMenuItems(venueId, items);
    return items;
  }

  /// Fetch locally persisted menu items for a venue.
  Future<List<MenuItem>> getLocalMenuItems(String venueId) async {
    final prefs = await SharedPreferences.getInstance();
    return _readLocalMenuItemsByKey(prefs, _localMenuKey(venueId));
  }

  /// Toggle availability of a menu item.
  Future<void> toggleAvailability(String itemId, bool isAvailable) async {
    await DineinApiService.invoke(
      'toggle_menu_item_availability',
      payload: {
        'itemId': itemId,
        'isAvailable': isAvailable,
        ..._venueSessionPayload(),
      },
    );
  }

  /// Create a new menu item.
  Future<MenuItem> createMenuItem(MenuItem item) async {
    final data = await DineinApiService.invoke(
      'create_menu_item',
      payload: {'item': item.toJson(), ..._venueSessionPayload()},
    );
    final created = MenuItem.fromJson(data as Map<String, dynamic>);
    await _mergeAndPersistLocalMenuItems(created.venueId, [created]);
    if (created.needsGeneratedImage) {
      unawaited(_queueMenuItemImageGenerationSilently(created.id));
    }
    return created;
  }

  /// Update an existing menu item.
  Future<void> updateMenuItem(
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    await DineinApiService.invoke(
      'update_menu_item',
      payload: {
        'itemId': itemId,
        'updates': updates,
        ..._venueSessionPayload(),
      },
    );
  }

  /// Delete a menu item.
  Future<void> deleteMenuItem(String itemId) async {
    await DineinApiService.invoke(
      'delete_menu_item',
      payload: {'itemId': itemId, ..._venueSessionPayload()},
    );
  }

  /// Import OCR draft items for a venue.
  Future<void> importDraftItems(
    String venueId,
    List<OcrDraftMenuItem> draftItems,
  ) async {
    if (draftItems.isEmpty) return;

    final menuItems = draftItems
        .map((item) => item.toMenuItem(venueId, id: _generateLocalId()))
        .toList();

    await DineinApiService.invoke(
      'import_draft_items',
      payload: {
        'venueId': venueId,
        'items': menuItems.map((item) => item.toJson()).toList(),
        ..._venueSessionPayload(),
      },
    );
    await _mergeAndPersistLocalMenuItems(venueId, menuItems);
    unawaited(
      _queueVenueBackfillSilently(
        venueId: venueId,
        limit: draftItems.length.clamp(1, 25).toInt(),
      ),
    );
  }

  /// Upload a menu file (image/PDF) to Supabase Storage.
  /// Returns the publicly accessible URL of the uploaded file.
  Future<String> uploadMenuFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final fileName = path.basename(filePath);
    final ext = path.extension(filePath).toLowerCase().replaceFirst('.', '');

    final mimeTypes = <String, String>{
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'pdf': 'application/pdf',
    };
    final contentType = mimeTypes[ext] ?? 'application/octet-stream';

    final data = await DineinApiService.invoke(
      'upload_menu_file',
      payload: {
        'fileName': fileName,
        'contentType': contentType,
        'fileData': base64Encode(bytes),
        ..._venueSessionPayload(),
      },
    );
    final result = data as Map<String, dynamic>;
    final signedUrl =
        result['signedUrl'] as String? ?? result['signed_url'] as String?;
    if (signedUrl == null || signedUrl.isEmpty) {
      throw Exception('Menu upload did not return a signed URL.');
    }
    return signedUrl;
  }

  /// Call the OCR edge function to extract menu items from a file.
  /// Returns a list of extracted draft menu items.
  Future<List<OcrDraftMenuItem>> extractMenuFromFile(String fileUrl) async {
    final result = await DineinApiService.invoke(
      'ocr_extract_menu',
      payload: {'fileUrl': fileUrl, ..._venueSessionPayload()},
    );
    final items =
        (result as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    return items.map((item) {
      final map = item as Map<String, dynamic>;
      return OcrDraftMenuItem(
        name: map['name'] as String? ?? 'Unnamed Item',
        description: map['description'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        category: map['category'] as String? ?? 'General',
        tags: const [],
        requiresReview: true,
      );
    }).toList();
  }

  /// Replace all menu items for a venue with new items.
  /// Deletes existing items first, then inserts new ones.
  Future<void> replaceVenueMenu(
    String venueId,
    List<OcrDraftMenuItem> draftItems,
  ) async {
    final menuItems = draftItems
        .map((item) => item.toMenuItem(venueId, id: _generateLocalId()))
        .toList();

    await DineinApiService.invoke(
      'replace_venue_menu',
      payload: {
        'venueId': venueId,
        'items': menuItems.map((item) => item.toJson()).toList(),
        ..._venueSessionPayload(),
      },
    );
    await _persistLocalMenuItems(venueId, menuItems);
    unawaited(
      _queueVenueBackfillSilently(
        venueId: venueId,
        limit: menuItems.length.clamp(1, 25).toInt(),
      ),
    );
  }

  Future<MenuImageGenerationResult> generateMenuItemImage(
    String itemId, {
    bool forceRegenerate = false,
  }) {
    return MenuImageGenerationService.instance.generateForItem(
      itemId: itemId,
      forceRegenerate: forceRegenerate,
    );
  }

  Future<MenuImageBackfillResult> backfillMissingMenuItemImages({
    required String venueId,
    int limit = 12,
    bool forceRegenerate = false,
  }) {
    return MenuImageGenerationService.instance.backfillMissingImages(
      venueId: venueId,
      limit: limit,
      forceRegenerate: forceRegenerate,
    );
  }

  Future<void> setMenuItemImageLock(String itemId, bool imageLocked) async {
    await DineinApiService.invoke(
      'update_menu_item',
      payload: {
        'itemId': itemId,
        'updates': {'image_locked': imageLocked},
        ..._venueSessionPayload(),
      },
    );
  }

  String _generateLocalId() => 'local-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _queueMenuItemImageGenerationSilently(String itemId) async {
    try {
      await generateMenuItemImage(itemId);
    } catch (_) {
      // Background queue attempts should never block CRUD flows.
    }
  }

  Future<void> _queueVenueBackfillSilently({
    required String venueId,
    required int limit,
  }) async {
    try {
      await backfillMissingMenuItemImages(venueId: venueId, limit: limit);
    } catch (_) {
      // Background queue attempts should never block OCR import or CRUD flows.
    }
  }

  Future<void> _persistLocalMenuItems(
    String venueId,
    List<MenuItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localMenuKey(venueId),
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _mergeAndPersistLocalMenuItems(
    String venueId,
    List<MenuItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final merged = <String, MenuItem>{
      for (final item in _readLocalMenuItemsByKey(
        prefs,
        _localMenuKey(venueId),
      ))
        item.id: item,
      for (final item in items) item.id: item,
    };
    await prefs.setString(
      _localMenuKey(venueId),
      jsonEncode(merged.values.map((item) => item.toJson()).toList()),
    );
  }

  List<MenuItem> _readLocalMenuItemsByKey(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
