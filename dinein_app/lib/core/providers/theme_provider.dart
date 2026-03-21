import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted theme mode preference using Riverpod v3 Notifier.
///
/// To prevent theme flicker on startup, call [ThemeNotifier.loadSavedTheme]
/// in `main()` before `runApp()`, then pass the result to `build()`.
final themeModeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _key = 'dinein_theme_mode';

  /// Pre-loaded theme mode set from `main()` before the first frame.
  static ThemeMode _initialThemeMode = ThemeMode.light;

  /// Call this in `main()` BEFORE `runApp()` to eliminate theme flicker.
  static Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == 'dark') {
      _initialThemeMode = ThemeMode.dark;
    } else if (value == 'system') {
      _initialThemeMode = ThemeMode.system;
    }
    // else keep default ThemeMode.light
  }

  @override
  ThemeMode build() {
    // Return the pre-loaded value — no async race, no flicker.
    return _initialThemeMode;
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    _initialThemeMode = next; // keep in sync for hot restarts
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDark => state == ThemeMode.dark;
}
