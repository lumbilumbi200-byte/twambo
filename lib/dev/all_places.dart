import 'twambo_place.dart';
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

/// Intercity (long-distance) places: Copperbelt + Northwestern only.
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
    ];

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
