import 'twambo_place.dart';
import 'highway_waypoints.dart';
import 'copperbelt/kitwe_places.dart';
import 'copperbelt/ndola_places.dart';
import 'copperbelt/chingola_places.dart';
import 'copperbelt/luanshya_places.dart';
import 'copperbelt/chililabombwe_places.dart';
import 'copperbelt/chambishi_places.dart';
import 'northwestern/solwezi_places.dart';
import 'northwestern/lumwana_kalumbila_places.dart';
import 'southern/livingstone_places.dart';
import 'southern/choma_places.dart';
import 'southern/mazabuka_places.dart';
import 'southern/monze_places.dart';

// ── Per-city converters ───────────────────────────────────────────────────────

List<TwamboPlace> kitweTwamboPlaces() => kitwePlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'kitwe', cityName: 'Kitwe'))
    .toList();

List<TwamboPlace> ndolaTwamboPlaces() => ndolaPlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'ndola', cityName: 'Ndola'))
    .toList();

List<TwamboPlace> chingolaTwamboPlaces() => chingolaPlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'chingola', cityName: 'Chingola'))
    .toList();

List<TwamboPlace> luanshyaTwamboPlaces() => luanshyaPlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'luanshya', cityName: 'Luanshya'))
    .toList();

List<TwamboPlace> chililabombweTwamboPlaces() => chililabombwePlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'chililabombwe', cityName: 'Chililabombwe'))
    .toList();

List<TwamboPlace> chambishiTwamboPlaces() => chambishiPlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'chambishi', cityName: 'Chambishi'))
    .toList();

List<TwamboPlace> solweziTwamboPlaces() => solweziPlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'solwezi', cityName: 'Solwezi'))
    .toList();

List<TwamboPlace> lumwanaKalumbilaTwamboPlaces() => lumwanaKalumbilaPlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'lumwana_kalumbila', cityName: 'Lumwana / Kalumbila'))
    .toList();

List<TwamboPlace> livingstoneTwamboPlaces() => livingstonePlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'livingstone', cityName: 'Livingstone'))
    .toList();

List<TwamboPlace> chomaTwamboPlaces() => chomaPlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'choma', cityName: 'Choma'))
    .toList();

List<TwamboPlace> mazabukaTwamboPlaces() => mazabukaPlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'mazabuka', cityName: 'Mazabuka'))
    .toList();

List<TwamboPlace> monzeTwamboPlaces() => monzePlaces
    .map((p) => TwamboPlace(p.name, p.lat, p.lng, tag: p.tag, cityId: 'monze', cityName: 'Monze'))
    .toList();

// ── Combined list — all covered cities ───────────────────────────────────────

/// Intercity (long-distance) places: Copperbelt + Northwestern + highway waypoints.
/// Southern province is excluded until routes go live there.
List<TwamboPlace> intercityTwamboPlaces() => [
      ...kitweTwamboPlaces(),
      ...ndolaTwamboPlaces(),
      ...chingolaTwamboPlaces(),
      ...luanshyaTwamboPlaces(),
      ...chililabombweTwamboPlaces(),
      ...chambishiTwamboPlaces(),
      ...solweziTwamboPlaces(),
      ...lumwanaKalumbilaTwamboPlaces(),
      ...highwayWaypoints(),
    ];

