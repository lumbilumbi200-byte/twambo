import 'dart:math';

class MonzePlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const MonzePlace(this.name, this.lat, this.lng, [this.tag]);
}

// All coordinates are user-verified (PIN) unless marked (~).
// Monze is an agricultural T1 highway transit town between Mazabuka and Choma.
// Eastern flank: agricultural estates + ZCA campus.
// Northern fringe: truck park + freight logistics.

const monzePlaces = <MonzePlace>[
  // ── City Centre ───────────────────────────────────────────────────────────
  MonzePlace('Monze CBD',                    -16.2804,  27.4824,  'City Centre'),  // PIN
  MonzePlace('Monze Bus Terminal',            -16.2804,  27.4824,  'Transport'),    // PIN (co-located with CBD market)

  // ── Hospitals ─────────────────────────────────────────────────────────────
  // Covers both 1st and 2nd-level regional care — highest-density medical destination in 60km radius
  MonzePlace('Monze Mission Hospital',        -16.2752,  27.4745,  'Hospital'),     // PIN (updated, corrected from -16.2760)

  // ── Education ─────────────────────────────────────────────────────────────
  MonzePlace('Monze Secondary School',        -16.2825,  27.4580,  'University'),   // PIN (principal civic school, west side; AM/PM spike)
  MonzePlace('St. Mary\'s Secondary School',  -16.2780,  27.4815,  'University'),   // PIN (eastern commuter school)
  MonzePlace('Monze College of Education',    -16.2510,  27.4950,  'University'),   // PIN (tertiary; north of CBD core)
  MonzePlace('Rusangu University',            -16.3794,  27.5239,  'University'),   // PIN (~16km south — long-distance fare)
  MonzePlace('ZCA Monze Main Campus',         -16.2840,  27.5280,  'University'),   // PIN (5km east of CBD)
  MonzePlace('ZCA Compound',                  -16.2880,  27.5210,  'Residential'),  // PIN (staff/labor housing near campus)
  MonzePlace('Monze Boarding Secondary School',-16.2925, 27.4610,  'University'),   // PIN (SW edge)
  MonzePlace('Lwengu School',                 -16.2890,  27.4690,  'University'),   // PIN (premium private school)

  // ── Residential ───────────────────────────────────────────────────────────
  MonzePlace('Manungu Township',              -16.2910,  27.4810,  'Residential'),  // PIN (high-density south)
  MonzePlace('Boma / Site and Service',       -16.2750,  27.4860,  'Residential'),  // PIN (civic/government zone)
  MonzePlace('Fairview',                      -16.2650,  27.4910,  'Residential'),  // PIN (NE medium-density)
  MonzePlace('Fairview Extension',            -16.2610,  27.4990,  'Residential'),  // PIN (outer NE sprawl)
  MonzePlace('Hilltop',                       -16.2710,  27.4930,  'Residential'),  // PIN (eastern elevated suburb)

  // ── Markets ───────────────────────────────────────────────────────────────
  MonzePlace('Monze Main Market',             -16.2730,  27.4765,  'Market'),       // PIN (ultra-high density; off railway/T1 corridor)
  MonzePlace('Manungu Market Hub',            -16.2870,  27.4640,  'Market'),       // PIN (secondary compound market, micro-commerce hub)

  // ── Agri-Logistics ────────────────────────────────────────────────────────
  // Monze is the 'home of cattle' — this northern rail-siding handles heavy agricultural distribution
  MonzePlace('Cattle Staging Yards',          -16.2645,  27.4845,  'Transport'),    // PIN (northern rail node; truck contractor anchor)

  // ── Institutional / Administrative ────────────────────────────────────────
  MonzePlace('Monze Town Council Offices',    -16.2705,  27.4795,  'Landmark'),     // PIN (central district governance)
  MonzePlace('ZESCO Monze Service Centre',    -16.2715,  27.4770,  'Transport'),    // PIN (utility fleet operations base)
  MonzePlace('Monze Police Camp',             -16.2735,  27.4765,  'Residential'),  // PIN (NW of CBD)
  MonzePlace('ZRA Camp',                      -16.2705,  27.4780,  'Residential'),  // PIN (near police camp)

  // ── Freight / Logistics ───────────────────────────────────────────────────
  MonzePlace('Monze Truck Park',              -16.2605,  27.4740,  'Transport'),    // PIN (T1 north, near grain silos)
  MonzePlace('Truck Park Logistics Fringe',   -16.2570,  27.4720,  'Transport'),    // PIN (auto-repair + transit depots)

  // ── Eastern Agricultural Belt ─────────────────────────────────────────────
  MonzePlace('Manson Farms',                  -16.2730,  27.5450,  'Residential'),  // PIN (~7km east of CBD)
  MonzePlace('Monze East / ComDev',           -16.2790,  27.5080,  'Junction'),     // PIN (urban-to-rural pricing boundary)

  // ── Road / T1 Junctions ───────────────────────────────────────────────────
  MonzePlace('Monze North Gate (T1)',         -16.2625,  27.4760,  'Junction'),     // PIN (entry from Mazabuka)
  MonzePlace('The Moorings',                  -16.2140,  27.4580,  'Junction'),     // PIN (~10km north, agri waypoint / T1 marker)
  MonzePlace('Monze South Gate (T1)',         -16.3100,  27.4850,  'Junction'),     // ~ (leaving urban zone toward Choma)

  // ── Perimeter Fare Boundary Nodes ────────────────────────────────────────
  // ~10km NW — access node for Lochinvar National Park; triggers rough-road surcharge
  MonzePlace('Lochinvar Gate (Moorings Traj.)', -16.1940, 27.5435, 'Junction'),    // PIN (western wilderness / Namwala route splitter)
  // ~10–12km south — Gonde ancestral site; seasonal Lwiindi ceremony surge node
  MonzePlace('Gonde Heritage Site',           -16.3450,  27.4690,  'Junction'),    // PIN (customary land / peri-urban multiplier trigger)
  // ~18km south — southern backend trip filter; crossing here exits Monze tariff entirely
  MonzePlace('Chisekesi (T1 Southern Limit)', -16.4255,  27.4120,  'Junction'),    // PIN (Choma-corridor inter-city tariff boundary)
];

List<MonzePlace> searchMonzePlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      monzePlaces.firstWhere((p) => p.name == 'Monze CBD'),
      monzePlaces.firstWhere((p) => p.name == 'Monze Bus Terminal'),
      monzePlaces.firstWhere((p) => p.name == 'Monze Mission Hospital'),
      monzePlaces.firstWhere((p) => p.name == 'Monze Main Market'),
      monzePlaces.firstWhere((p) => p.name == 'Manungu Township'),
      monzePlaces.firstWhere((p) => p.name == 'Monze Secondary School'),
      monzePlaces.firstWhere((p) => p.name == 'Rusangu University'),
      monzePlaces.firstWhere((p) => p.name == 'Cattle Staging Yards'),
    ];
  }
  final q = query.toLowerCase();
  return monzePlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

double monzeHaversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
