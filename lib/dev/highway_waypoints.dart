import 'twambo_place.dart';

/// Named pickup points on intercity highways.
/// Coordinates marked (~) are approximate — verify on Google Maps.
/// Fares are computed proportionally in the booking flow (remaining distance
/// to destination ÷ full route distance × route_fare), so no hardcoded price here.
/// The cityName field shows the segment label in the picker.

const _kWaypoints = <({String name, double lat, double lng, String segment})>[
  // ── Ndola → Luanshya ──────────────────────────────────────────────────────
  (name: 'Ndola Airport Turnoff', lat: -12.999, lng: 28.665, segment: 'Ndola–Luanshya'),  // ~
  (name: 'Stadium Turnoff',       lat: -13.055, lng: 28.528, segment: 'Ndola–Luanshya'),  // ~

  // ── Luanshya → Kitwe ──────────────────────────────────────────────────────
  (name: 'Fisenge Turnoff',       lat: -12.968, lng: 28.315, segment: 'Luanshya–Kitwe'),  // ~

  // ── Kitwe → Chambishi ─────────────────────────────────────────────────────
  (name: 'Sabina Area',           lat: -12.726, lng: 28.127, segment: 'Kitwe–Chambishi'), // ~

  // ── Kitwe → Chingola ──────────────────────────────────────────────────────
  (name: 'Chingola Road Junction', lat: -12.665, lng: 28.036, segment: 'Kitwe–Chingola'), // ~

  // ── Chingola → Chililabombwe ───────────────────────────────────────────────
  (name: 'Chililabombwe Approach', lat: -12.444, lng: 27.845, segment: 'Chingola–Chililabombwe'), // ~
];

List<TwamboPlace> highwayWaypoints() => _kWaypoints
    .map((p) => TwamboPlace(
          p.name, p.lat, p.lng,
          tag: 'Highway',
          cityId: 'highway',
          cityName: p.segment,
        ))
    .toList();
