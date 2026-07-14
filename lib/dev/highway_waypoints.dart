import 'twambo_place.dart';

/// Named pickup points on intercity highways — roadside boarding between cities.
/// Verified GPS coordinates from ground-truth survey data.
/// Fares computed proportionally in the booking flow:
///   remaining_km_to_dest / full_route_km × route_fare × 0.88 (roadside discount)
/// The cityName field labels the highway segment shown in the picker.

const _kWaypoints = <({String name, double lat, double lng, String segment})>[
  // ── Ndola → Luanshya (M6 / T3 split) ───────────────────────────────────────
  (name: 'Luanshya-Masangano Turn-off', lat: -13.0125, lng: 28.4891, segment: 'Ndola–Luanshya'),

  // ── Kitwe → Chambishi ────────────────────────────────────────────────────────
  (name: 'Kafue Bridge Checkpoint',     lat: -12.7610, lng: 28.1884, segment: 'Kitwe–Chambishi'),
  (name: 'Chambishi Graveyard Jct',     lat: -12.6582, lng: 28.0321, segment: 'Kitwe–Chambishi'),

  // ── Chambishi → Chingola ─────────────────────────────────────────────────────
  (name: 'Sabina Junction (Bell Jct)',  lat: -12.6324, lng: 27.9712, segment: 'Chambishi–Chingola'),

  // ── Chingola → Chililabombwe ─────────────────────────────────────────────────
  (name: 'Kakoso Junction Hub',         lat: -12.3667, lng: 27.8277, segment: 'Chingola–Chililabombwe'),

  // ── Chingola → Solwezi (T5 / M8) ────────────────────────────────────────────
  (name: 'Chanyanya Turn-Off',          lat: -12.5480, lng: 27.7942, segment: 'Chingola–Solwezi'),

  // ── Kitwe → Chingola via Kalulushi ──────────────────────────────────────────
  (name: 'Kalulushi M18 Kitwe Turn-off', lat: -12.8410, lng: 28.0935, segment: 'Kitwe–Kalulushi–Chingola'),
  (name: 'Chibuluma Mine Road Gate',    lat: -12.8315, lng: 28.0792, segment: 'Kitwe–Kalulushi–Chingola'),
];

List<TwamboPlace> highwayWaypoints() => _kWaypoints
    .map((p) => TwamboPlace(
          p.name, p.lat, p.lng,
          tag: 'Highway',
          cityId: 'highway',
          cityName: p.segment,
        ))
    .toList();
