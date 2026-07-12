import 'dart:math';

class KitwePlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const KitwePlace(this.name, this.lat, this.lng, [this.tag]);
}

// Coordinates marked (PIN) are user-verified — accurate.
// Coordinates marked (~) are approximate from earlier build — verify on Google Maps.

const kitwePlaces = <KitwePlace>[
  // ── City Centre ───────────────────────────────────────────────────────────
  KitwePlace('Kitwe CBD',                  -12.8015,    28.2205,    'City Centre'),  // PIN (Obote Ave hub)
  KitwePlace('Kitwe Bus Station',          -12.8015,    28.2205,    'Transport'),    // PIN (Obote Ave minibus terminal)

  // ── Markets ───────────────────────────────────────────────────────────────
  KitwePlace('Chisokone Market',           -12.8035,    28.2195,    'Market'),       // PIN

  // ── Shopping ─────────────────────────────────────────────────────────────
  KitwePlace('Mukuba Mall',                -12.8040,    28.2275,    'Shopping'),     // PIN
  KitwePlace('ECL Mall',                   -12.7995,    28.2210,    'Shopping'),     // PIN (Freedom Avenue)

  // ── Hospitals ─────────────────────────────────────────────────────────────
  KitwePlace('Kitwe Teaching Hospital',    -12.7978,    28.2102,    'Hospital'),     // PIN
  KitwePlace('Wusakile Mine Hospital',     -12.8390,    28.2280,    'Hospital'),     // PIN
  KitwePlace('Sinozam Hospital',           -12.8210,    28.2040,    'Hospital'),     // PIN

  // ── Universities ──────────────────────────────────────────────────────────
  KitwePlace('Copperbelt University',      -12.8052,    28.2441,    'University'),   // ~

  // ── Sports ────────────────────────────────────────────────────────────────
  KitwePlace('Nkana Stadium',              -12.8471,    28.2112,    'Sports'),       // ~

  // ── Residential: Far North ───────────────────────────────────────────────
  KitwePlace('Garneton',                   -12.7214,    28.2124,    'Residential'),  // ~
  KitwePlace('Kawama',                     -12.7485,    28.2502,    'Residential'),  // ~
  KitwePlace('Chachacha',                  -12.7480,    28.2380,    'Residential'),  // PIN (northern outer node)
  KitwePlace('Nakadoli',                   -12.7661,    28.2572,    'Residential'),  // ~

  // ── Residential: North ───────────────────────────────────────────────────
  KitwePlace('Chimwemwe',                  -12.7610,    28.2250,    'Residential'),  // PIN (high-density)
  KitwePlace('Twatasha',                   -12.7758,    28.2215,    'Residential'),  // ~
  KitwePlace('Kwacha',                     -12.7842,    28.2619,    'Residential'),  // ~
  KitwePlace('Bulangililo',                -12.7697,    28.2238,    'Residential'),  // ~
  KitwePlace('Ipusukilo',                  -12.7885,    28.2530,    'Residential'),  // ~
  KitwePlace('Buchi / Kamitondo',          -12.7740,    28.2190,    'Residential'),  // PIN
  KitwePlace('Mindolo',                    -12.8050,    28.1880,    'Residential'),  // PIN (western mine housing)

  // ── Residential: Central ─────────────────────────────────────────────────
  KitwePlace('Parklands',                  -12.7930,    28.2315,    'Residential'),  // PIN
  KitwePlace('Riverside',                  -12.7830,    28.2440,    'Residential'),  // PIN (near CBU)
  KitwePlace('Nkana West',                 -12.8120,    28.2120,    'Residential'),  // PIN (historic mine exec suburb)
  KitwePlace('Nkana East',                 -12.8090,    28.2390,    'Residential'),  // PIN

  // ── Residential: South ───────────────────────────────────────────────────
  KitwePlace('Wusakile',                   -12.8410,    28.2320,    'Residential'),  // PIN (mine shaft area)
  KitwePlace('Ndeke',                      -12.8550,    28.2450,    'Residential'),  // PIN (SE, Ndeke Village/Extension)
  KitwePlace('Chamboli',                   -12.8618,    28.2267,    'Residential'),  // ~

  // ── Mine Gates (shift-change pickup nodes) ───────────────────────────────
  KitwePlace('Mopani Nkana Main Gate',     -12.8115,    28.2160,    'Transport'),    // PIN (concentrator + smelter entry)
  KitwePlace('SOB Shaft Access',           -12.8360,    28.2005,    'Transport'),    // PIN (South Ore Body, underground shafts)

  // ── Road / Junctions ─────────────────────────────────────────────────────
  // Northern approach — T3 from Chingola/Chambishi; right = Chibuluma/Kalulushi, straight = CBD
  KitwePlace('T3 / Chibuluma Junction',    -12.7790,    28.2070,    'Junction'),     // PIN
  // Southern boundary — T3 exit toward Ndola; ties Ndeke/Wusakile traffic to inter-city pipeline
  KitwePlace('T3 / President Ave South',   -12.8220,    28.2395,    'Junction'),     // PIN
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

double privateFromRoadKm(double roadKm) => (roadKm * 7).clamp(25.0, 500.0);
double dynamicFromRoadKm(double roadKm) => (roadKm * 7 / 3).clamp(15.0, 500.0);

double estimatePrivateFare(double oLat, double oLng, double dLat, double dLng) {
  final km = haversineKm(oLat, oLng, dLat, dLng) * 1.35;
  return privateFromRoadKm(km);
}

double estimateDynamicFare(double oLat, double oLng, double dLat, double dLng) {
  final km = haversineKm(oLat, oLng, dLat, dLng) * 1.35;
  return dynamicFromRoadKm(km);
}
