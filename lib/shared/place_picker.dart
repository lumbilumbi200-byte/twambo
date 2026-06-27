import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../dev/kitwe_places.dart';
import '../dev/mock_trips.dart' show kShowMapTiles;
import 'theme.dart';

/// Tappable field that opens a search-and-select overlay for KitwePlaces.
/// Includes a map pin option alongside the search list.
class PlacePicker extends StatelessWidget {
  final KitwePlace? selected;
  final String placeholder;
  final String label;
  final IconData icon;
  final ValueChanged<KitwePlace> onSelected;

  const PlacePicker({
    required this.label,
    required this.placeholder,
    required this.onSelected,
    this.selected,
    this.icon = Icons.location_on_outlined,
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
        // Main search tap
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
                        if (selected!.tag != null)
                          Text(selected!.tag!, style: GoogleFonts.manrope(
                              fontSize: 10, color: TwamboColors.textSecondary)),
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
        // Map pin button
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
    final result = await showModalBottomSheet<KitwePlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceSearchSheet(initial: selected),
    );
    if (result != null) onSelected(result);
  }

  Future<void> _openMap(BuildContext context) async {
    final result = await showModalBottomSheet<KitwePlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MapPickerSheet(title: label),
    );
    if (result != null) onSelected(result);
  }
}

// ── Search sheet ──────────────────────────────────────────────────────────────

class _PlaceSearchSheet extends StatefulWidget {
  final KitwePlace? initial;
  const _PlaceSearchSheet({this.initial});

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _ctrl = TextEditingController();
  List<KitwePlace> _results = kitwePlaces;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_filter);
  }

  void _filter() {
    final q = _ctrl.text.toLowerCase();
    setState(() {
      _results = q.isEmpty
          ? kitwePlaces
          : kitwePlaces.where((p) =>
              p.name.toLowerCase().contains(q) ||
              (p.tag?.toLowerCase().contains(q) ?? false)).toList();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.85,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
      ),
      child: Column(children: [
        // Handle
        const SizedBox(height: 8),
        Container(width: 36, height: 4, color: TwamboColors.line),
        const SizedBox(height: 12),

        // Header
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

        // Search field
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
                hintText: 'Search places in Kitwe…',
                hintStyle: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary),
                prefixIcon: const Icon(Icons.search, size: 18, color: TwamboColors.textSecondary),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () { _ctrl.clear(); },
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

        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('${_results.length} PLACES', style: GoogleFonts.spaceGrotesk(
                fontSize: 8, fontWeight: FontWeight.w700,
                color: TwamboColors.textSecondary, letterSpacing: 1.5))),
        ),
        const SizedBox(height: 4),

        // Results
        Expanded(child: ListView.builder(
          itemCount: _results.length,
          itemBuilder: (_, i) {
            final p = _results[i];
            final isSelected = widget.initial?.name == p.name;
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
                  Icon(
                    _tagIcon(p.tag),
                    size: 16,
                    color: isSelected ? TwamboColors.primary : TwamboColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: GoogleFonts.manrope(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: isSelected ? TwamboColors.primary : textColor)),
                    if (p.tag != null)
                      Text(p.tag!, style: GoogleFonts.manrope(
                          fontSize: 10, color: TwamboColors.textSecondary)),
                  ])),
                  if (isSelected)
                    const Icon(Icons.check_circle, size: 16, color: TwamboColors.primary),
                ]),
              ),
            );
          },
        )),
      ]),
    );
  }

  IconData _tagIcon(String? tag) {
    switch (tag) {
      case 'Market': return Icons.storefront_outlined;
      case 'Shopping': return Icons.shopping_bag_outlined;
      case 'Hospital': return Icons.local_hospital_outlined;
      case 'School': return Icons.school_outlined;
      case 'Transport': return Icons.directions_bus_outlined;
      case 'Park': return Icons.park_outlined;
      case 'Street': return Icons.turn_right_outlined;
      default: return Icons.location_on_outlined;
    }
  }
}

// ── Map pin sheet ─────────────────────────────────────────────────────────────

class _MapPickerSheet extends StatefulWidget {
  final String title;
  const _MapPickerSheet({required this.title});
  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  final _mapCtrl = MapController();
  LatLng _center = const LatLng(-12.8024, 28.2132);
  bool _confirming = false;

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }



  String _nearestName(double lat, double lng) {
    KitwePlace? nearest;
    double minDist = double.infinity;
    for (final p in kitwePlaces) {
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

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    LatLng pos;
    try { pos = _mapCtrl.camera.center; } catch (_) { pos = _center; }
    final name = _nearestName(pos.latitude, pos.longitude);
    if (mounted) {
      Navigator.pop(context, KitwePlace(name, pos.latitude, pos.longitude));
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
        // Header
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

        // Map
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: const LatLng(-12.8024, 28.2132),
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

            // Center pin
            Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Icon(Icons.location_on_rounded, size: 48,
                    color: TwamboColors.error,
                    shadows: const [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))]),
              ),
            ),

            // Crosshair dot
            Center(
              child: Container(width: 4, height: 4,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
            ),

            // Live coordinate label
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

        // Confirm button
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
