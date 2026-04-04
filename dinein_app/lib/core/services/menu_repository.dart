import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:db_pkg/models/models.dart';
import 'api_invoker.dart';
import 'auth_repository.dart';
import 'dinein_api_service.dart';
import 'menu_image_generation_service.dart';

/// Repository for menu item data access via Supabase.
class MenuRepository {
  final ApiInvoker _invoke;

  MenuRepository._() : _invoke = DineinApiService.invoke;
  static final instance = MenuRepository._();

  /// Test-only constructor that accepts a mock invoker.
  MenuRepository.forTesting({required ApiInvoker invoker}) : _invoke = invoker;

  static const _localMenuPrefix = 'dinein.local_menu.';

  String _localMenuKey(String venueId) => '$_localMenuPrefix$venueId';

  Map<String, dynamic> _venueSessionPayload() {
    final session = AuthRepository.instance.currentVenueSession;
    if (session == null) return const {};
    final token = session.accessToken;
    if (token.isEmpty) return const {};
    return {
      'venue_session': {'access_token': token},
    };
  }

  /// Fetch all menu items for a venue.
  Future<List<MenuItem>> getMenuItems(
    String venueId, {
    bool useAdminSession = false,
  }) async {
    final data =
        await _invoke(
              'get_menu_items',
              useAdminSession: useAdminSession,
              payload: {'venueId': venueId},
            )
            as List<dynamic>;
    final items = data.map((e) => MenuItem.fromJson(e)).toList();
    final allPricesHidden =
        items.isNotEmpty && items.every((item) => item.priceHidden);
    if (items.isEmpty || allPricesHidden) {
      await _clearLocalMenuItems(venueId);
    } else {
      await _persistLocalMenuItems(venueId, items);
    }
    return items;
  }

  Future<MenuItem?> getMenuItemById(
    String itemId, {
    bool useAdminSession = false,
  }) async {
    final data = await _invoke(
      'get_menu_item_by_id',
      useAdminSession: useAdminSession,
      payload: {'itemId': itemId},
    );
    if (data == null) return null;
    return MenuItem.fromJson(data as Map<String, dynamic>);
  }

