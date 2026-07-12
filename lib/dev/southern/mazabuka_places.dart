import 'dart:math';

class MazabukaPlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const MazabukaPlace(this.name, this.lat, this.lng, [this.tag]);
}

// All coordinates are user-verified (PIN) unless marked (~).
// Mazabuka is dominated by Nakambala Sugar Estate (Zambia Sugar Plc).
// T1 highway splits the corporate agro-industrial zone (north/east)
// from the organic high-density townships (south/west).

const mazabukaPlaces = <MazabukaPlace>[
  // ── City Centre ───────────────────────────────────────────────────────────
  MazabukaPlace('Mazabuka CBD',               -15.8560,  27.7485,  'City Centre'),  // PIN
  MazabukaPlace('Mazabuka Bus Station',        -15.8560,  27.7485,  'Transport'),    // PIN (co-located at CBD market)

  // ── Hospitals ─────────────────────────────────────────────────────────────
  MazabukaPlace('Mazabuka General Hospital',   -15.8545,  27.7390,  'Hospital'),     // PIN
  MazabukaPlace('Nakambala Health Centre',     -15.8295,  27.7780,  'Hospital'),     // PIN (estate-internal; triggers estate route multiplier)

  // ── Education ─────────────────────────────────────────────────────────────
  MazabukaPlace('Mazabuka Secondary School',   -15.8590,  27.7265,  'University'),   // PIN (largest day school; AM/PM spike node)
  MazabukaPlace('Nakambala School Complex',    -15.8440,  27.7690,  'University'),   // PIN (estate-run; shift-locked to factory schedule)
  MazabukaPlace('Mazabuka Skills Centre',      -15.8640,  27.7410,  'University'),   // PIN (vocational campus, south of CBD core)

  // ── Industrial / Zambia Sugar ─────────────────────────────────────────────
  MazabukaPlace('Zambia Sugar Factory Gate',   -15.8315,  27.7804,  'Transport'),    // PIN (staff perimeter gate; shift-change anchor)
  MazabukaPlace('Nakambala Sugar Mill Entry',  -15.8335,  27.7815,  'Transport'),    // PIN (factory floor / boiler stack — distinct from gate)
  MazabukaPlace('Nakambala Club',              -15.8385,  27.7660,  'Landmark'),     // PIN (exec social venue; premium evening drop-off)
  MazabukaPlace('Nakambala Suburb',            -15.8420,  27.7710,  'Residential'),  // PIN (corporate staff housing)
  MazabukaPlace('Nakambala Compound',          -15.8490,  27.7650,  'Residential'),  // PIN (field labor workforce base)

  // ── Residential / Townships ───────────────────────────────────────────────
  MazabukaPlace('Kaonga',                      -15.8620,  27.7340,  'Residential'),  // PIN (largest high-density township)
  MazabukaPlace('Kabobola',                    -15.8610,  27.7530,  'Residential'),  // PIN (southern sector)
  MazabukaPlace('Ndeke',                       -15.8710,  27.7420,  'Residential'),  // PIN (southern expansion zone)

  // ── Residential Expansions ────────────────────────────────────────────────
  MazabukaPlace('Hillside',                    -15.8645,  27.7610,  'Residential'),  // PIN (SE professional housing)
  MazabukaPlace('Fairview',                    -15.8450,  27.7320,  'Residential'),  // PIN (western commuter suburb)
  MazabukaPlace('Changa Changa',               -15.8770,  27.7280,  'Residential'),  // PIN (SW peri-urban fringe, high-density)

  // ── Markets ───────────────────────────────────────────────────────────────
  MazabukaPlace('Nakambala Market',            -15.8470,  27.7625,  'Market'),       // PIN (agri-produce hub for estate worker communities)

  // ── Institutional / Civic ─────────────────────────────────────────────────
  // Note: table longitude 27.4400 is a typo — narrative pin 27.7440 used (correct relative to CBD)
  MazabukaPlace('Mazabuka Police Camp',        -15.8580,  27.7440,  'Residential'),  // PIN (civic/security anchor NW of market)
  MazabukaPlace('District Council Offices',    -15.8565,  27.7450,  'Landmark'),     // PIN (administrative anchor, distinct from police camp)
  MazabukaPlace('ZESCO Operations Yard',       -15.8505,  27.7375,  'Transport'),    // PIN (utility base; continuous contractor vehicle movement)
  MazabukaPlace('Mazabuka Golf Club',          -15.8475,  27.7555,  'Landmark'),     // PIN (premium corporate drop zone)

  // ── Out-of-Town Agricultural Nodes ───────────────────────────────────────
  // ~12–14 km SW of CBD; outgrower scheme — heavy cargo + farming management transport
  MazabukaPlace('Kaleya Smallholders Area',    -15.9320,  27.6850,  'Junction'),     // PIN
  // ~18 km SW on T1; crossing this node triggers Long-Range Inter-District Shared Pool fare
  MazabukaPlace('Magoye Bus Stage',            -16.0020,  27.6185,  'Junction'),     // PIN (southern tariff splitter)

  // ── Road / Junctions ─────────────────────────────────────────────────────
  // Lubombo Rd junction — vehicles either enter the Zambia Sugar industrial loop or stay on T1
  MazabukaPlace('Lubombo Road Junction',       -15.8510,  27.7590,  'Junction'),     // PIN
  // Northern T1 boundary — edge of Nakambala Estate; pricing trigger toward Kafue/Lusaka
  MazabukaPlace('T1 North Exit (Nakambala Boundary)', -15.8210, 27.7950, 'Junction'), // PIN
  // Southern T1 entry point from Monze — urban speed zone trigger
  MazabukaPlace('T1 South Gate (from Monze)', -15.8890,  27.7120,  'Junction'),     // PIN
  // Province boundary: any GPS ping north of this bridge exits Mazabuka local rate scale entirely
  MazabukaPlace('Kafue River Bridge (T1)',     -15.7728,  28.1755,  'Junction'),     // PIN (inter-city corridor tariff trigger)
];

List<MazabukaPlace> searchMazabukaPlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      mazabukaPlaces.firstWhere((p) => p.name == 'Mazabuka CBD'),
      mazabukaPlaces.firstWhere((p) => p.name == 'Mazabuka Bus Station'),
      mazabukaPlaces.firstWhere((p) => p.name == 'Kaonga'),
      mazabukaPlaces.firstWhere((p) => p.name == 'Zambia Sugar Factory Gate'),
      mazabukaPlaces.firstWhere((p) => p.name == 'Mazabuka General Hospital'),
      mazabukaPlaces.firstWhere((p) => p.name == 'Nakambala Compound'),
      mazabukaPlaces.firstWhere((p) => p.name == 'Nakambala Market'),
      mazabukaPlaces.firstWhere((p) => p.name == 'Changa Changa'),
    ];
  }
  final q = query.toLowerCase();
  return mazabukaPlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

double mazabukaHaversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
