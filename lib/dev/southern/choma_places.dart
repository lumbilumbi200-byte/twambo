import 'dart:math';

class ChomaPlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const ChomaPlace(this.name, this.lat, this.lng, [this.tag]);
}

// Coordinates marked (PIN) are user-verified — accurate.
// Coordinates marked (~) are approximate — verify on Google Maps.
// Choma is the Southern Province capital. Urban core clusters tightly
// around the T1 / railway crossing at ~-16.812, 26.980.
// Three perimeter nodes (Batoka, Tara, Macha) define the inter-district
// tariff boundaries in all three exit directions.

const chomaPlaces = <ChomaPlace>[
  // ── City Centre ───────────────────────────────────────────────────────────
  ChomaPlace('Choma CBD',                       -16.8120,  26.9810,  'City Centre'),  // ~
  ChomaPlace('Choma Bus Station',               -16.8145,  26.9790,  'Transport'),    // ~ (near railway yard)

  // ── Hospitals ─────────────────────────────────────────────────────────────
  ChomaPlace('Choma General Hospital',          -16.8130,  26.9860,  'Hospital'),     // PIN

  // ── Education ─────────────────────────────────────────────────────────────
  // All three are boarding-school anchors — heavy mid-term / term-open/close surge
  ChomaPlace('Choma Secondary School',          -16.8220,  26.9690,  'University'),   // PIN
  ChomaPlace('Njase Girls Secondary School',    -16.7930,  26.9985,  'University'),   // PIN (NE rim boarding school)
  ChomaPlace('St. Mulumba\'s Special School',   -16.8180,  26.9890,  'University'),   // PIN (specialized institution)

  // ── Provincial Government & Civic ─────────────────────────────────────────
  // Post-designation HQ — daily gravity well for civil servants, contractors, corporate visits
  ChomaPlace('Provincial Admin Complex',        -16.8040,  26.9950,  'Landmark'),     // PIN (premium AM/PM office corridor)
  ChomaPlace('Choma Town Council & Civic Centre', -16.8105, 26.9825, 'Landmark'),    // PIN (historic downtown governance)
  ChomaPlace('Choma Museum & Crafts Centre',    -16.8090,  26.9840,  'Landmark'),     // PIN (T1-facing; premium tourist drop-off)

  // ── Markets & Commercial ──────────────────────────────────────────────────
  ChomaPlace('Makalanguzu Market',              -16.8120,  26.9805,  'Market'),       // PIN (CBD trade epicentre alongside T1/railway)

  // ── Transport / Logistics ─────────────────────────────────────────────────
  ChomaPlace('Zambia Railways Choma Yard',      -16.8145,  26.9790,  'Transport'),    // PIN (industrial grain silos + cargo)

  // ── Road / T1 Junctions ───────────────────────────────────────────────────
  // Urban entry/exit triggers (approximate — verify)
  ChomaPlace('Choma North Gate (T1)',           -16.7960,  26.9940,  'Junction'),     // ~ (toward Monze / Mazabuka)
  ChomaPlace('Choma South Gate (T1)',           -16.8410,  26.9530,  'Junction'),     // ~ (toward Kalomo / Livingstone)

  // ── Perimeter Fare Boundary Nodes ────────────────────────────────────────
  // ~22km NE on T1; also the SE gateway to Maamba Coal Mine / Sinazongwe corridor
  // Crossing north/east triggers Batoka-Maamba Transit Corridor Surcharge
  ChomaPlace('Batoka Interchange (T1)',         -16.7845,  27.1980,  'Junction'),     // PIN (northern inter-district boundary)
  // ~20km SW on T1; beyond this point = Livingstone Corridor Inter-City Tariff
  ChomaPlace('Tara Siding (T1 SW Limit)',       -16.8920,  26.8340,  'Junction'),     // PIN (southern inter-city boundary)
  // Western turn-off toward Macha Mission Hospital; triggers Western Rural Asset Surcharge
  ChomaPlace('Macha Junction (Western Rural)',  -16.8195,  26.8910,  'Junction'),     // PIN (rough-road surcharge trigger)

  // ── Residential Areas ─────────────────────────────────────────────────────
  ChomaPlace('New Extension',                   -16.8010,  27.0015,  'Residential'),  // PIN (premium; senior govt officials near Provincial Complex)
  ChomaPlace('Shampande Compound',              -16.8215,  26.9850,  'Residential'),  // PIN (high-density; high-frequency short trips)
  ChomaPlace('Kamunza Compound',                -16.8280,  26.9740,  'Residential'),  // PIN (high-density SW; morning market traffic)
  ChomaPlace('Whitewood Suburb',                -16.7975,  26.9790,  'Residential'),  // PIN (medium-density; north of T1, management housing)
  ChomaPlace('Railway Quarters',                -16.8160,  26.9710,  'Residential'),  // PIN (historic technical housing, industrial rail-side)
  ChomaPlace('Macha Road Suburb',               -16.8110,  26.9450,  'Residential'),  // PIN (peri-urban western edge; new estates + lodges)

  // ── Inner Road Vectors (routing geometry anchors) ─────────────────────────
  ChomaPlace('T1 Highway Core (Choma)',         -16.8100,  26.9810,  'Junction'),     // PIN (base-line dispatch origin corridor)
  ChomaPlace('Macha Road Trunk (M11)',          -16.8150,  26.9550,  'Junction'),     // PIN (NW radial outflow to rural research centers)
  ChomaPlace('Sinazongwe Road Junction',        -16.8190,  26.9920,  'Junction'),     // PIN (SE radial; Maamba coal mine logistics feed)
  ChomaPlace('Riverside Drive',                 -16.8045,  26.9875,  'Junction'),     // PIN (N-suburb to town-centre bypass link)
  ChomaPlace('Industrial Road Loop',            -16.8155,  26.9765,  'Junction'),     // PIN (heavy-vehicle freight lane to grain elevators)

  // ── Fuel Stations (fleet handover / zone boundary proxies) ───────────────
  ChomaPlace('TotalEnergies Choma',             -16.8115,  26.9815,  'Transport'),    // PIN (CBD-central, opposite Makalanguzu Market)
  ChomaPlace('Puma Energy Choma',               -16.8105,  26.9845,  'Transport'),    // PIN (T1 highway; inter-city long-run catch)
  ChomaPlace('Mount Meru Filling Station',      -16.8070,  26.9910,  'Transport'),    // PIN (eastern inflow; bulk logistics from Lusaka)
  ChomaPlace('Uno Energies Choma',              -16.8222,  26.9566,  'Transport'),    // PIN (western perimeter; T1 toward Livingstone boundary)
  ChomaPlace('Kobil Choma',                     -16.8135,  26.9770,  'Transport'),    // PIN (industrial zone; local delivery + agri machinery)

  // ── Clinics & Secondary Medical ───────────────────────────────────────────
  ChomaPlace('Shampande Health Centre',         -16.8245,  26.9910,  'Hospital'),     // PIN (eastern high-density outpatient hub)
  ChomaPlace('Kamunza Clinic',                  -16.8310,  26.9715,  'Hospital'),     // PIN (SW informal settlements)
  ChomaPlace('Railway Clinic',                  -16.8175,  26.9735,  'Hospital'),     // PIN (rail-yard neighborhood ward unit)
  ChomaPlace('New Extension Medical Outpost',   -16.7990,  26.9970,  'Hospital'),     // PIN (premium suburban private health anchor)

  // ── Schools & Training ────────────────────────────────────────────────────
  ChomaPlace('Choma Day Secondary School',      -16.8150,  26.9650,  'University'),   // PIN (high daily student transit volume)
  ChomaPlace('Choma Trades Training Centre',    -16.7985,  26.9895,  'University'),   // PIN (adult technical students; N periphery)
  ChomaPlace('Adonai Comprehensive School',     -16.8030,  26.9780,  'University'),   // PIN (private; high ride-hailing pick-up density)
  ChomaPlace('Swan Comprehensive School',       -16.8080,  26.9930,  'University'),   // PIN (daily family school-run node)
  // ~22km NW into Macha corridor — long-distance fixed rate required during student transit windows
  ChomaPlace('Macha Girls Secondary School',    -16.6580,  26.7840,  'University'),   // PIN (out-of-district; long-distance flat rate)

  // ── Commercial, Banking & Entertainment ──────────────────────────────────
  ChomaPlace('Choma Spar Plaza',                -16.8110,  26.9820,  'Shopping'),     // PIN (main modern retail plaza + premium ATMs)
  ChomaPlace('ZANACO Bank Choma',               -16.8122,  26.9812,  'Shopping'),     // PIN (CBD core banking; high cashout frequency)
  ChomaPlace('Absa / Indo-Zambia Strip',        -16.8118,  26.9830,  'Shopping'),     // PIN (business banking corridor)
  ChomaPlace('Choma Showgrounds (Eagles FC)',   -16.8060,  26.9880,  'Landmark'),     // PIN (match day + agri-show surge node)

  // ── Out-of-Town Tourism Node ──────────────────────────────────────────────
  // NE off T1; standard urban tracking ends here — premium eco-lodge rate applies beyond
  ChomaPlace('Nkanga Conservation Area Gate',   -16.7610,  27.0420,  'Landmark'),     // PIN (tourism outlier; out-of-bounds rate trigger)
];

List<ChomaPlace> searchChomaPlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      chomaPlaces.firstWhere((p) => p.name == 'Choma CBD'),
      chomaPlaces.firstWhere((p) => p.name == 'Choma Bus Station'),
      chomaPlaces.firstWhere((p) => p.name == 'Makalanguzu Market'),
      chomaPlaces.firstWhere((p) => p.name == 'Choma General Hospital'),
      chomaPlaces.firstWhere((p) => p.name == 'Provincial Admin Complex'),
      chomaPlaces.firstWhere((p) => p.name == 'Choma Secondary School'),
      chomaPlaces.firstWhere((p) => p.name == 'Njase Girls Secondary School'),
      chomaPlaces.firstWhere((p) => p.name == 'Zambia Railways Choma Yard'),
    ];
  }
  final q = query.toLowerCase();
  return chomaPlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

double chomaHaversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
