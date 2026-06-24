import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
import '../dev/kitwe_places.dart';
import '../dev/mock_trips.dart';

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

// ── Unread notification count (rider bell badge) ──────────────────────────────

final unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) async {
  if (kUseMockData) return 0;
  try {
    final resp = await ApiClient.dio.get(Endpoints.notifications);
    final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
    return raw.where((n) => n['is_read'] == false).length;
  } catch (_) {
    return 0;
  }
});
