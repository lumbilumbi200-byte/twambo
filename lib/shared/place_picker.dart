import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../dev/twambo_place.dart';
import '../dev/mock_trips.dart' show kShowMapTiles;
import 'theme.dart';

/// Tappable field that opens a search-and-select overlay.
///
/// [places]    — the list to search. Pass [placesForCity] for a city-scoped
///               picker or [allTwamboPlaces()] for a hike multi-city picker.
/// [cityLabel] — shown in the search hint, e.g. "Kitwe" or "all cities".
/// [mapCenter] — initial centre for the map-pin sheet (defaults to Kitwe).
class PlacePicker extends StatelessWidget {
  final TwamboPlace? selected;
  final String placeholder;
  final String label;
  final IconData icon;
  final ValueChanged<TwamboPlace> onSelected;
  final List<TwamboPlace> places;
  final String cityLabel;
  final LatLng mapCenter;

  const PlacePicker({
    required this.label,
    required this.placeholder,
    required this.onSelected,
    required this.places,
    this.selected,
    this.cityLabel = 'your city',
    this.icon = Icons.location_on_outlined,
    this.mapCenter = const LatLng(-12.8024, 28.2132),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final borderColor = isDark ? const Color(0xFF3E3E3E) : TwamboColors.line;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: TwamboColors.textSecondary, letterSpacing: 1.5)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _openSearch(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: fillColor,
                border: Border.all(
                  color: selected != null ? TwamboColors.primary : borderColor,
                  width: selected != null ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Icon(icon, size: 18,
                    color: selected != null ? TwamboColors.primary : TwamboColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(child: selected == null
                    ? Text(placeholder, style: GoogleFonts.manrope(
                        fontSize: 13, color: TwamboColors.textSecondary))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(selected!.name, style: GoogleFonts.manrope(
                            fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                        if (selected!.tag != null || selected!.cityName.isNotEmpty)
                          Text(
                            [if (selected!.cityName.isNotEmpty) selected!.cityName,
                             if (selected!.tag != null) selected!.tag!].join(' · '),
                            style: GoogleFonts.manrope(
                                fontSize: 10, color: TwamboColors.textSecondary),
                          ),
                      ])),
                Icon(
                  selected != null ? Icons.check_circle_outline : Icons.chevron_right,
                  size: 18,
                  color: selected != null ? TwamboColors.primary : TwamboColors.textSecondary,
                ),
              ]),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _openMap(context),
          child: Container(
            width: 48, height: 48,
            margin: const EdgeInsets.only(left: 6),
            color: TwamboColors.primary.withValues(alpha: 0.12),
            child: const Icon(Icons.map_outlined, size: 20, color: TwamboColors.primary),
          ),
        ),
      ]),
    ]);
  }

  Future<void> _openSearch(BuildContext context) async {
    final result = await showModalBottomSheet<TwamboPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceSearchSheet(
        initial: selected,
        places: places,
        cityLabel: cityLabel,
      ),
    );
    if (result != null) onSelected(result);
  }

  Future<void> _openMap(BuildContext context) async {
    final result = await showModalBottomSheet<TwamboPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MapPickerSheet(title: label, center: mapCenter, places: places),
    );
    if (result != null) onSelected(result);
  }
}

// ── Search sheet ──────────────────────────────────────────────────────────────

class _PlaceSearchSheet extends StatefulWidget {
  final TwamboPlace? initial;
  final List<TwamboPlace> places;
  final String cityLabel;
  const _PlaceSearchSheet({this.initial, required this.places, required this.cityLabel});

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _ctrl = TextEditingController();
  late List<TwamboPlace> _results;
  List<TwamboPlace> _nominatimResults = [];
  bool _nominatimLoading = false;
  Timer? _debounce;

  static final _nominatim = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    headers: {'User-Agent': 'TwamboApp/1.0 (twambo.zm)'},
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  @override
  void initState() {
    super.initState();
    _results = widget.places;
    _ctrl.addListener(_onQuery);
  }

  void _onQuery() {
    final q = _ctrl.text.toLowerCase();
    setState(() {
      _results = q.isEmpty
          ? widget.places
          : widget.places.where((p) =>
              p.name.toLowerCase().contains(q) ||
              (p.tag?.toLowerCase().contains(q) ?? false) ||
              p.cityName.toLowerCase().contains(q)).toList();
    });

    _debounce?.cancel();
    final raw = _ctrl.text.trim();
    if (raw.length < 3) {
      setState(() { _nominatimResults = []; _nominatimLoading = false; });
      return;
    }
    setState(() { _nominatimResults = []; _nominatimLoading = true; });
    _debounce = Timer(const Duration(milliseconds: 600), () => _searchNominatim(raw));
  }

