import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dev/kitwe_places.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggle() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ── Saved locations (Home / Work) ─────────────────────────────────────────────

class SavedLocationsNotifier extends Notifier<Map<String, KitwePlace?>> {
  @override
  Map<String, KitwePlace?> build() => {'home': null, 'work': null};

  void set(String key, KitwePlace place) {
    state = {...state, key: place};
  }

  void clear(String key) {
    state = {...state, key: null};
  }
}

final savedLocationsProvider =
    NotifierProvider<SavedLocationsNotifier, Map<String, KitwePlace?>>(
        SavedLocationsNotifier.new);
