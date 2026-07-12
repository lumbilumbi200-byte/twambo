import 'dart:math';

class LivingstonePlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const LivingstonePlace(this.name, this.lat, this.lng, [this.tag]);
}

// All coordinates are user-verified (PIN).
// Livingstone operates on a dual-world layout:
//   • North/East  — high-density residential + commercial grid
//   • South       — premium safari/lodge corridor toward Victoria Falls & Zimbabwe border
//
// WILDLIFE BUFFER ZONE:
//   Latitudes between -17.8685 and -17.9282 fall inside the elephant transit corridor
//   and national park territory. Flag drivers to reduce speed to 50 km/h between
//   18:00 and 06:00 when any active trip enters this latitude band.
const double livingstoneWildlifeBufferNorth = -17.8685;
const double livingstoneWildlifeBufferSouth = -17.9282;

const livingstonePlaces = <LivingstonePlace>[

  // ══════════════════════════════════════════════════════════════════════════
  // SECTOR 1 — Perimeter Fences & Border Nodes
  // ══════════════════════════════════════════════════════════════════════════

  // International crossings — triggers automated cross-border surcharge
  LivingstonePlace('Victoria Falls Border Post (ZM)',  -17.9230,  25.8565,  'Junction'),   // PIN (drop-off only; cross-border premium)
  LivingstonePlace('Victoria Falls Bridge',            -17.9282,  25.8570,  'Junction'),   // PIN (no-man's-land; southernmost trip limit)
  // Western splitter — routes toward Botswana / Namibia via M10
  LivingstonePlace('Kazungula Road Turn-off (M10)',    -17.8390,  25.8115,  'Junction'),   // PIN (inter-provincial western splitter)
  // Northern line-haul boundary — beyond this = Kalomo/Choma inter-city tariff
  LivingstonePlace('Zimba Corridor Gate (T1)',         -17.7210,  25.9320,  'Junction'),   // PIN (northern inter-district boundary)
  // SE rural fringe — unpaved road multiplier near lower gorges
  LivingstonePlace('Songwe Village Perimeter',         -17.9310,  25.9180,  'Junction'),   // PIN (SE rough-road boundary)
  // Western upper-Zambezi lodge corridor anchor
  LivingstonePlace('Simonga Village (M10 West)',       -17.8820,  25.6690,  'Junction'),   // PIN (airport-to-remote-lodge transit end)

  // ══════════════════════════════════════════════════════════════════════════
  // SECTOR 2 — Residential Neighborhoods & Suburbs
  // ══════════════════════════════════════════════════════════════════════════

  // ── Premium / Low-Density ─────────────────────────────────────────────────
  LivingstonePlace('Fairmount / Thermal Area',         -17.8485,  25.8530,  'Residential'), // PIN (premium; adjacent to golf course)
  LivingstonePlace('Airport Extension',                -17.8280,  25.8420,  'Residential'), // PIN (upscale emerging estate)
  LivingstonePlace('Linda Low-Density Strip',          -17.8375,  25.8640,  'Residential'), // PIN (colonial homes + modern townhouses)
  LivingstonePlace('Golf Course Residential',          -17.8540,  25.8475,  'Residential'), // PIN (ultra-premium; safari operators + expats)

  // ── High-Density Commuter Compounds ──────────────────────────────────────
  LivingstonePlace('Maramba Compound',                 -17.8395,  25.8820,  'Residential'), // PIN (highest-volume daily shuttle driver)
  LivingstonePlace('Libuyu Compound',                  -17.8560,  25.8870,  'Residential'), // PIN (SE across Maramba River)
  LivingstonePlace('Linda Compound',                   -17.8310,  25.8710,  'Residential'), // PIN (high-yield; tracks toward industrial zone)
  LivingstonePlace('Sawmills Compound',                -17.8210,  25.8520,  'Residential'), // PIN (historic railway-worker neighborhood)
  LivingstonePlace('Malota Compound',                  -17.8460,  25.8620,  'Residential'), // PIN (high-frequency short-trip zone near rail)
  LivingstonePlace('Dambwa Central',                   -17.8490,  25.8190,  'Residential'), // PIN (large stable suburb W of Mosi-oa-Tunya Rd)
  LivingstonePlace('Dambwa Site and Service',          -17.8555,  25.8080,  'Residential'), // PIN (dense grid; tight access roads)
  LivingstonePlace('Dambwa North',                     -17.8380,  25.8240,  'Residential'), // PIN (mid-tier; steady commuter flow)
  LivingstonePlace('Highlands Suburb',                 -17.8080,  25.8610,  'Residential'), // PIN (northern rim outlier)
  LivingstonePlace('Ngwenya Compound',                 -17.8140,  25.8390,  'Residential'), // PIN (informal; manual dispatch route verification)

  // ══════════════════════════════════════════════════════════════════════════
  // SECTOR 3 — Core Inner Arteries, Intersections & Transit Hubs
  // ══════════════════════════════════════════════════════════════════════════

  LivingstonePlace('Livingstone CBD',                  -17.8465,  25.8545,  'City Centre'), // PIN (Mosi-oa-Tunya Rd core dispatch origin)
  LivingstonePlace('Harry Mwaanga Nkumbula Airport',   -17.8212,  25.8508,  'Transport'),   // PIN (LVI; airport pick-up surcharge trigger)
  LivingstonePlace('Maramba River Bridge',             -17.8545,  25.8795,  'Junction'),    // PIN (critical bottleneck; residential east ↔ core)
  LivingstonePlace('Kazungula Road Roundabout',        -17.8265,  25.8535,  'Junction'),    // PIN (main highway gateway into town from N)
  LivingstonePlace('Akapelwa Street Axis',             -17.8450,  25.8560,  'Junction'),    // PIN (central commercial spine; high congestion)
  // Southern gateway splitter — town ends here; safari/park zone begins beyond
  LivingstonePlace('Mosi-oa-Tunya / Johnston Jct',    -17.8685,  25.8530,  'Junction'),    // PIN (wildlife buffer NORTH boundary marker)
  LivingstonePlace('Kapiri Mposhi Street Intersection',-17.8435,  25.8580,  'Junction'),   // PIN (logistics / transport yard distributor)
  LivingstonePlace('Livingstone Central Rail Station', -17.8480,  25.8575,  'Transport'),   // PIN (inter-city rail multi-modal hub)
  LivingstonePlace('Maramba Market Bus Terminal',      -17.8405,  25.8745,  'Transport'),   // PIN (ultra-high density minibus + shared-taxi staging)
  LivingstonePlace('Inter-City Bus Terminus',          -17.8440,  25.8510,  'Transport'),   // PIN (Lusaka / Copperbelt long-distance gateway)

  // ══════════════════════════════════════════════════════════════════════════
  // SECTOR 4 — Fueling Stations & Fleet Depots
  // ══════════════════════════════════════════════════════════════════════════

  LivingstonePlace('TotalEnergies Mosi-oa-Tunya S',   -17.8510,  25.8535,  'Transport'),   // PIN (last main fuel before falls corridor)
  LivingstonePlace('Puma Energy CBD Central',          -17.8445,  25.8540,  'Transport'),   // PIN (core town traffic refuel hub)
  LivingstonePlace('Mount Meru Kazungula Jct',         -17.8270,  25.8525,  'Transport'),   // PIN (northern inflow; Lusaka-bound logistics)
  LivingstonePlace('Kobil Linda Road',                 -17.8390,  25.8610,  'Transport'),   // PIN (eastern suburb fleet station)
  LivingstonePlace('Uno Energies Dambwa',              -17.8480,  25.8280,  'Transport'),   // PIN (western ring residential service)
  LivingstonePlace('Puma Energy Airport Road',         -17.8260,  25.8490,  'Transport'),   // PIN (aviation logistics; near car rentals)

  // ══════════════════════════════════════════════════════════════════════════
  // SECTOR 5 — Healthcare, Clinics & Emergency Destinations
  // ══════════════════════════════════════════════════════════════════════════

  LivingstonePlace('Livingstone Central Hospital',     -17.8415,  25.8605,  'Hospital'),    // PIN (main regional referral; bypass dispatch latency)
  LivingstonePlace('Maramba Clinic',                   -17.8410,  25.8790,  'Hospital'),    // PIN (dense eastern settlements primary health)
  LivingstonePlace('Libuyu Clinic',                    -17.8590,  25.8910,  'Hospital'),    // PIN (SE compound medical anchor)
  LivingstonePlace('Dambwa Health Centre',             -17.8510,  25.8150,  'Hospital'),    // PIN (high-volume western medical destination)
  LivingstonePlace('Linda Urban Health Centre',        -17.8330,  25.8690,  'Hospital'),    // PIN (local priority north-east health anchor)
  LivingstonePlace('Falls Medical Clinic (Private)',   -17.8495,  25.8515,  'Hospital'),    // PIN (premium tourist specialist; medical evacuations)

  // ══════════════════════════════════════════════════════════════════════════
  // SECTOR 6 — Academic Institutions, Trades & Universities
  // ══════════════════════════════════════════════════════════════════════════

  LivingstonePlace('LIBES Campus',                     -17.8290,  25.8660,  'University'),  // PIN (daily student commuter flows)
  LivingstonePlace('Victoria Falls University (VFU)',  -17.8090,  25.8570,  'University'),  // PIN (northern perimeter tertiary)
  LivingstonePlace('David Livingstone Secondary',      -17.8490,  25.8360,  'University'),  // PIN (historic institutional surge node)
  LivingstonePlace('St. Mary\'s Secondary School',     -17.8365,  25.8590,  'University'),  // PIN (high-yield school-run hub)
  LivingstonePlace('Maramba Basic School',             -17.8385,  25.8770,  'University'),  // PIN (high-density compound school)
  LivingstonePlace('Hillcrest Technical Secondary',    -17.8320,  25.8440,  'University'),  // PIN (elite boarding; severe term-change surge)
  LivingstonePlace('Linda Secondary School',           -17.8340,  25.8730,  'University'),  // PIN (high-volume suburban school node)

  // ══════════════════════════════════════════════════════════════════════════
  // SECTOR 7 — Tourism, Malls, Lodges & Wildlife Nodes
  // ══════════════════════════════════════════════════════════════════════════

  // ── Commercial / Banking ──────────────────────────────────────────────────
  LivingstonePlace('Mosi-oa-Tunya Square (Shoprite)',  -17.8455,  25.8535,  'Shopping'),    // PIN (premier retail + ATM hub)
  LivingstonePlace('Victoria Falls Shopping Complex',  -17.9220,  25.8550,  'Shopping'),    // PIN (high-yield; falls entrance plaza)
  LivingstonePlace('ZANACO Livingstone',               -17.8460,  25.8550,  'Shopping'),    // PIN (financial core; high cashout traffic)
  LivingstonePlace('Standard Chartered Civic Strip',   -17.8445,  25.8555,  'Shopping'),    // PIN (business district banking anchor)

  // ── Cultural & Historical Landmarks ───────────────────────────────────────
  LivingstonePlace('Livingstone Museum',               -17.8475,  25.8540,  'Landmark'),    // PIN (CBD cultural landmark; tourist transit node)
  LivingstonePlace('Maramba Cultural Village',         -17.8630,  25.8640,  'Landmark'),    // PIN (park-route specialty excursion)
  LivingstonePlace('Railway Museum',                   -17.8520,  25.8420,  'Landmark'),    // PIN (heritage tourism; niche high-yield)

  // ── Premium Safari Lodges (south of wildlife buffer — premium rates apply) ─
  LivingstonePlace('Royal Livingstone Resort',         -17.9175,  25.8450,  'Landmark'),    // PIN (ultra-premium; inside national park)
  LivingstonePlace('Radisson Blu Mosi-oa-Tunya',      -17.8960,  25.8315,  'Landmark'),    // PIN (premium riverside; high airport-shuttle demand)
  LivingstonePlace('Avani Victoria Falls Resort',      -17.9195,  25.8490,  'Landmark'),    // PIN (high-yield; walking distance to falls)
  LivingstonePlace('Victoria Falls Waterfront Lodge',  -17.8870,  25.8350,  'Landmark'),    // PIN (cruise + adventure-tour pickup hub)
  LivingstonePlace('Chrismar Hotel Livingstone',       -17.8720,  25.8560,  'Landmark'),    // PIN (premium conference/govt retreat venue)
  LivingstonePlace('Protea Hotel by Marriott',         -17.8645,  25.8540,  'Landmark'),    // PIN (corporate hotel on park boundary road)
  LivingstonePlace('David Livingstone Safari Lodge',   -17.8905,  25.8340,  'Landmark'),    // PIN (river-cruise launch site)
  // Extreme distal western lodges — fixed long-distance rate via M10 required
  LivingstonePlace('River Club Luxury Lodge',          -17.8910,  25.7420,  'Landmark'),    // PIN (extreme distal W; fixed-rate only)
  LivingstonePlace('Tongabezi Lodge',                  -17.8845,  25.7190,  'Landmark'),    // PIN (extreme distal W; remote wilderness pricing)

  // ── Wildlife, Adventure & Recreation ─────────────────────────────────────
  LivingstonePlace('Mosi-oa-Tunya National Park Gate', -17.8810,  25.8510,  'Junction'),   // PIN (wildlife warning activate point)
  LivingstonePlace('Livingstone Crocodile Park',       -17.8595,  25.8515,  'Landmark'),   // PIN (southern town edge; family tourism)
  // Distal east — custom eastern corridor tariff; unpaved terrain
  LivingstonePlace('Mukuni Village Cultural Site',     -17.9320,  25.9030,  'Landmark'),   // PIN (high-yield excursion; rough-road tariff)
  LivingstonePlace('Livingstone Golf & Country Club',  -17.8515,  25.8490,  'Landmark'),   // PIN (premium private client pickup)
  LivingstonePlace('Batoka Gorge Heliport',            -17.9215,  25.8670,  'Transport'),  // PIN (high-yield adventure; rapid tourist turnaround)
];

