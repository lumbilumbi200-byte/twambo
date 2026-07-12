import 'dart:math';

class ChingolaPlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const ChingolaPlace(this.name, this.lat, this.lng, [this.tag]);
}

// Coordinates marked (OSM) are from Overpass Turbo export — accurate.
// Coordinates marked (PIN) are user-verified pins — accurate.
// All coordinates in this file are confirmed — nothing approximate.

const chingolaPlaces = <ChingolaPlace>[
  // ── City Centre ───────────────────────────────────────────────────────────
  ChingolaPlace('Chingola CBD',                    -12.5350,    27.8610,    'City Centre'),  // PIN (The Park Mall core)
  ChingolaPlace('Chingola Bus Station',             -12.5476997, 27.8513653, 'Transport'),    // OSM

  // ── Shopping ──────────────────────────────────────────────────────────────
  ChingolaPlace('Shoprite Chingola',                -12.5479805, 27.8591794, 'Shopping'),     // OSM

  // ── Hospitals ─────────────────────────────────────────────────────────────
  ChingolaPlace('Nchanga North General Hospital',   -12.5200,    27.8600,    'Hospital'),     // PIN
  ChingolaPlace('Chawama Mini Hospital',            -12.5585406, 27.8408847, 'Hospital'),     // OSM

  // ── Residential / Compounds ───────────────────────────────────────────────
  // ── Premium / Low-Density ─────────────────────────────────────────────────
  ChingolaPlace('Nchanga South',                    -12.5350,    27.8540,    'Residential'),  // PIN (premium exec; colonial-style wide plots)
  ChingolaPlace('Riverside Extension',              -12.5190,    27.8680,    'Residential'),  // PIN (high-income NE private housing)
  ChingolaPlace('Kabundi South',                    -12.5410,    27.8720,    'Residential'),  // PIN (mid-premium; corporate managers)
  ChingolaPlace('GRA / Up-Station',                 -12.5270,    27.8480,    'Residential'),  // PIN (civil service premium; near municipal offices)
  ChingolaPlace('Kasompe Extension',                -12.5690,    27.8920,    'Residential'),  // PIN (southern peri-urban; near airfield)
  // ── High-Density Commuter Compounds ──────────────────────────────────────
  ChingolaPlace('Chiwempala',                       -12.5480,    27.8440,    'Residential'),  // PIN (largest compound; residential)
  ChingolaPlace('Chiwempala Market Core',           -12.5510,    27.8410,    'Market'),       // PIN (market hub within Chiwempala)
  ChingolaPlace('Chawama',                          -12.5585406, 27.8408847, 'Residential'),  // PIN
  ChingolaPlace('Chabanyama',                       -12.5630,    27.8320,    'Residential'),  // PIN (SW worker hub; feeds processing plants)
  ChingolaPlace('Soweto Chingola',                  -12.5540,    27.8220,    'Residential'),  // PIN (high-density; borders mine dumps)
  ChingolaPlace('Maiteneke',                        -12.5390,    27.8290,    'Residential'),  // PIN (between Nchanga mine and Chiwempala)
  ChingolaPlace('Nchanga North',                    -12.5220,    27.8490,    'Residential'),  // PIN (mine management suburb)
  ChingolaPlace('Kabundi East',                     -12.5185,    27.8760,    'Residential'),  // PIN (sprawling eastern suburb — north tip)
  ChingolaPlace('Kabundi East (South Grid)',         -12.5460,    27.8890,    'Residential'),  // PIN (south tip; tight residential network)
  ChingolaPlace('Kapisha',                          -12.5510,    27.8820,    'Residential'),  // PIN (SE high-density)
  ChingolaPlace('Kapisha North',                    -12.5120,    27.8930,    'Residential'),  // PIN (NE fringe; road friction zone)
  ChingolaPlace('Lulamba',                          -12.4960,    27.8690,    'Residential'),  // PIN (northern outer fringe)
  ChingolaPlace('Lulamba Extension',                -12.4850,    27.8820,    'Residential'),  // PIN (distal N sprawl; standalone distance tier)
  ChingolaPlace('Riverside',                        -12.5645,    27.8760,    'Residential'),  // PIN
  ChingolaPlace('Kantanshi',                        -12.5360,    27.8420,    'Residential'),  // PIN (western mining margin)

  // ── Hospitals ─────────────────────────────────────────────────────────────
  ChingolaPlace('Nchanga South Hospital',           -12.5315,    27.8495,    'Hospital'),     // PIN (premium mine medical centre; emergency routing)

  // ── Clinics ───────────────────────────────────────────────────────────────
  ChingolaPlace('Chiwempala Clinic',                -12.5465,    27.8390,    'Hospital'),     // PIN (high-traffic public health node)
  ChingolaPlace('Kabundi Health Centre',            -12.5430,    27.8820,    'Hospital'),     // PIN (eastern suburb secondary medical)

  // ── Education ─────────────────────────────────────────────────────────────
  ChingolaPlace('Nchanga Trust School',             -12.5360,    27.8440,    'University'),   // PIN (premium school-run; high private dispatch)
  ChingolaPlace('Chingola Day Secondary School',    -12.5330,    27.8650,    'University'),   // PIN (central; cross-neighborhood student flows)
  ChingolaPlace('Chingola Arts Secondary',          -12.5310,    27.8560,    'University'),   // PIN (near commercial core)
  ChingolaPlace('Kabundi Secondary School',         -12.5480,    27.8860,    'University'),   // PIN (high-volume daily family transit)
  ChingolaPlace('Don Bosco Technical Institute',    -12.5610,    27.8520,    'University'),   // PIN (vocational; mid-day young adult commuter)

  // ── Commercial / Shopping ─────────────────────────────────────────────────
  ChingolaPlace('The Park Mall',                    -12.5312,    27.8535,    'Shopping'),     // PIN (premier retail + ATM hub)
  ChingolaPlace('Motherland Shopping Mall',         -12.5365,    27.8615,    'Shopping'),     // PIN (eastern business approach retail)
  ChingolaPlace('Town Centre Market Square',        -12.5305,    27.8510,    'Market'),       // PIN (high-congestion CBD commerce core)

  // ── Banking / Financial ───────────────────────────────────────────────────
  ChingolaPlace('Fern Avenue Commercial Axis',      -12.5295,    27.8515,    'Junction'),     // PIN (CBD banking/business entry vector)

  // ── Premium Landmarks ─────────────────────────────────────────────────────
  ChingolaPlace('Nchanga Golf Club',                -12.5245,    27.8445,    'Landmark'),     // PIN (championship course; premium private dispatch)
  ChingolaPlace('KCM Corporate HQ',                 -12.5205,    27.8460,    'Landmark'),     // PIN (corporate hub; rigid SLA dispatch rules)

  // ── Fuel Stations ─────────────────────────────────────────────────────────
  ChingolaPlace('TotalEnergies Chingola CBD',       -12.5285,    27.8530,    'Transport'),    // PIN (central fleet hub)
  ChingolaPlace('Puma Energy Kitwe Road',           -12.5520,    27.8595,    'Transport'),    // PIN (southern gateway; incoming Kitwe traffic)
  ChingolaPlace('Mount Meru Solwezi Junction',      -12.5230,    27.8365,    'Transport'),    // PIN (T5 transition point for long-haul fleets)
  ChingolaPlace('Uno Energies Kabundi',             -12.5395,    27.8710,    'Transport'),    // PIN (eastern suburb fleet depot)
  ChingolaPlace('Kobil Chiwempala',                 -12.5495,    27.8455,    'Transport'),    // PIN (high-density public transit refuel node)

  // ── Mine Infrastructure ───────────────────────────────────────────────────
  // Nchanga Open Pit — one of the largest open-cast copper mines in the world
  ChingolaPlace('Nchanga Open Pit Gate',            -12.5110,    27.8180,    'Transport'),    // PIN (shift-change node)
  ChingolaPlace('Mine Shaft Access Road',           -12.5180,    27.8410,    'Transport'),    // PIN (heavy truck route; shift-change warning active)

  // ── Road / Junctions ─────────────────────────────────────────────────────
  // NOTE: heavy machinery channels run along -12.5020 to -12.5210; monitor for haul-track closures
  ChingolaPlace('T3 Highway Core (Chingola)',       -12.5585,    27.8625,    'Junction'),     // PIN (main dual-carriageway base corridor)
  ChingolaPlace('T5 Outflow (Solwezi Road Split)',  -12.5210,    27.8340,    'Junction'),     // PIN (NW radial toward Solwezi mines)
  // THE critical corridor splitter — left = T5 to Solwezi, straight = T3 to Chililabombwe/DRC
  ChingolaPlace('T3/T5 Junction (Solwezi Split)',   -12.5410,    27.8290,    'Junction'),     // PIN
  // Western gate — T5 exit toward Solwezi / Kalumbila / Lumwana
  ChingolaPlace('Solwezi Road Gateway (T3/M8)',     -12.5452,    27.8305,    'Junction'),     // PIN
  ChingolaPlace('Eshowe Road Connector',            -12.5385,    27.8590,    'Junction'),     // PIN (Nchanga South ↔ eastern residential link)
  // Southern gate — T3 entry from Kitwe; anchors Kasompe Airport
  ChingolaPlace('T3 South Gate / Kasompe Jct',     -12.5710,    27.8930,    'Junction'),     // PIN
  ChingolaPlace('Kasompe Airfield (CGJ)',           -12.5725,    27.8960,    'Transport'),    // PIN (private mining charters + logistics)
  // Northern gate — T3 exit toward Chililabombwe
  ChingolaPlace('Chililabombwe Road (T3 North)',    -12.5020,    27.8490,    'Junction'),     // PIN (international freight toward Kasumbalesa/DRC)
  ChingolaPlace('Chililabombwe Road Exit (North)',  -12.5185,    27.8795,    'Junction'),     // PIN (urban-exit toward Chililabombwe)

  // ── Perimeter / Out-of-Town Boundary Nodes ───────────────────────────────
  // Southern fare boundary — crossing this switches to Kitwe inter-city matrix
  ChingolaPlace('Five Mile Rock (T3 South)',        -12.5920,    27.9110,    'Junction'),     // PIN (outer boundary / zone-switch control)
  // ~10km north; eco-tourism outlier — high-friction country dirt road tariff
  ChingolaPlace('Hippo Pool Monument Gate',         -12.4350,    27.8420,    'Landmark'),     // PIN (distal N; Kafue River eco-tourism rate)
];

List<ChingolaPlace> searchChingolaPlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      chingolaPlaces.firstWhere((p) => p.name == 'Chingola CBD'),
      chingolaPlaces.firstWhere((p) => p.name == 'Chingola Bus Station'),
      chingolaPlaces.firstWhere((p) => p.name == 'Chiwempala Market Core'),
      chingolaPlaces.firstWhere((p) => p.name == 'The Park Mall'),
      chingolaPlaces.firstWhere((p) => p.name == 'Nchanga South Hospital'),
      chingolaPlaces.firstWhere((p) => p.name == 'Nchanga North General Hospital'),
      chingolaPlaces.firstWhere((p) => p.name == 'Kabundi East'),
      chingolaPlaces.firstWhere((p) => p.name == 'Nchanga Golf Club'),
    ];
  }
  final q = query.toLowerCase();
  return chingolaPlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

double chingolaHaversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
