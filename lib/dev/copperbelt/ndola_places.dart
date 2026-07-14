import 'dart:math';

class NdolaPlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const NdolaPlace(this.name, this.lat, this.lng, [this.tag]);
}

// Coordinates marked (OSM) are from Overpass Turbo export — accurate.
// Coordinates marked (PIN) are user-verified pins — accurate.
// Coordinates marked (~) are still approximate — verify on Google Maps.
// Ndola is the Copperbelt's administrative and commercial capital.

const ndolaPlaces = <NdolaPlace>[
  // ── City Centre ───────────────────────────────────────────────────────────
  NdolaPlace('Ndola CBD',                   -12.9680,    28.6430,    'City Centre'),  // PIN (President Ave)
  NdolaPlace('Ndola Bus Station',           -12.9686005, 28.6495389, 'Transport'),    // OSM
  NdolaPlace('Ndola Town Centre TC Hub',    -12.9270,    28.6415,    'Transport'),    // PIN (northern transit hub — intercity boarding)
  NdolaPlace('Ndola Stadium Area (T3)',     -12.9268,    28.6015,    'Transport'),    // PIN (T3 highway approach node near stadium)
  NdolaPlace('Masala Bus Station',          -12.9973932, 28.6429534, 'Transport'),    // OSM
  NdolaPlace('SMK International Airport',   -12.9150,    28.5320,    'Transport'),    // PIN (new airport, 15km west on T3)

  // ── Shopping ─────────────────────────────────────────────────────────────
  NdolaPlace('Jacaranda Mall',              -13.0047795, 28.6494808, 'Shopping'),     // OSM
  NdolaPlace('Shoprite CBD',                -13.0053858, 28.6499372, 'Shopping'),     // OSM
  NdolaPlace('Shoprite Northrise',          -12.9744523, 28.6479189, 'Shopping'),     // OSM
  NdolaPlace('Pick n Pay',                  -12.9603472, 28.6322810, 'Shopping'),     // OSM
  NdolaPlace('Choppies',                    -12.9808608, 28.6380336, 'Shopping'),     // OSM
  NdolaPlace('Kansenshi Shops',             -12.9595975, 28.6316389, 'Shopping'),     // OSM
  NdolaPlace('Lubuto West Market',          -13.0072183, 28.6128105, 'Market'),       // OSM

  // ── Hospitals ─────────────────────────────────────────────────────────────
  NdolaPlace('Ndola Central Hospital',              -12.9700,    28.6339,    'Hospital'),  // PIN
  NdolaPlace('Arthur Davison Hospital',             -12.9479,    28.6476,    'Hospital'),  // PIN
  NdolaPlace('Northern Command Military Hospital',  -12.9910772, 28.6543767, 'Hospital'),  // OSM
  NdolaPlace('Lubuto Clinic',                       -13.0094866, 28.6202,    'Hospital'),  // OSM

  // ── Landmarks ─────────────────────────────────────────────────────────────
  // NOTE: second pin at -12.9610, 28.5720 (near T3) disputes this location — verify
  NdolaPlace('Levy Mwanawasa Stadium',      -12.9750,    28.6114,    'Landmark'),     // PIN (surge multiplier: 3km radius on match days)
  NdolaPlace('Ndola Golf Club',             -12.9590,    28.6465,    'Landmark'),     // PIN (premium hospitality; high-end client dispatch)
  // ~15km west along T3 into the bush — fixed rural out-of-bounds tariff
  NdolaPlace('Dag Hammarskjöld Crash Site', -12.9710,    28.5210,    'Landmark'),     // PIN (distal historical tourism outlier)

  // ── Residential: North ───────────────────────────────────────────────────
  NdolaPlace('Kawama',                      -12.9280981, 28.6303496, 'Residential'),  // OSM
  NdolaPlace('Kawama South',                -12.9150,    28.6320,    'Residential'),  // PIN (distal N frontier; tiered distance multiplier)
  NdolaPlace('Pamodzi',                     -12.9316769, 28.6228784, 'Residential'),  // OSM
  NdolaPlace('Chipulukusu',                 -12.9322604, 28.6557945, 'Residential'),  // OSM
  NdolaPlace('Chifubu',                     -12.9350,    28.6380,    'Residential'),  // PIN (Chifubu Market hub)
  NdolaPlace('Chifubu Compound',            -12.9360,    28.6490,    'Residential'),  // PIN (high-density worker core)
  NdolaPlace('Northrise',                   -12.9515,    28.6490,    'Residential'),  // PIN
  NdolaPlace('Hillcrest',                   -12.9590,    28.6270,    'Residential'),  // PIN

  // ── Residential: Central ─────────────────────────────────────────────────
  NdolaPlace('Kansenshi',                   -12.9564192, 28.6233072, 'Residential'),  // OSM
  NdolaPlace('Kansenshi Premium',           -12.9615,    28.6310,    'Residential'),  // PIN (upper-tier; consistent business commuter traffic)
  NdolaPlace('Kanini',                      -12.9730,    28.6250,    'Residential'),  // PIN (mid-premium; bridges industrial fringe to CBD loop)
  NdolaPlace('Ndola Central GRA',           -12.9680,    28.6410,    'Residential'),  // PIN (elite admin residential; expansive plots)
  NdolaPlace('Ndeke',                       -13.0180,    28.6190,    'Residential'),  // PIN (SW quadrant)
  NdolaPlace('Ndeke East',                  -12.9980,    28.6710,    'Residential'),  // PIN (fast-growing sector past the river line)
  NdolaPlace('Itawa',                       -12.9850,    28.6630,    'Residential'),  // PIN (SE, near old airport)
  NdolaPlace('Itawa Extension',             -12.9910,    28.6590,    'Residential'),  // PIN (premium; clean asphalt access near airport axis)
  NdolaPlace('Kabushi',                     -12.9910,    28.6520,    'Residential'),  // PIN
  NdolaPlace('Kabushi Compound',            -12.9940,    28.6350,    'Residential'),  // PIN (high-density; micro-trips toward industrial mills)
  NdolaPlace('Twapia',                      -12.9730,    28.5850,    'Residential'),  // PIN (highway cluster)
  NdolaPlace('Twapia Extension',            -12.9690,    28.5810,    'Residential'),  // PIN (western boundary; dual-carriageway volume node)

  // ── Residential: South ───────────────────────────────────────────────────
  NdolaPlace('Masala',                      -12.9860,    28.6350,    'Residential'),  // PIN (market hub)
  NdolaPlace('Masala Compound',             -12.9880,    28.6270,    'Residential'),  // PIN (dense pedestrian market traffic core)
  NdolaPlace('Lubuto',                      -12.9990,    28.6180,    'Residential'),  // PIN (SW high-density)
  NdolaPlace('Bwafwano',                    -12.9230,    28.6140,    'Residential'),  // PIN (NW periphery)
  NdolaPlace('Mushili',                     -13.0120,    28.6650,    'Residential'),  // PIN (SE sprawl)
  NdolaPlace('Mushili Compound',            -13.0110,    28.6540,    'Residential'),  // PIN (rapidly expanding; custom unpaved route modifiers)
  NdolaPlace('Chizombe',                    -12.9430,    28.5980,    'Residential'),  // PIN (W peri-urban)

  // ── Shopping / Commercial ─────────────────────────────────────────────────
  NdolaPlace('Kafubu Mall',                 -12.9755,    28.6415,    'Shopping'),     // PIN (central retail hub over river loop)
  NdolaPlace('Rekha Shopping Mall',         -12.9690,    28.6460,    'Shopping'),     // PIN (downtown high-yield retail)
  NdolaPlace('Jacaranda Shopping Centre',   -12.9710,    28.6360,    'Shopping'),     // PIN (CBD-central; distinct from Jacaranda Mall south)

  // ── Education ─────────────────────────────────────────────────────────────
  NdolaPlace('CBU Ndola Medical Campus',    -12.9640,    28.6355,    'University'),   // PIN (student + medical professional commuter flows)
  NdolaPlace('NIPA Ndola Campus',           -12.9660,    28.6290,    'University'),   // PIN (tertiary; high evening executive-class bookings)
  NdolaPlace('Northrise University',        -12.9460,    28.6010,    'University'),   // PIN (western approach; high private booking density)
  NdolaPlace('Ndola Technical School',      -13.0040,    28.6650,    'University'),   // PIN (institutional; heavy morning drop-off)
  NdolaPlace('Simba International School',  -12.9425,    28.6295,    'University'),   // PIN (ultra-premium; severe AM/PM surge spikes)

  // ── Clinics ───────────────────────────────────────────────────────────────
  NdolaPlace('Chifubu Health Centre',       -12.9340,    28.6525,    'Hospital'),     // PIN (high-priority; heavy neighborhood patient transport)
  // Ndola Teaching Hospital may overlap with Ndola Central Hospital — verify
  NdolaPlace('Ndola Teaching Hospital',     -12.9675,    28.6375,    'Hospital'),     // PIN (emergency routing priority)

  // ── Fuel Stations ─────────────────────────────────────────────────────────
  NdolaPlace('TotalEnergies President Ave', -12.9680,    28.6445,    'Transport'),    // PIN (core CBD fleet node; high throughput)
  NdolaPlace('Puma Energy Kansenshi',       -12.9585,    28.6320,    'Transport'),    // PIN (premium suburban fleet hub)
  NdolaPlace('Mount Meru Bwana Mkubwa',     -13.0230,    28.6810,    'Transport'),    // PIN (S gate heavy logistics; Kapiri Mposhi long-haul)
  NdolaPlace('Kobil Itawa Station',         -12.9860,    28.6535,    'Transport'),    // PIN (aviation-adjacent fleet depot)
  NdolaPlace('Uno Energies Chifubu',        -12.9390,    28.6470,    'Transport'),    // PIN (northern high-density minibus fleet point)

  // ── Industrial ────────────────────────────────────────────────────────────
  NdolaPlace('Indeni Refinery / TAZAMA',    -13.0250,    28.6910,    'Transport'),    // PIN (energy infrastructure complex)
  NdolaPlace('Indeni Refinery Gate',        -13.0360,    28.6790,    'Transport'),    // PIN (corporate gate; enterprise SLA dispatch)
  NdolaPlace('Bwana Mkubwa Industrial',     -13.0180,    28.6780,    'Transport'),    // PIN (chemical/construction)
  NdolaPlace('Bwana Mkubwa M6 Track',       -13.0310,    28.6920,    'Junction'),     // PIN (heavy freight; multi-axle truck corridor)
  // Old / cargo axis airport inside town — distinct from new SMK airport 15km west
  NdolaPlace('SMK Old Airport / Cargo Axis',-12.9965,    28.6635,    'Transport'),    // PIN (specialized shipping + cargo transfers)

  // ── Road Vectors & Junctions ─────────────────────────────────────────────
  NdolaPlace('Dag Hammarskjöld Drive',      -12.9550,    28.6340,    'Junction'),     // PIN (northern distribution spine; suburb-to-business)
  NdolaPlace('President Avenue Corridor',   -12.9695,    28.6435,    'Junction'),     // PIN (busiest CBD artery; peak-hour congestion zone)
  NdolaPlace('Broadway Street Ring',        -12.9630,    28.6440,    'Junction'),     // PIN (mid-town bypass; avoids downtown grid)
  NdolaPlace('Kafubu River Bridge',         -12.9925,    28.6210,    'Junction'),     // PIN (critical choke point; S-density to mid-town)
  NdolaPlace('T3 Spine (Kitwe-Ndola)',      -12.9715,    28.5950,    'Junction'),     // PIN (main expressway backbone)
  // Western gate — T3 dual carriageway entry into Ndola from Kitwe
  NdolaPlace('T3 Gate (Ndola-Kitwe Road)',  -12.9620,    28.5680,    'Junction'),     // PIN
  NdolaPlace('Ndola-Luanshya Exit (M6)',    -13.0040,    28.5290,    'Junction'),     // PIN
  NdolaPlace('Ndola-Lusaka Road (T2/T3)',   -13.0450,    28.5820,    'Junction'),     // PIN
  NdolaPlace('Chichele Junction',           -13.0067419, 28.5712396, 'Junction'),     // OSM
  // Northeast — Sakania border route to DRC (alternative to Kasumbalesa)
  NdolaPlace('Sakania Border Route',        -12.9180,    28.6980,    'Junction'),     // PIN
];

List<NdolaPlace> searchNdolaPlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      ndolaPlaces.firstWhere((p) => p.name == 'Ndola CBD'),
      ndolaPlaces.firstWhere((p) => p.name == 'Ndola Bus Station'),
      ndolaPlaces.firstWhere((p) => p.name == 'Kafubu Mall'),
      ndolaPlaces.firstWhere((p) => p.name == 'Masala'),
      ndolaPlaces.firstWhere((p) => p.name == 'Kansenshi'),
      ndolaPlaces.firstWhere((p) => p.name == 'Chifubu'),
      ndolaPlaces.firstWhere((p) => p.name == 'Ndola Teaching Hospital'),
      ndolaPlaces.firstWhere((p) => p.name == 'Northrise University'),
    ];
  }
  final q = query.toLowerCase();
  return ndolaPlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

double ndolaHaversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
