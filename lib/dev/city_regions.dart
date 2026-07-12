import 'dart:math';

class CityRegion {
  final String id;          // slug used in place file routing
  final String name;        // display name
  final String province;
  final double centerLat;
  final double centerLng;
  final double radiusKm;    // detection radius — inside = user is in this city

  const CityRegion({
    required this.id,
    required this.name,
    required this.province,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
  });
}

// ── Covered cities ────────────────────────────────────────────────────────────
// Radius is set to the urban boundary, not the administrative district.
// Intentionally generous so peri-urban areas resolve correctly.

const List<CityRegion> kCityRegions = [
  // ── Copperbelt Province ───────────────────────────────────────────────────
  CityRegion(
    id: 'ndola', name: 'Ndola', province: 'Copperbelt',
    centerLat: -12.9580, centerLng: 28.6366, radiusKm: 18,
  ),
  CityRegion(
    id: 'kitwe', name: 'Kitwe', province: 'Copperbelt',
    centerLat: -12.8024, centerLng: 28.2132, radiusKm: 20,
  ),
  CityRegion(
    id: 'chingola', name: 'Chingola', province: 'Copperbelt',
    centerLat: -12.5266, centerLng: 27.8590, radiusKm: 16,
  ),
  CityRegion(
    id: 'luanshya', name: 'Luanshya', province: 'Copperbelt',
    centerLat: -13.1348, centerLng: 28.4162, radiusKm: 14,
  ),
  CityRegion(
    id: 'chililabombwe', name: 'Chililabombwe', province: 'Copperbelt',
    centerLat: -12.3606, centerLng: 27.8310, radiusKm: 12,
  ),
  CityRegion(
    id: 'chambishi', name: 'Chambishi', province: 'Copperbelt',
    centerLat: -12.6500, centerLng: 28.0400, radiusKm: 10,
  ),

  // ── Northwestern Province ─────────────────────────────────────────────────
  CityRegion(
    id: 'solwezi', name: 'Solwezi', province: 'Northwestern',
    centerLat: -12.1744, centerLng: 26.3969, radiusKm: 14,
  ),
  CityRegion(
    id: 'lumwana_kalumbila', name: 'Lumwana / Kalumbila', province: 'Northwestern',
    centerLat: -12.0933, centerLng: 25.8520, radiusKm: 20,
  ),

  // ── Southern Province ─────────────────────────────────────────────────────
  CityRegion(
    id: 'livingstone', name: 'Livingstone', province: 'Southern',
    centerLat: -17.8543, centerLng: 25.8553, radiusKm: 18,
  ),
  CityRegion(
    id: 'choma', name: 'Choma', province: 'Southern',
    centerLat: -16.8072, centerLng: 26.9820, radiusKm: 14,
  ),
  CityRegion(
    id: 'mazabuka', name: 'Mazabuka', province: 'Southern',
    centerLat: -15.8614, centerLng: 27.7596, radiusKm: 12,
  ),
  CityRegion(
    id: 'monze', name: 'Monze', province: 'Southern',
    centerLat: -16.2752, centerLng: 27.4750, radiusKm: 12,
  ),
];

// ── Haversine helper ──────────────────────────────────────────────────────────

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
          sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * asin(sqrt(a));
}

// ── Detection API ─────────────────────────────────────────────────────────────

/// Returns the city the user is currently in, or null if outside all covered areas.
CityRegion? detectCity(double lat, double lng) {
  CityRegion? best;
  double bestDist = double.infinity;

  for (final region in kCityRegions) {
    final dist = _haversineKm(lat, lng, region.centerLat, region.centerLng);
    if (dist <= region.radiusKm && dist < bestDist) {
      best = region;
      bestDist = dist;
    }
  }
  return best;
}

/// Returns the nearest city regardless of radius — used as fallback when
/// the user is between cities (e.g. on the highway between Kitwe and Ndola).
CityRegion nearestCity(double lat, double lng) {
  CityRegion nearest = kCityRegions.first;
  double bestDist = double.infinity;
  for (final region in kCityRegions) {
    final dist = _haversineKm(lat, lng, region.centerLat, region.centerLng);
    if (dist < bestDist) {
      nearest = region;
      bestDist = dist;
    }
  }
  return nearest;
}

/// Provinces live but not yet open for intercity travel.
const kComingSoonProvinces = {'Southern'};

/// Cities available for intercity (long-distance) trips right now.
/// Copperbelt + Northwestern only — Southern launches later.
List<CityRegion> get intercityCities =>
    kCityRegions.where((r) => !kComingSoonProvinces.contains(r.province)).toList();

/// Groups cities by province for the long-distance From/To picker.
Map<String, List<CityRegion>> get citiesByProvince {
  final map = <String, List<CityRegion>>{};
  for (final r in kCityRegions) {
    map.putIfAbsent(r.province, () => []).add(r);
  }
  return map;
}

/// Groups only the intercity-available cities by province.
Map<String, List<CityRegion>> get intercityCitiesByProvince {
  final map = <String, List<CityRegion>>{};
  for (final r in intercityCities) {
    map.putIfAbsent(r.province, () => []).add(r);
  }
  return map;
}

/// Provinces that are in kCityRegions but blocked from intercity travel.
Map<String, List<CityRegion>> get comingSoonCitiesByProvince {
  final map = <String, List<CityRegion>>{};
  for (final r in kCityRegions) {
    if (kComingSoonProvinces.contains(r.province)) {
      map.putIfAbsent(r.province, () => []).add(r);
    }
  }
  return map;
}