  Future<void> _searchNominatim(String q) async {
    try {
      final resp = await _nominatim.get<List<dynamic>>('/search', queryParameters: {
        'q': q,
        'format': 'json',
        'countrycodes': 'zm',
        'limit': 5,
        'addressdetails': 1,
      });
      final items = resp.data ?? [];
      final results = <TwamboPlace>[];
      for (final item in items) {
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lng = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lng == null) continue;
        final display = (item['display_name'] as String? ?? '');
        final name = display.split(',').first.trim();
        results.add(TwamboPlace(name, lat, lng,
            cityId: _nearestCityId(lat, lng), tag: 'Map Search'));
      }
      if (mounted) setState(() { _nominatimResults = results; _nominatimLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _nominatimResults = []; _nominatimLoading = false; });
    }
  }

  String _nearestCityId(double lat, double lng) {
    TwamboPlace? nearest;
    double minDist = double.infinity;
    for (final p in widget.places) {
      final d = (lat - p.lat) * (lat - p.lat) + (lng - p.lng) * (lng - p.lng);
      if (d < minDist) { minDist = d; nearest = p; }
    }
    return nearest?.cityId ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final screenH = MediaQuery.of(context).size.height;

    final showNominatim = _nominatimLoading || _nominatimResults.isNotEmpty;
    int itemCount = _results.length;
    if (showNominatim) {
      itemCount += 1; // section header
      if (_nominatimLoading) itemCount += 1;
      itemCount += _nominatimResults.length;
    }

    return Container(
      height: screenH * 0.85,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 4, color: TwamboColors.line),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: Text('CHOOSE PLACE', style: GoogleFonts.spaceGrotesk(
                fontSize: 12, fontWeight: FontWeight.w800,
                color: textColor, letterSpacing: 1.5))),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, size: 20, color: TwamboColors.textSecondary),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt,
              border: Border.all(color: TwamboColors.line),
            ),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: GoogleFonts.manrope(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search places in ${widget.cityLabel}…',
                hintStyle: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary),
                prefixIcon: const Icon(Icons.search, size: 18, color: TwamboColors.textSecondary),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: _ctrl.clear,
                        child: const Icon(Icons.clear, size: 16, color: TwamboColors.textSecondary),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('${_results.length} PLACES', style: GoogleFonts.spaceGrotesk(
                fontSize: 8, fontWeight: FontWeight.w700,
                color: TwamboColors.textSecondary, letterSpacing: 1.5))),
        ),
        const SizedBox(height: 4),

        Expanded(child: ListView.builder(
          itemCount: itemCount,
          itemBuilder: (_, i) {
            if (i < _results.length) {
              return _buildPlaceRow(context, _results[i], isDark, textColor);
            }

            final offset = i - _results.length;

            // Section header
            if (offset == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(children: [
                  const Icon(Icons.public, size: 12, color: TwamboColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('FROM MAP SEARCH', style: GoogleFonts.spaceGrotesk(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      color: TwamboColors.textSecondary, letterSpacing: 1.5)),
                ]),
              );
            }

            // Loading spinner
            if (_nominatimLoading && offset == 1) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: TwamboColors.primary))),
              );
            }

            // Nominatim results
            final ni = offset - 1 - (_nominatimLoading ? 1 : 0);
            if (ni >= 0 && ni < _nominatimResults.length) {
              return _buildPlaceRow(context, _nominatimResults[ni], isDark, textColor,
                  fromNominatim: true);
            }

            return const SizedBox.shrink();
          },
        )),
      ]),
    );
  }

  Widget _buildPlaceRow(BuildContext context, TwamboPlace p, bool isDark, Color textColor,
      {bool fromNominatim = false}) {
    final isSelected = widget.initial?.name == p.name && widget.initial?.cityId == p.cityId;
    return GestureDetector(
      onTap: () => Navigator.pop(context, p),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        decoration: BoxDecoration(
          color: isSelected
              ? TwamboColors.primary.withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF1E1E1E) : TwamboColors.surfaceAlt),
          border: Border(left: BorderSide(
            color: isSelected ? TwamboColors.primary : Colors.transparent,
            width: 3,
          )),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Icon(fromNominatim ? Icons.public : _tagIcon(p.tag), size: 16,
              color: isSelected ? TwamboColors.primary : TwamboColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: GoogleFonts.manrope(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: isSelected ? TwamboColors.primary : textColor)),
            if (p.tag != null || p.cityName.isNotEmpty)
              Text(
                [if (p.cityName.isNotEmpty) p.cityName,
                 if (p.tag != null) p.tag!].join(' · '),
                style: GoogleFonts.manrope(
                    fontSize: 10, color: TwamboColors.textSecondary),
              ),
          ])),
          if (isSelected)
            const Icon(Icons.check_circle, size: 16, color: TwamboColors.primary),
        ]),
      ),
    );
  }

  IconData _tagIcon(String? tag) {
    switch (tag) {
      case 'Market':    return Icons.storefront_outlined;
      case 'Shopping':  return Icons.shopping_bag_outlined;
      case 'Hospital':  return Icons.local_hospital_outlined;
      case 'School':    return Icons.school_outlined;
      case 'Transport': return Icons.directions_bus_outlined;
      case 'Park':      return Icons.park_outlined;
      case 'Street':    return Icons.turn_right_outlined;
      case 'Fuel':      return Icons.local_gas_station_outlined;
      case 'Lodge':     return Icons.hotel_outlined;
      case 'Mine':      return Icons.factory_outlined;
      default:          return Icons.location_on_outlined;
    }
  }
}

