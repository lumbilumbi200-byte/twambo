import 'dart:math';

class KitwePlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  const KitwePlace(this.name, this.lat, this.lng, [this.tag]);
}

const kitwePlaces = <KitwePlace>[
  // ── City Centre ───────────────────────────────────────────────────────────
  KitwePlace('Kitwe CBD',                    -12.8024, 28.2132, 'City Centre'),
  KitwePlace('Freedom Park',                 -12.7965, 28.2085, 'Park'),
  KitwePlace('Kitwe City Council',           -12.8025, 28.2130, 'Government'),
  KitwePlace('Kitwe Post Office',            -12.8022, 28.2138, 'Services'),
  KitwePlace('Kitwe Bus Station',            -12.8048, 28.2168, 'Transport'),
  KitwePlace('Racecourse Showgrounds',       -12.7902, 28.2102, 'Landmark'),

  // ── CBD Streets ───────────────────────────────────────────────────────────
  KitwePlace('Freedom Way',                  -12.8018, 28.2128, 'Street'),
  KitwePlace('Obote Avenue',                 -12.8015, 28.2145, 'Street'),
  KitwePlace('President Avenue',             -12.8010, 28.2110, 'Street'),
  KitwePlace('Oxford Road',                  -12.7958, 28.2080, 'Street'),
  KitwePlace('Zambia Road',                  -12.8048, 28.2155, 'Street'),
  KitwePlace('Nkana Road',                   -12.8040, 28.1980, 'Street'),

  // ── Markets ───────────────────────────────────────────────────────────────
  KitwePlace('Chisokone Market',             -12.8050, 28.2200, 'Market'),
  KitwePlace('Twapiya Market',               -12.8148, 28.2318, 'Market'),
  KitwePlace('Twatasha Market',              -12.8398, 28.1648, 'Market'),
  KitwePlace('Mufuchani Market',             -12.7958, 28.2458, 'Market'),
  KitwePlace('Kawama Market',                -12.8558, 28.1858, 'Market'),
  KitwePlace('Chamboli Market',              -12.8338, 28.2108, 'Market'),
  KitwePlace('Wusakile Market',              -12.8188, 28.2458, 'Market'),

  // ── Shopping ─────────────────────────────────────────────────────────────
  KitwePlace('Mukuba Mall',                  -12.7978, 28.2088, 'Shopping'),
  KitwePlace('Shoprite Kitwe',               -12.8028, 28.2148, 'Shopping'),
  KitwePlace('Kafubu Mall',                  -12.8448, 28.1782, 'Shopping'),
  KitwePlace('Cosmopolitan Mall',            -12.8012, 28.2128, 'Shopping'),
  KitwePlace('Mica Cash & Carry',            -12.8030, 28.2140, 'Shopping'),

  // ── Hospitals ────────────────────────────────────────────────────────────
  KitwePlace('Kitwe Teaching Hospital',      -12.8098, 28.2178, 'Hospital'),
  KitwePlace('Arthur Davison Hospital',      -12.7908, 28.1942, 'Hospital'),
  KitwePlace('Wusakile Mine Hospital',       -12.8200, 28.2468, 'Hospital'),
  KitwePlace('St Anthony\'s Hospital',       -12.8198, 28.2048, 'Hospital'),
  KitwePlace('Kitwe Central Hospital',       -12.8035, 28.2120, 'Hospital'),
  KitwePlace('Ndeke Clinic',                 -12.7855, 28.2348, 'Clinic'),
  KitwePlace('Buchi Clinic',                 -12.8060, 28.2410, 'Clinic'),
  KitwePlace('Chimwemwe Clinic',             -12.8248, 28.1960, 'Clinic'),
  KitwePlace('Twatasha Clinic',              -12.8408, 28.1638, 'Clinic'),
  KitwePlace('Kawama Clinic',                -12.8548, 28.1840, 'Clinic'),

  // ── Education ────────────────────────────────────────────────────────────
  KitwePlace('Copperbelt University',        -12.7868, 28.2288, 'University'),
  KitwePlace('CBU Main Gate',                -12.7855, 28.2275, 'University'),
  KitwePlace('CBU Sports Complex',           -12.7878, 28.2300, 'University'),
  KitwePlace('Kitwe College of Education',   -12.8088, 28.2048, 'College'),
  KitwePlace('Chiwala Secondary School',     -12.7820, 28.2322, 'School'),
  KitwePlace('Wusakile Mine School',         -12.8205, 28.2478, 'School'),
  KitwePlace('Kamfinsa Secondary',           -12.8640, 28.2710, 'School'),
  KitwePlace('Ipusukilo Secondary',          -12.7688, 28.2278, 'School'),

  // ── Hotels / Entertainment ────────────────────────────────────────────────
  KitwePlace('Leo\'s Pub & Grill',           -12.7972, 28.2042, 'Entertainment'),
  KitwePlace('Nkana Stadium',                -12.8078, 28.2198, 'Sports'),
  KitwePlace('Pyramid Hotel',                -12.8018, 28.2138, 'Hotel'),
  KitwePlace('Edinburgh Hotel',              -12.7985, 28.2108, 'Hotel'),
  KitwePlace('Savoy Hotel',                  -12.8010, 28.2120, 'Hotel'),
  KitwePlace('Mukuba Hotel',                 -12.8018, 28.2148, 'Hotel'),

  // ── Industrial / Mining ───────────────────────────────────────────────────
  KitwePlace('Industrial Area',              -12.8100, 28.1930, 'Industrial'),
  KitwePlace('Nkana Smelter',                -12.8120, 28.1870, 'Industrial'),
  KitwePlace('ZCCM Kitwe HQ',               -12.8115, 28.1885, 'Industrial'),
  KitwePlace('Nkana Mine Shaft 3',           -12.8090, 28.1820, 'Industrial'),
  KitwePlace('Kitwe Weighbridge',            -12.8058, 28.1818, 'Transport'),

  // ── Fuel Stations (handy meetup points) ──────────────────────────────────
  KitwePlace('Total Obote Avenue',           -12.8020, 28.2122, 'Fuel'),
  KitwePlace('BP Mukuba Road',               -12.7990, 28.2058, 'Fuel'),
  KitwePlace('Engen Parklands',              -12.7988, 28.2032, 'Fuel'),
  KitwePlace('Total Nkana Road',             -12.8042, 28.1978, 'Fuel'),

  // ── Residential: North ───────────────────────────────────────────────────
  KitwePlace('Highridge',                    -12.7780, 28.2150, 'Residential'),
  KitwePlace('Ipusukilo',                    -12.7690, 28.2280, 'Residential'),
  KitwePlace('Mindolo',                      -12.7720, 28.1980, 'Residential'),
  KitwePlace('Chiwala',                      -12.7820, 28.2320, 'Residential'),
  KitwePlace('Ndeke Village',                -12.7850, 28.2350, 'Residential'),
  KitwePlace('Itimpi',                       -12.7880, 28.2680, 'Residential'),
  KitwePlace('Riverside',                    -12.7875, 28.2194, 'Residential'),

  // ── Residential: Central-West ─────────────────────────────────────────────
  KitwePlace('Parklands',                    -12.7986, 28.2045, 'Residential'),
  KitwePlace('Northrise',                    -12.7950, 28.1900, 'Residential'),
  KitwePlace('Nkana West',                   -12.8048, 28.1848, 'Residential'),
  KitwePlace('Nkana East',                   -12.8100, 28.2250, 'Residential'),

  // ── Residential: East ─────────────────────────────────────────────────────
  KitwePlace('Buchi',                        -12.8050, 28.2400, 'Residential'),
  KitwePlace('Mufuchani',                    -12.7958, 28.2458, 'Residential'),
  KitwePlace('Wusakile',                     -12.8175, 28.2450, 'Residential'),
  KitwePlace('Golden Oak',                   -12.8180, 28.2420, 'Residential'),

  // ── Residential: South-East ──────────────────────────────────────────────
  KitwePlace('Garneton',                     -12.8260, 28.2275, 'Residential'),
  KitwePlace('Garneton East',                -12.8255, 28.2430, 'Residential'),
  KitwePlace('Garneton West',                -12.8262, 28.2150, 'Residential'),
  KitwePlace('Bulangililo',                  -12.8185, 28.2315, 'Residential'),
  KitwePlace('Bulangililo Extension',        -12.8220, 28.2380, 'Residential'),
  KitwePlace('Kamfinsa',                     -12.8648, 28.2698, 'Residential'),

  // ── Residential: South ───────────────────────────────────────────────────
  KitwePlace('Chamboli',                     -12.8330, 28.2100, 'Residential'),
  KitwePlace('Nakadoli',                     -12.8350, 28.2100, 'Residential'),
  KitwePlace('Chimwemwe',                    -12.8248, 28.1948, 'Residential'),
  KitwePlace('Makululu',                     -12.8298, 28.1898, 'Residential'),
  KitwePlace('Kwacha',                       -12.8400, 28.1950, 'Residential'),
  KitwePlace('Kawama',                       -12.8548, 28.1848, 'Residential'),

  // ── Residential: South-West (Twatasha belt) ───────────────────────────────
  KitwePlace('Twatasha',                     -12.8400, 28.1650, 'Residential'),
  KitwePlace('Twatasha Township',            -12.8420, 28.1620, 'Residential'),
  KitwePlace('Twatasha Extension',           -12.8438, 28.1598, 'Residential'),
  KitwePlace('Luangwa Area',                 -12.8250, 28.1720, 'Residential'),
  KitwePlace('Kafubu',                       -12.8480, 28.1780, 'Residential'),
];

