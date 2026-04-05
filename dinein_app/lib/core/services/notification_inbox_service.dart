import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'web_badge_service.dart';

/// A single notification in the inbox.
class InboxNotification {
  final String id;
  final String title;
  final String body;
  final String? url;
  final String type;
  final bool read;
  final DateTime timestamp;

  const InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    this.url,
    this.type = 'info',
    this.read = false,
    required this.timestamp,
  });

  InboxNotification copyWith({bool? read}) => InboxNotification(
        id: id,
        title: title,
        body: body,
        url: url,
        type: type,
        read: read ?? this.read,
        timestamp: timestamp,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'url': url,
        'type': type,
        'read': read,
        'ts': timestamp.toIso8601String(),
      };

  factory InboxNotification.fromJson(Map<String, dynamic> json) {
    return InboxNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      url: json['url'] as String?,
      type: json['type'] as String? ?? 'info',
      read: json['read'] as bool? ?? false,
      timestamp: DateTime.tryParse(json['ts'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Persistent notification inbox backed by SharedPreferences.
///
/// Stores up to [_maxEntries] notifications as a JSON array.
/// Broadcasts unread count changes for reactive UI updates.
/// Integrates with the Badging API via [_onBadgeUpdate] callback.
class NotificationInboxService {
  NotificationInboxService._();

  static final NotificationInboxService instance = NotificationInboxService._();

  static const String _storageKey = 'dinein_notification_inbox';
  static const int _maxEntries = 200;

  List<InboxNotification> _items = [];
  bool _initialized = false;

  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  /// Stream of unread notification count changes.
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  /// Current unread count.
  int get unreadCount => _items.where((n) => !n.read).length;

  /// All inbox items, newest first.
  List<InboxNotification> get items => List.unmodifiable(_items);

  /// Callback invoked when badge count changes (for Badging API integration).
  VoidCallback? _onBadgeUpdate;

  /// Register a callback to update app badge when unread count changes.
  void setBadgeUpdateCallback(VoidCallback callback) {
    _onBadgeUpdate = callback;
  }

  /// Initialize the service — loads from storage.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromStorage();

    // Wire badge API updates
    setBadgeUpdateCallback(() {
      final count = unreadCount;
      if (count > 0) {
        WebBadgeService.instance.setBadge(count);
      } else {
        WebBadgeService.instance.clearBadge();
      }
    });

    _emitUnreadCount();
  }

  /// Add a new notification to the inbox.
  Future<void> add({
    required String id,
    required String title,
    required String body,
    String? url,
    String type = 'info',
  }) async {
    // Deduplicate by ID
    if (_items.any((n) => n.id == id)) return;

    _items.insert(
      0,
      InboxNotification(
        id: id,
        title: title,
        body: body,
        url: url,
        type: type,
        timestamp: DateTime.now(),
      ),
    );

    // Trim to max entries
    if (_items.length > _maxEntries) {
      _items = _items.sublist(0, _maxEntries);
    }

    await _saveToStorage();
    _emitUnreadCount();
  }

  /// Mark a single notification as read.
  Future<void> markRead(String id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(read: true);
    await _saveToStorage();
    _emitUnreadCount();
  }

  /// Mark all notifications as read.
  Future<void> markAllRead() async {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
        changed = true;
      }
    }
    if (!changed) return;
    await _saveToStorage();
    _emitUnreadCount();
  }

  /// Clear all notifications.
  Future<void> clear() async {
    _items.clear();
    await _saveToStorage();
    _emitUnreadCount();
  }

  // ─── Storage ───

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> decoded = json.decode(raw) as List<dynamic>;
      _items = decoded
          .map((e) => InboxNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('NotificationInboxService: load error: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(
        _items.map((n) => n.toJson()).toList(),
      );
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('NotificationInboxService: save error: $e');
    }
  }

  void _emitUnreadCount() {
    _unreadCountController.add(unreadCount);
    _onBadgeUpdate?.call();
  }

  /// Dispose the service.
  void dispose() {
    _unreadCountController.close();
  }
}