// ── Map pin sheet ─────────────────────────────────────────────────────────────

class _MapPickerSheet extends StatefulWidget {
  final String title;
  final LatLng center;
  final List<TwamboPlace> places;
  const _MapPickerSheet({required this.title, required this.center, required this.places});
  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  final _mapCtrl = MapController();
  late LatLng _center;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _center = widget.center;
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  String _nearestName(double lat, double lng) {
    TwamboPlace? nearest;
    double minDist = double.infinity;
    for (final p in widget.places) {
      final dLat = lat - p.lat;
      final dLng = lng - p.lng;
      final d = dLat * dLat + dLng * dLng;
      if (d < minDist) { minDist = d; nearest = p; }
    }
    if (nearest == null) return 'Pinned location';
    final km = minDist * 111.32;
    if (km < 0.5) return nearest.name;
    if (km < 2.0) return '${nearest.name} area';
    return 'Pinned location';
  }

  String _nearestCityId(double lat, double lng) {
    TwamboPlace? nearest;
    double minDist = double.infinity;
    for (final p in widget.places) {
      final dLat = lat - p.lat;
      final dLng = lng - p.lng;
      final d = dLat * dLat + dLng * dLng;
      if (d < minDist) { minDist = d; nearest = p; }
    }
    return nearest?.cityId ?? '';
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    LatLng pos;
    try { pos = _mapCtrl.camera.center; } catch (_) { pos = _center; }
    final name = _nearestName(pos.latitude, pos.longitude);
    final cityId = _nearestCityId(pos.latitude, pos.longitude);
    if (mounted) {
      Navigator.pop(context, TwamboPlace(name, pos.latitude, pos.longitude, cityId: cityId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Column(children: [
        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.surfaceAlt,
                  border: const Border(left: BorderSide(color: TwamboColors.primary, width: 3)),
                ),
                child: Icon(Icons.arrow_back, size: 16,
                    color: isDark ? Colors.white : TwamboColors.textPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(widget.title, style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: textColor, letterSpacing: 1.2)),
                Text('Pan to pin location',
                    style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
              ]),
            ),
          ]),
        ),

        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: widget.center,
                initialZoom: 14.5,
                onMapEvent: (event) {
                  setState(() => _center = event.camera.center);
                },
              ),
              children: [
                if (kShowMapTiles)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.twambo.app',
                  )
                else
                  const ColoredBox(color: Color(0xFFD8DADB), child: SizedBox.expand()),
              ],
            ),
            Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Icon(Icons.location_on_rounded, size: 48,
                    color: TwamboColors.error,
                    shadows: const [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))]),
              ),
            ),
            Center(
              child: Container(width: 4, height: 4,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
            ),
            Positioned(
              bottom: 8, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.black87,
                  child: Text(
                    '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}',
                    style: GoogleFonts.manrope(fontSize: 12, color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ]),
        ),

        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: GestureDetector(
            onTap: _confirming ? null : _confirm,
            child: Container(
              height: 52, width: double.infinity,
              color: _confirming ? TwamboColors.line : TwamboColors.primary,
              child: Center(child: _confirming
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: TwamboColors.textPrimary))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('SELECT THIS LOCATION', style: GoogleFonts.spaceGrotesk(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: TwamboColors.textPrimary, letterSpacing: 1.5)),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_rounded, size: 16, color: TwamboColors.textPrimary),
                    ])),
            ),
          ),
        ),
      ]),
    );
  }
}
