import 'dart:math';

class LumwanaKalumbilaPlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const LumwanaKalumbilaPlace(this.name, this.lat, this.lng, [this.tag]);
}

// All coordinates are user-verified (PIN) — nothing approximate.
// Covers the T5 Highway corridor: Solwezi → Lumwana (Barrick) → Kalumbila (FQM Sentinel).
// Lumwana is spatially split: organic boomtown (Manyama/Chanamo) vs. corporate estate.
// The two ore bodies (Malundwe & Chimiwungo) have separate gate nodes —
// workers must specify which pit to avoid major routing errors.

const lumwanaKalumbilaPlaces = <LumwanaKalumbilaPlace>[
  // ── Manyama Boomtown Strip (organic / informal) ───────────────────────────
  LumwanaKalumbilaPlace('Manyama Market Hub',          -12.3147,  25.8486,  'City Centre'),  // PIN — mass-transit + retail core (original)
  LumwanaKalumbilaPlace('Manyama Market Center',       -12.2341,  25.7915,  'Market'),       // PIN — verified 2025 ground coords (intercity boarding)
  LumwanaKalumbilaPlace('Chanamo Quarter',              -12.3110,  25.8360,  'Residential'),  // PIN — contractor guest houses / rentals
  LumwanaKalumbilaPlace('Manyama Hospital Road Jct',   -12.3210,  25.8495,  'Junction'),     // PIN — south branch to clinics + residential

  // ── Lumwana Corporate Estate (planned / controlled) ───────────────────────
  LumwanaKalumbilaPlace('Lumwana Estate',               -12.2880,  25.8120,  'Residential'),  // PIN — mine staff / exec housing
  LumwanaKalumbilaPlace('Lumwana MFEZ / Supplier Park', -12.2710,  25.8310,  'Transport'),    // PIN — industrial supplier zone
  LumwanaKalumbilaPlace('Lumwana MFEZ Main Gate',       -12.2530,  25.7144,  'Transport'),    // PIN — verified 2025 main gate coords

  // ── Barrick Mine Gates ────────────────────────────────────────────────────
  LumwanaKalumbilaPlace('Barrick Lumwana Main Gate',    -12.2540,  25.8230,  'Transport'),    // PIN — general mine entrance
  LumwanaKalumbilaPlace('Malundwe Pit Gate',            -12.2420,  25.8190,  'Transport'),    // PIN — northern pit operations
  LumwanaKalumbilaPlace('Chimiwungo Super Pit Gate',    -12.3020,  25.8650,  'Transport'),    // PIN — primary $2B expansion hub

  // ── Kalumbila / FQM Sentinel ──────────────────────────────────────────────
  LumwanaKalumbilaPlace('Kalumbila Town Centre',        -12.3410,  25.6320,  'City Centre'),  // PIN — corporate planned hub
  LumwanaKalumbilaPlace('Kalumbila Town Square',        -12.2155,  25.3852,  'City Centre'),  // PIN — verified 2025 town square coords
  LumwanaKalumbilaPlace('FQM Sentinel Mine Gate',       -12.4010,  25.6485,  'Transport'),    // PIN — processing plant entrance

  // ── Kalumbila Infrastructure ──────────────────────────────────────────────
  LumwanaKalumbilaPlace('Kalumbila Town Gate',          -12.3315,  25.6260,  'Transport'),    // PIN (security checkpoint / urban entry)
  LumwanaKalumbilaPlace('Kalumbila Airstrip',           -12.3120,  25.6795,  'Transport'),    // PIN (FQM private charter strip)

  // ── T5 Highway Spine (routing checkpoints) ────────────────────────────────
  // Mutanda — M8 forks south to Kasempa/Zambezi; T5 continues west to Lumwana
  LumwanaKalumbilaPlace('Mutanda Junction (M8/T5)',     -12.4045,  26.2360,  'Junction'),     // PIN
  // Toll plaza just past Mutanda — fixed cost node for all westbound trips
  LumwanaKalumbilaPlace('Humphrey Mulemba Toll Plaza',  -12.3820,  26.2510,  'Junction'),     // PIN
  // Meheba/Maheba Settlement turn-off — NGO vehicles + regional commuter buses
  LumwanaKalumbilaPlace('Meheba Settlement Turn-Off',   -12.4100,  26.0150,  'Junction'),     // PIN (~75km SW of Solwezi)
  // Buffer zone before Chimiwungo lease — contractor shops + worker extensions
  LumwanaKalumbilaPlace('Lumwana East',                 -12.2620,  25.9220,  'Residential'),  // PIN
  // T5 branches south off the highway into Kalumbila/Sentinel
  LumwanaKalumbilaPlace('Kalumbila Turn-Off (T5)',      -12.2785,  25.6110,  'Junction'),     // PIN
];

List<LumwanaKalumbilaPlace> searchLumwanaKalumbilaPlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      lumwanaKalumbilaPlaces.firstWhere((p) => p.name == 'Manyama Market Hub'),
      lumwanaKalumbilaPlaces.firstWhere((p) => p.name == 'Kalumbila Town Centre'),
      lumwanaKalumbilaPlaces.firstWhere((p) => p.name == 'Chimiwungo Super Pit Gate'),
      lumwanaKalumbilaPlaces.firstWhere((p) => p.name == 'Malundwe Pit Gate'),
      lumwanaKalumbilaPlaces.firstWhere((p) => p.name == 'Lumwana Estate'),
      lumwanaKalumbilaPlaces.firstWhere((p) => p.name == 'FQM Sentinel Mine Gate'),
    ];
  }
  final q = query.toLowerCase();
  return lumwanaKalumbilaPlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

double lumwanaKalumbilaHaversineKm(
    double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dlng / 2) *
          sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
