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

class SavedLocationsNotifier extends AsyncNotifier<Map<String, KitwePlace?>> {
  // backend IDs so we can PATCH / DELETE without a separate fetch
  final Map<String, int> _ids = {};

  @override
  Future<Map<String, KitwePlace?>> build() async {
    try {
      final resp = await ApiClient.dio.get(Endpoints.savedPlaces);
      final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
      final map = <String, KitwePlace?>{'home': null, 'work': null};
      for (final j in raw) {
        final label = j['label'] as String?;
        if (label == 'home' || label == 'work') {
          _ids[label!] = j['id'] as int;
          map[label] = KitwePlace(
            j['name'] as String,
            double.parse(j['latitude'].toString()),
            double.parse(j['longitude'].toString()),
          );
        }
      }
      return map;
    } catch (_) {
      return {'home': null, 'work': null};
    }
  }

  Future<void> set(String key, KitwePlace place) async {
    final current = state.asData?.value ?? {'home': null, 'work': null};
    state = AsyncData({...current, key: place});
    try {
      final body = {
        'label': key,
        'name': place.name,
        'address': place.name,
        'latitude': place.lat,
        'longitude': place.lng,
      };
      if (_ids.containsKey(key)) {
        final resp = await ApiClient.dio.patch(
            '${Endpoints.savedPlaces}${_ids[key]}/', data: body);
        _ids[key] = resp.data['id'] as int;
      } else {
        final resp = await ApiClient.dio.post(Endpoints.savedPlaces, data: body);
        _ids[key] = resp.data['id'] as int;
      }
    } catch (_) {}
  }

  Future<void> clear(String key) async {
    final current = state.asData?.value ?? {'home': null, 'work': null};
    state = AsyncData({...current, key: null});
    try {
      if (_ids.containsKey(key)) {
        await ApiClient.dio.delete('${Endpoints.savedPlaces}${_ids[key]}/');
        _ids.remove(key);
      }
    } catch (_) {}
  }
}

final savedLocationsProvider =
    AsyncNotifierProvider<SavedLocationsNotifier, Map<String, KitwePlace?>>(
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
