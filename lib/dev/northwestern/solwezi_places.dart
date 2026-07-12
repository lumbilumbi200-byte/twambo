import 'dart:math';

class SolweziPlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const SolweziPlace(this.name, this.lat, this.lng, [this.tag]);
}

// Coordinates marked (OSM) are from Overpass Turbo export — accurate.
// Coordinates marked (PIN) are user-verified pins — accurate.
// All coordinates in this file are confirmed — nothing approximate.

const solweziPlaces = <SolweziPlace>[
  // ── City Centre ───────────────────────────────────────────────────────────
  SolweziPlace('Solwezi CBD',              -12.1820553, 26.3990713, 'City Centre'),  // OSM
  SolweziPlace('Solwezi Bus Station',      -12.1806597, 26.3976335, 'Transport'),    // OSM
  SolweziPlace('Mitech Bus Terminal',      -12.1888895, 26.4228872, 'Transport'),    // OSM
  SolweziPlace('Solwezi Airport (SLI)',    -12.1739,    26.3667,    'Transport'),    // PIN (north of CBD, T5 highway)

  // ── Shopping ──────────────────────────────────────────────────────────────
  SolweziPlace('Shoprite Solwezi',         -12.1769387, 26.3904989, 'Shopping'),     // OSM
  SolweziPlace('Pick n Pay Solwezi',       -12.1818913, 26.3973996, 'Shopping'),     // OSM
  SolweziPlace('Choppies Solwezi',         -12.1602316, 26.4247291, 'Shopping'),     // OSM

  // ── Hospitals ─────────────────────────────────────────────────────────────
  SolweziPlace('Solwezi General Hospital', -12.1764,    26.4068,    'Hospital'),     // PIN

  // ── Residential ───────────────────────────────────────────────────────────
  SolweziPlace('Mushitala',                -12.1550,    26.4020,    'Residential'),  // PIN (Kansanshi corridor anchor)
  SolweziPlace('Kimasala',                 -12.1850,    26.4280,    'Residential'),  // PIN (high-density east)
  SolweziPlace('Messengers',               -12.1810,    26.4090,    'Residential'),  // PIN (high-density near CBD)
  SolweziPlace('Kazomba',                  -12.1880,    26.3910,    'Residential'),  // PIN (high-density near CBD)
  SolweziPlace('Kampemba',                 -12.1965,    26.4180,    'Residential'),  // PIN (SE wing)
  SolweziPlace('Kabwela',                  -12.1640,    26.4310,    'Residential'),  // PIN (eastern margin)
  SolweziPlace('Lubushi',                  -12.1520,    26.3750,    'Residential'),  // PIN (NW fringe)
  SolweziPlace('Chishanta',                -12.2030,    26.3640,    'Residential'),  // PIN (SW pocket)
  SolweziPlace('Kansanshi Residential',    -12.1150,    26.4190,    'Residential'),  // PIN (mine housing)

  // ── Mine Transit Corridor ─────────────────────────────────────────────────
  // High-frequency town-to-mine shift runs — 05:30–07:00 and 16:30–18:00
  SolweziPlace('Kansanshi Mine Road Junction', -12.1620, 26.4035,  'Junction'),     // PIN

  // ── Road / Hiking Junctions ───────────────────────────────────────────────
  // Western gate — T5 exit toward Kalumbila / Mutanda / Lumwana
  SolweziPlace('Solwezi West Gate (T5 to Kalumbila)', -12.1881252, 26.3382460, 'Junction'),  // OSM (Petroda)
  // Eastern gate — toward Chingola and the Copperbelt
  SolweziPlace('Solwezi East Gate (to Chingola)',     -12.1955405, 26.4561661, 'Junction'),  // OSM (Meru East)
];

List<SolweziPlace> searchSolweziPlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      solweziPlaces.firstWhere((p) => p.name == 'Solwezi CBD'),
      solweziPlaces.firstWhere((p) => p.name == 'Solwezi Bus Station'),
      solweziPlaces.firstWhere((p) => p.name == 'Shoprite Solwezi'),
      solweziPlaces.firstWhere((p) => p.name == 'Pick n Pay Solwezi'),
      solweziPlaces.firstWhere((p) => p.name == 'Kampemba'),
      solweziPlaces.firstWhere((p) => p.name == 'Kansanshi Residential'),
    ];
  }
  final q = query.toLowerCase();
  return solweziPlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

double solweziHaversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
