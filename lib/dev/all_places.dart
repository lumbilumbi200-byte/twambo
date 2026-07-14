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
// Fares calibrated against real Copperbelt market rates (2025).
// Direct pairs from operator survey; indirect pairs derived via route segments.
// Symmetric — suggestedHikeFare() looks up either direction.
const Map<String, Map<String, double>> kRouteFares = {
  'kitwe': {
    'ndola': 40,  'chambishi': 25,  'chingola': 45,  'chililabombwe': 65,
    'luanshya': 30,  'solwezi': 230,  'lumwana_kalumbila': 310,
  },
  'ndola': {
    'kitwe': 40,  'chambishi': 60,  'chingola': 80,  'chililabombwe': 100,
    'luanshya': 30,  'solwezi': 260,  'lumwana_kalumbila': 330,
  },
  'chingola': {
    'kitwe': 45,  'ndola': 80,  'chililabombwe': 25,  'luanshya': 70,
    'chambishi': 35,  'solwezi': 200,  'lumwana_kalumbila': 280,
  },
  'chililabombwe': {
    'kitwe': 65,  'ndola': 100,  'chingola': 25,  'luanshya': 90,
    'chambishi': 55,  'solwezi': 210,  'lumwana_kalumbila': 290,
  },
  'luanshya': {
    'kitwe': 30,  'ndola': 30,  'chingola': 70,  'chililabombwe': 90,
    'chambishi': 50,  'solwezi': 250,  'lumwana_kalumbila': 320,
  },
  'chambishi': {
    'kitwe': 25,  'ndola': 60,  'chingola': 35,  'chililabombwe': 55,
    'luanshya': 50,  'solwezi': 220,  'lumwana_kalumbila': 300,
  },
  'solwezi': {
    'kitwe': 230,  'ndola': 260,  'chingola': 200,  'chililabombwe': 210,
    'luanshya': 250,  'chambishi': 220,  'lumwana_kalumbila': 100,
  },
  'lumwana_kalumbila': {
    'kitwe': 310,  'ndola': 330,  'chingola': 280,  'chililabombwe': 290,
    'luanshya': 320,  'chambishi': 300,  'solwezi': 100,
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
