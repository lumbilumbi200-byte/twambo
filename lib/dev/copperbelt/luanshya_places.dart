import 'dart:math';

class LuanshyaPlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const LuanshyaPlace(this.name, this.lat, this.lng, [this.tag]);
}

// Coordinates marked (OSM) are from Overpass Turbo export — accurate.
// Coordinates marked (PIN) are user-verified pins — accurate.
// All coordinates in this file are confirmed — nothing approximate.
// Luanshya is a bifurcated company town: municipal CBD on the east,
// Roan Antelope Mine townships on the west.

const luanshyaPlaces = <LuanshyaPlace>[
  // ── City Centre (eastern strip) ───────────────────────────────────────────
  LuanshyaPlace('Luanshya CBD',                -13.1360,    28.4165,    'City Centre'),  // PIN
  LuanshyaPlace('Luanshya Bus Station',         -13.1392,    28.4135,    'Transport'),    // PIN
  LuanshyaPlace('Luanshya Town Avenue',         -13.1288,    28.4173,    'Transport'),    // PIN (main road intercity boarding strip)

  // ── Shopping ──────────────────────────────────────────────────────────────
  LuanshyaPlace('Shoprite Luanshya',            -13.1296961, 28.4184964, 'Shopping'),     // OSM
  LuanshyaPlace('Z Mart',                       -13.1296016, 28.4184936, 'Shopping'),     // OSM
  LuanshyaPlace('Choppies Luanshya',            -13.1319324, 28.4206708, 'Shopping'),     // OSM
  LuanshyaPlace('PEP Luanshya',                 -13.1320938, 28.4204128, 'Shopping'),     // OSM

  // ── Hospitals / Clinics ───────────────────────────────────────────────────
  LuanshyaPlace('Thomson District General Hospital', -13.1352, 28.4069,  'Hospital'),     // PIN
  LuanshyaPlace('Roan Antelope General Hospital',    -13.1415, 28.3582,  'Hospital'),     // PIN
  LuanshyaPlace('SDA Health Centre',            -13.1034239, 28.3313332, 'Hospital'),     // OSM
  LuanshyaPlace('Kawama Urban Health Centre',   -13.1213939, 28.3100336, 'Hospital'),     // OSM

  // ── Residential: East (CBD side) ─────────────────────────────────────────
  LuanshyaPlace('Mikomfwa',                     -13.1480,    28.4230,    'Residential'),  // PIN (dense, southern edge of town)

  // ── Residential: Roan Mine Townships ─────────────────────────────────────
  LuanshyaPlace('Roan',                         -13.1415,    28.3840,    'Residential'),  // PIN (township center, Sections 1-9)
  LuanshyaPlace('Mpatamatu',                    -13.1550,    28.3120,    'Residential'),  // PIN (outer mine township, ~10km west of CBD)
  LuanshyaPlace('Kawama',                       -13.1199708, 28.3097312, 'Residential'),  // OSM

  // ── Residential: Mine Sections (western grid) ─────────────────────────────
  LuanshyaPlace('Section 21',                   -13.0988509, 28.3284468, 'Residential'),  // OSM
  LuanshyaPlace('Section 22',                   -13.1054240, 28.3345566, 'Residential'),  // OSM
  LuanshyaPlace('Section 23',                   -13.1071242, 28.3278779, 'Residential'),  // OSM
  LuanshyaPlace('Section 24',                   -13.1080350, 28.3241372, 'Residential'),  // OSM
  LuanshyaPlace('Section 25',                   -13.1076782, 28.3175988, 'Residential'),  // OSM
  LuanshyaPlace('Section 26',                   -13.0997427, 28.3165156, 'Residential'),  // OSM
  LuanshyaPlace('Section 27',                   -13.0996668, 28.3083679, 'Residential'),  // OSM

  // ── Industrial Anchors ────────────────────────────────────────────────────
  LuanshyaPlace('CLM Baluba Mine Gate',         -13.0880,    28.4110,    'Transport'),    // PIN (northern, toward Kitwe highway)
  LuanshyaPlace('ZAMEFA Plant',                  -13.1235,    28.4210,    'Transport'),    // PIN (copper wire/rod factory)

  // ── Road / Hiking Junctions ───────────────────────────────────────────────
  // T3 Highway splitter — vehicles either continue Kitwe↔Ndola or turn onto M6 into Luanshya
  LuanshyaPlace('Fisenge Junction (T3 / M6)',   -13.0420,    28.4320,    'Junction'),     // PIN
  LuanshyaPlace('Roan-Mpatamatu Junction',       -13.1485,    28.3780,    'Junction'),     // PIN
  LuanshyaPlace('Kitwe Road Exit (Section 27)',  -13.1098,    28.3845,    'Junction'),     // PIN
  LuanshyaPlace('Section 27 Trail Junction',     -13.1165,    28.3750,    'Junction'),     // PIN
];

List<LuanshyaPlace> searchLuanshyaPlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      luanshyaPlaces.firstWhere((p) => p.name == 'Luanshya CBD'),
      luanshyaPlaces.firstWhere((p) => p.name == 'Luanshya Bus Station'),
      luanshyaPlaces.firstWhere((p) => p.name == 'Roan'),
      luanshyaPlaces.firstWhere((p) => p.name == 'Mpatamatu'),
      luanshyaPlaces.firstWhere((p) => p.name == 'Section 22'),
      luanshyaPlaces.firstWhere((p) => p.name == 'Kawama'),
    ];
  }
  final q = query.toLowerCase();
  return luanshyaPlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

double luanshyaHaversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