  /// Fetch the admin menu review queue across all venues.
  Future<List<AdminMenuQueueEntry>> getAdminMenuQueue() async {
    final data =
        await _invoke(
              'get_admin_menu_queue',
              useAdminSession: true,
            )
            as List<dynamic>;
    return data
        .map(
          (entry) => AdminMenuQueueEntry.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<AdminMenuCatalogEntry>> getAdminMenuCatalog() async {
    final data =
        await _invoke(
              'get_admin_menu_catalog',
              useAdminSession: true,
            )
            as List<dynamic>;
    return data
        .map(
          (entry) => AdminMenuCatalogEntry.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<AdminMenuGroupAssignment>> getAdminMenuGroupAssignments(
    String groupId,
  ) async {
    final data =
        await _invoke(
              'get_admin_menu_group_assignments',
              useAdminSession: true,
              payload: {'groupId': groupId},
            )
            as List<dynamic>;
    return data
        .map(
          (entry) => AdminMenuGroupAssignment.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> createAdminMenuGroups({
    required List<Map<String, dynamic>> items,
    List<String> venueIds = const [],
    bool assignAll = false,
  }) async {
    await _invoke(
      'create_admin_menu_groups',
      useAdminSession: true,
      payload: {'items': items, 'venueIds': venueIds, 'assignAll': assignAll},
    );
  }

  Future<void> assignAdminMenuGroup(
    String groupId, {
    List<String> venueIds = const [],
    bool assignAll = false,
  }) async {
    await _invoke(
      'assign_admin_menu_group',
      useAdminSession: true,
      payload: {
        'groupId': groupId,
        'venueIds': venueIds,
        'assignAll': assignAll,
      },
    );
  }

  Future<void> deleteAdminMenuGroup(String groupId) async {
    await _invoke(
      'delete_admin_menu_group',
      useAdminSession: true,
      payload: {'groupId': groupId},
    );
  }

  /// Fetch locally persisted menu items for a venue.
  Future<List<MenuItem>> getLocalMenuItems(String venueId) async {
    final prefs = await SharedPreferences.getInstance();
    return _readLocalMenuItemsByKey(prefs, _localMenuKey(venueId));
  }

  /// Toggle availability of a menu item.
  Future<void> toggleAvailability(String itemId, bool isAvailable) async {
    await _invoke(
      'toggle_menu_item_availability',
      payload: {
        'itemId': itemId,
        'isAvailable': isAvailable,
        ..._venueSessionPayload(),
      },
    );
    await _updateLocalMenuItemById(
      itemId,
      (item) => item.copyWith(isAvailable: isAvailable),
    );
  }

  /// Create a new menu item.
  Future<MenuItem> createMenuItem(MenuItem item) async {
    final data = await _invoke(
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
    Map<String, dynamic> updates, {
    bool useAdminSession = false,
  }) async {
    final data = await _invoke(
      'update_menu_item',
      useAdminSession: useAdminSession,
      payload: {
        'itemId': itemId,
        'updates': updates,
        ..._venueSessionPayload(),
      },
    );
    if (!useAdminSession && data is Map<String, dynamic>) {
      final updated = MenuItem.fromJson(data);
      await _mergeAndPersistLocalMenuItems(updated.venueId, [updated]);
    }
  }

  /// Persist the ordered guest highlight selection for a venue.
  Future<List<MenuItem>> setMenuItemHighlights(
    String venueId,
    List<String> orderedItemIds,
  ) async {
    final normalizedIds = <String>[];
    for (final rawId in orderedItemIds) {
      final id = rawId.trim();
      if (id.isEmpty || normalizedIds.contains(id)) continue;
      normalizedIds.add(id);
      if (normalizedIds.length == 3) break;
    }

    final data = await _invoke(
      'set_menu_item_highlights',
      payload: {
        'venueId': venueId,
        'itemIds': normalizedIds,
        ..._venueSessionPayload(),
      },
    );
    final items = (data as List<dynamic>)
        .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
        .toList();
    await _persistLocalMenuItems(venueId, items);
    return items;
  }

  /// Delete a menu item.
  Future<void> deleteMenuItem(String itemId) async {
    await _invoke(
      'delete_menu_item',
      payload: {'itemId': itemId, ..._venueSessionPayload()},
    );
    await _removeLocalMenuItemById(itemId);
  }

  Future<MenuImageGenerationResult> generateMenuItemImage(
    String itemId, {
    String? venueId,
    bool forceRegenerate = false,
    bool useAdminSession = false,
  }) {
    return MenuImageGenerationService.instance.generateForItem(
      itemId: itemId,
      venueId: venueId,
      forceRegenerate: forceRegenerate,
      useAdminSession: useAdminSession,
    );
  }

  Future<MenuImageBackfillResult> backfillMissingMenuItemImages({
    required String venueId,
    int limit = 12,
    bool forceRegenerate = false,
    bool useAdminSession = false,
  }) {
    return MenuImageGenerationService.instance.backfillMissingImages(
      venueId: venueId,
      limit: limit,
      forceRegenerate: forceRegenerate,
      useAdminSession: useAdminSession,
    );
  }

  Future<void> setMenuItemImageLock(
    String itemId,
    bool imageLocked, {
    bool useAdminSession = false,
  }) async {
    await _invoke(
      'update_menu_item',
      useAdminSession: useAdminSession,
      payload: {
        'itemId': itemId,
        'updates': {'image_locked': imageLocked},
        ..._venueSessionPayload(),
      },
    );
    if (useAdminSession) return;
    await _updateLocalMenuItemById(
      itemId,
      (item) => item.copyWith(imageLocked: imageLocked),
    );
  }

  Future<void> _queueMenuItemImageGenerationSilently(String itemId) async {
    try {
      await generateMenuItemImage(itemId);
    } catch (_) {
      // Background queue attempts should never block CRUD flows.
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

  Future<void> _clearLocalMenuItems(String venueId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localMenuKey(venueId));
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

  Future<void> _updateLocalMenuItemById(
    String itemId,
    MenuItem Function(MenuItem item) transform,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(_localMenuPrefix),
    )) {
      final items = _readLocalMenuItemsByKey(prefs, key);
      var didChange = false;
      final updatedItems = items.map((item) {
        if (item.id != itemId) return item;
        didChange = true;
        return transform(item);
      }).toList();
      if (!didChange) continue;
      await prefs.setString(
        key,
        jsonEncode(updatedItems.map((item) => item.toJson()).toList()),
      );
    }
  }

  Future<void> _removeLocalMenuItemById(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(_localMenuPrefix),
    )) {
      final items = _readLocalMenuItemsByKey(prefs, key);
      final updatedItems = items
          .where((item) => item.id != itemId)
          .toList(growable: false);
      if (updatedItems.length == items.length) continue;
      if (updatedItems.isEmpty) {
        await prefs.remove(key);
        continue;
      }
      await prefs.setString(
        key,
        jsonEncode(updatedItems.map((item) => item.toJson()).toList()),
      );
    }
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
