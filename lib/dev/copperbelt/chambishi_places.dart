import 'dart:math';

class ChambishiPlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const ChambishiPlace(this.name, this.lat, this.lng, [this.tag]);
}

// Coordinates marked (OSM) are from Overpass Turbo export — accurate.
// Coordinates marked (PIN) are user-verified pins — accurate.
// All coordinates in this file are confirmed — nothing approximate.
// Chambishi is a company town dominated by NFCA (Chinese copper mine) and
// the ZCCZ Multi-Facility Economic Zone (MFEZ).

const chambishiPlaces = <ChambishiPlace>[
  // ── Town Centre ───────────────────────────────────────────────────────────
  ChambishiPlace('Chambishi Market / Town Centre',  -12.6325,    28.0535,    'City Centre'),  // PIN
  ChambishiPlace('Chambishi Mine Township',          -12.6360,    28.0510,    'Residential'),  // PIN (historic core)

  // ── Hospitals / Clinics ───────────────────────────────────────────────────
  ChambishiPlace('Chambishi Mini Hospital',          -12.6393843, 28.0621008, 'Hospital'),     // OSM
  ChambishiPlace('Chambishi Mine Urban Health Centre',-12.6375060, 28.0626510,'Hospital'),     // OSM
  ChambishiPlace('Lulamba Health Post',              -12.6461950, 28.0678780, 'Hospital'),     // OSM
  ChambishiPlace('Sitwe Health Post',                -12.6273400, 28.0583140, 'Hospital'),     // OSM
  ChambishiPlace('Twaiteka Compound Health Post',    -12.6311860, 28.0757980, 'Hospital'),     // OSM
  ChambishiPlace('Plantsite Health Post',            -12.6595610, 28.0574950, 'Hospital'),     // OSM

  // ── Residential / Compounds ───────────────────────────────────────────────
  ChambishiPlace('Twaiteka / Twalubuka',             -12.6450,    28.0650,    'Residential'),  // PIN (high-density SE)
  ChambishiPlace('Mwambashi',                        -12.6150,    28.0280,    'Residential'),  // PIN (outer western fringe)
  ChambishiPlace('Plantsite',                        -12.6591,    28.0583,    'Residential'),  // PIN
  ChambishiPlace('Chambishi Compound',               -12.6322,    28.0775,    'Residential'),  // PIN (dense residential)

  // ── Mine Shift Pickup Points (highway bus stops) ──────────────────────────
  ChambishiPlace('NFCA Turn',                        -12.6584446, 28.0695751, 'Transport'),    // OSM
  ChambishiPlace('CCS Turn',                         -12.6671411, 28.0777219, 'Transport'),    // OSM
  ChambishiPlace('China Civil Engineering',          -12.6845360, 28.0923415, 'Transport'),    // OSM
  ChambishiPlace('Mukulumpe Mine',                   -12.6919260, 28.0983974, 'Transport'),    // OSM

  // ── Industrial Gates (mine & smelter drop-offs) ───────────────────────────
  ChambishiPlace('NFCA Mine Main Gate',              -12.6490,    28.0410,    'Transport'),    // PIN (underground mining)
  ChambishiPlace('Chambishi Copper Smelter (CCS)',   -12.6610,    28.0360,    'Transport'),    // PIN (custom smelter)
  ChambishiPlace('ZCCZ / MFEZ Gate',                 -12.6530,    28.0580,    'Transport'),    // PIN (economic zone entrance)

  // ── Road / Hiking Junctions ───────────────────────────────────────────────
  // T3 gateway — Chingola road meets Chambishi access roads
  ChambishiPlace('Chingola Road Junction (T3)',      -12.6565,    28.0682,    'Junction'),     // PIN
  // Sabina — M4 splits NE to Mufulira, M16 splits S to Kalulushi
  ChambishiPlace('Sabina Junction (Mufulira/Kalulushi Split)', -12.6675, 28.0980, 'Junction'), // PIN
  // OSM confirmed turn-offs on the T3
  ChambishiPlace('Kalulushi Turn Off',               -12.7163910, 28.1239090, 'Junction'),     // OSM
  ChambishiPlace('Mufulira Turn Off',                -12.7141142, 28.1171915, 'Junction'),     // OSM
];

List<ChambishiPlace> searchChambishiPlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      chambishiPlaces.firstWhere((p) => p.name == 'Chambishi Market / Town Centre'),
      chambishiPlaces.firstWhere((p) => p.name == 'NFCA Mine Main Gate'),
      chambishiPlaces.firstWhere((p) => p.name == 'NFCA Turn'),
      chambishiPlaces.firstWhere((p) => p.name == 'Chambishi Mine Township'),
      chambishiPlaces.firstWhere((p) => p.name == 'Twaiteka / Twalubuka'),
      chambishiPlaces.firstWhere((p) => p.name == 'Chambishi Copper Smelter (CCS)'),
    ];
  }
  final q = query.toLowerCase();
  return chambishiPlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

double chambishiHaversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