List<KitwePlace> searchPlaces(String query) {
  if (query.trim().isEmpty) {
    return [
      kitwePlaces.firstWhere((p) => p.name == 'Kitwe CBD'),
      kitwePlaces.firstWhere((p) => p.name == 'Mukuba Mall'),
      kitwePlaces.firstWhere((p) => p.name == 'Copperbelt University'),
      kitwePlaces.firstWhere((p) => p.name == 'Chisokone Market'),
      kitwePlaces.firstWhere((p) => p.name == 'Kitwe Teaching Hospital'),
      kitwePlaces.firstWhere((p) => p.name == "Leo's Pub & Grill"),
    ];
  }
  final q = query.toLowerCase();
  return kitwePlaces
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(10)
      .toList();
}

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dlat = (lat2 - lat1) * pi / 180;
  final dlng = (lng2 - lng1) * pi / 180;
  final a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlng / 2) * sin(dlng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// ── Fare calculation ──────────────────────────────────────────────────────────
//
// Rate: K9/km, min K15 private, min K15/rider dynamic
//
// Two paths:
//   1. OSRM road km (accurate) — used in request_ride_screen after route loads
//   2. Haversine × 1.8 estimate — used on trip cards before OSRM is available

double privateFromRoadKm(double roadKm) => (roadKm * 9).clamp(15.0, 500.0);
double dynamicFromRoadKm(double roadKm) => (roadKm * 9 / 3).clamp(15.0, 500.0);

double estimatePrivateFare(double oLat, double oLng, double dLat, double dLng) {
  final km = haversineKm(oLat, oLng, dLat, dLng) * 1.8;
  return privateFromRoadKm(km);
}

double estimateDynamicFare(double oLat, double oLng, double dLat, double dLng) {
  final km = haversineKm(oLat, oLng, dLat, dLng) * 1.8;
  return dynamicFromRoadKm(km);
}
