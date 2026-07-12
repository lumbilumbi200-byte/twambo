/// Universal place type used across all city place files and the PlacePicker.
/// Each city's typed class (KitwePlace, NdolaPlace, etc.) converts to this
/// at the boundary so the rest of the app only deals with one type.
class TwamboPlace {
  final String name;
  final double lat;
  final double lng;
  final String? tag;
  final String cityId;   // matches CityRegion.id e.g. 'kitwe', 'ndola'
  final String cityName; // display name e.g. 'Kitwe'

  const TwamboPlace(
    this.name,
    this.lat,
    this.lng, {
    this.tag,
    this.cityId = '',
    this.cityName = '',
  });
}
