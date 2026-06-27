import 'dart:math';

class KitwePlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const KitwePlace(this.name, this.lat, this.lng, [this.tag]);
}

// Coordinates: OSM bounded-search where available, Gemini spatial data for gaps.
const kitwePlaces = <KitwePlace>[
  // ── City Centre ───────────────────────────────────────────────────────────
  KitwePlace('Kitwe CBD',               -12.8038,  28.2131, 'City Centre'),
  KitwePlace('Kitwe Bus Station',       -12.8060,  28.2140, 'Transport'),

  // ── Markets ───────────────────────────────────────────────────────────────
  KitwePlace('Chisokone Market',        -12.8181,  28.2070, 'Market'),

  // ── Shopping ─────────────────────────────────────────────────────────────
  KitwePlace('Mukuba Mall',             -12.8065,  28.2206, 'Shopping'),

  // ── Hospitals / Education ─────────────────────────────────────────────────
  KitwePlace('Kitwe Teaching Hospital', -12.7984,  28.2101, 'Hospital'),
  KitwePlace('Copperbelt University',   -12.8052,  28.2441, 'University'),

  // ── Sports ────────────────────────────────────────────────────────────────
  KitwePlace('Nkana Stadium',           -12.8471,  28.2112, 'Sports'),

  // ── Residential: Far North ───────────────────────────────────────────────
  KitwePlace('Garneton',                -12.7214,  28.2124, 'Residential'),
  KitwePlace('Kawama',                  -12.7485,  28.2502, 'Residential'),
  KitwePlace('Nakadoli',                -12.7661,  28.2572, 'Residential'),
  KitwePlace('Mindolo',                 -12.7915,  28.1938, 'Residential'),

  // ── Residential: North ───────────────────────────────────────────────────
  KitwePlace('Chimwemwe',               -12.7713,  28.2012, 'Residential'),
  KitwePlace('Twatasha',                -12.7758,  28.2215, 'Residential'),
  KitwePlace('Kwacha',                  -12.7842,  28.2619, 'Residential'),
  KitwePlace('Bulangililo',             -12.7697,  28.2238, 'Residential'),
  KitwePlace('Ipusukilo',               -12.7885,  28.2530, 'Residential'),
  KitwePlace('Buchi',                   -12.7900,  28.2071, 'Residential'),
  KitwePlace('Riverside',               -12.7977,  28.2526, 'Residential'),

  // ── Residential: Central ─────────────────────────────────────────────────
  KitwePlace('Parklands',               -12.8015,  28.2410, 'Residential'),
  KitwePlace('Nkana West',              -12.8285,  28.2120, 'Residential'),
  KitwePlace('Nkana East',              -12.8268,  28.2175, 'Residential'),

  // ── Residential: South ───────────────────────────────────────────────────
  KitwePlace('Wusakile',                -12.8492,  28.2161, 'Residential'),
  KitwePlace('Chamboli',                -12.8618,  28.2267, 'Residential'),
];

List<KitwePlace> searchPlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      kitwePlaces.firstWhere((p) => p.name == 'Kitwe CBD'),
      kitwePlaces.firstWhere((p) => p.name == 'Mukuba Mall'),
      kitwePlaces.firstWhere((p) => p.name == 'Copperbelt University'),
      kitwePlaces.firstWhere((p) => p.name == 'Chisokone Market'),
      kitwePlaces.firstWhere((p) => p.name == 'Kitwe Teaching Hospital'),
      kitwePlaces.firstWhere((p) => p.name == 'Nkana Stadium'),
    ];
  }
  final q = query.toLowerCase();
  return kitwePlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double privateFromRoadKm(double roadKm) => (roadKm * 7).clamp(15.0, 500.0);
double dynamicFromRoadKm(double roadKm) => (roadKm * 7 / 3).clamp(15.0, 500.0);

double estimatePrivateFare(double oLat, double oLng, double dLat, double dLng) {
  final km = haversineKm(oLat, oLng, dLat, dLng) * 1.35;
  return privateFromRoadKm(km);
}

double estimateDynamicFare(double oLat, double oLng, double dLat, double dLng) {
  final km = haversineKm(oLat, oLng, dLat, dLng) * 1.35;
  return dynamicFromRoadKm(km);
}