// ── Route fare lookup table ───────────────────────────────────────────────────
// Agreed market fares (ZMW) for standard highway pickup between city pairs.
// City pickup (driver diverts off-route) adds a detour fee on top.
// Symmetric — look up either direction.
const Map<String, Map<String, double>> kRouteFares = {
  'kitwe': {
    'ndola': 50, 'chambishi': 20, 'chingola': 35, 'chililabombwe': 65,
    'luanshya': 30, 'solwezi': 100, 'lumwana_kalumbila': 150,
  },
  'ndola': {
    'kitwe': 50, 'chambishi': 55, 'chingola': 70, 'chililabombwe': 95,
    'luanshya': 35, 'solwezi': 130, 'lumwana_kalumbila': 250,
  },
  'chingola': {
    'kitwe': 35, 'ndola': 70, 'chililabombwe': 40, 'luanshya': 65,
    'chambishi': 50, 'solwezi': 70, 'lumwana_kalumbila': 120,
  },
  'chililabombwe': {
    'kitwe': 65, 'ndola': 95, 'chingola': 40, 'luanshya': 80,
    'chambishi': 60, 'solwezi': 55, 'lumwana_kalumbila': 100,
  },
  'luanshya': {
    'kitwe': 30, 'ndola': 35, 'chingola': 65, 'chililabombwe': 80,
    'chambishi': 45, 'solwezi': 110, 'lumwana_kalumbila': 160,
  },
  'chambishi': {
    'kitwe': 20, 'ndola': 55, 'chingola': 50, 'chililabombwe': 60,
    'luanshya': 45, 'solwezi': 115, 'lumwana_kalumbila': 140,
  },
  'solwezi': {
    'kitwe': 100, 'ndola': 130, 'chingola': 70, 'chililabombwe': 55,
    'luanshya': 110, 'chambishi': 115, 'lumwana_kalumbila': 50,
  },
  'lumwana_kalumbila': {
    'kitwe': 150, 'ndola': 250, 'chingola': 120, 'chililabombwe': 100,
    'luanshya': 160, 'chambishi': 140, 'solwezi': 50,
  },
};

/// Returns the suggested highway fare for a hike trip between two cities.
/// Returns null if the pair isn't in the table (driver enters manually).
double? suggestedHikeFare(String fromCityId, String toCityId) =>
    kRouteFares[fromCityId]?[toCityId] ??
    kRouteFares[toCityId]?[fromCityId];

List<TwamboPlace> allTwamboPlaces() => [
      ...kitweTwamboPlaces(),
      ...ndolaTwamboPlaces(),
      ...chingolaTwamboPlaces(),
      ...luanshyaTwamboPlaces(),
      ...chililabombweTwamboPlaces(),
      ...chambishiTwamboPlaces(),
      ...solweziTwamboPlaces(),
      ...lumwanaKalumbilaTwamboPlaces(),
      ...livingstoneTwamboPlaces(),
      ...chomaTwamboPlaces(),
      ...mazabukaTwamboPlaces(),
      ...monzeTwamboPlaces(),
    ];

/// Search places in a given city list by name or tag.
/// When query is empty, returns the first 6 entries as "popular".
List<TwamboPlace> searchCityPlaces(String query, List<TwamboPlace> places) {
  if (query.trim().isEmpty) return places.take(6).toList();
  final q = query.toLowerCase();
  return places
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.tag?.toLowerCase().contains(q) ?? false))
      .take(12)
      .toList();
}

/// Returns the place list for a specific city by id.
/// Falls back to Kitwe if the city id is unrecognised.
List<TwamboPlace> placesForCity(String cityId) {
  switch (cityId) {
    case 'kitwe':           return kitweTwamboPlaces();
    case 'ndola':           return ndolaTwamboPlaces();
    case 'chingola':        return chingolaTwamboPlaces();
    case 'luanshya':        return luanshyaTwamboPlaces();
    case 'chililabombwe':   return chililabombweTwamboPlaces();
    case 'chambishi':       return chambishiTwamboPlaces();
    case 'solwezi':         return solweziTwamboPlaces();
    case 'lumwana_kalumbila': return lumwanaKalumbilaTwamboPlaces();
    case 'livingstone':     return livingstoneTwamboPlaces();
    case 'choma':           return chomaTwamboPlaces();
    case 'mazabuka':        return mazabukaTwamboPlaces();
    case 'monze':           return monzeTwamboPlaces();
    default:                return kitweTwamboPlaces();
  }
}