List<LivingstonePlace> searchLivingstonePlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      livingstonePlaces.firstWhere((p) => p.name == 'Livingstone CBD'),
      livingstonePlaces.firstWhere((p) => p.name == 'Harry Mwaanga Nkumbula Airport'),
      livingstonePlaces.firstWhere((p) => p.name == 'Maramba Market Bus Terminal'),
      livingstonePlaces.firstWhere((p) => p.name == 'Livingstone Central Hospital'),
      livingstonePlaces.firstWhere((p) => p.name == 'Mosi-oa-Tunya Square (Shoprite)'),
      livingstonePlaces.firstWhere((p) => p.name == 'Victoria Falls Border Post (ZM)'),
      livingstonePlaces.firstWhere((p) => p.name == 'Maramba Compound'),
      livingstonePlaces.firstWhere((p) => p.name == 'Royal Livingstone Resort'),
    ];
  }
  final q = query.toLowerCase();
  return livingstonePlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

// Returns true if the latitude is inside the elephant / national park warning buffer.
// Use this to flag driver speed-limit alerts between 18:00 and 06:00.
bool isInLivingstoneWildlifeBuffer(double lat) =>
    lat <= livingstoneWildlifeBufferNorth && lat >= livingstoneWildlifeBufferSouth;

double livingstoneHaversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
