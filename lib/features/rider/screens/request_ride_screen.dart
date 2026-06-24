import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../dev/kitwe_places.dart';
import '../../../dev/mock_trips.dart';
import '../../../shared/theme.dart';

// Grey tile placeholder shown in mock mode (no network calls)
Widget _mockBaseTile() => ColoredBox(color: Color(0xFFD8DADB));

// ── OSRM route for the request screen ────────────────────────────────────────

class _RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;
  const _RouteResult({required this.points, required this.distanceKm, required this.durationMin});
}

final _requestRouteProvider = FutureProvider.family<_RouteResult, String>((ref, key) async {
  final p = key.split(',');
  final oLat = double.parse(p[0]); final oLng = double.parse(p[1]);
  final dLat = double.parse(p[2]); final dLng = double.parse(p[3]);

  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
  final resp = await dio.get(
    'https://router.project-osrm.org/route/v1/driving/$oLng,$oLat;$dLng,$dLat',
    queryParameters: {'overview': 'full', 'geometries': 'geojson'},
  );
  if (resp.data['code'] != 'Ok') throw Exception('No route found');
  final route = resp.data['routes'][0] as Map;
  final coords = (route['geometry']['coordinates'] as List).map<LatLng>((c) {
    final coord = c as List;
    return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
  }).toList();
  return _RouteResult(
    points: coords,
    distanceKm: (route['distance'] as num).toDouble() / 1000,
    durationMin: ((route['duration'] as num).toDouble() / 60).round(),
  );
});

// ── Screen ────────────────────────────────────────────────────────────────────

class RequestRideScreen extends ConsumerStatefulWidget {
  final KitwePlace from;
  final KitwePlace to;
  const RequestRideScreen({super.key, required this.from, required this.to});

  @override
  ConsumerState<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends ConsumerState<RequestRideScreen> {
  String _mode = 'dynamic';
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final from = widget.from;
    final to = widget.to;
    final routeKey = '${from.lat},${from.lng},${to.lat},${to.lng}';
    final routeAsync = ref.watch(_requestRouteProvider(routeKey));
    final screenH = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : TwamboColors.surfaceAlt;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    // OSRM gives real road distance (e.g. Nkana West→Twatasha = 11km road vs 4.5km straight).
    // Use it for fare when loaded; fall back to haversine estimate while loading.
    final distKm = routeAsync.maybeWhen(data: (r) => r.distanceKm, orElse: () => null);
    final durMin = routeAsync.maybeWhen(data: (r) => r.durationMin, orElse: () => null);
    final privateFare = distKm != null
        ? privateFromRoadKm(distKm)
        : estimatePrivateFare(from.lat, from.lng, to.lat, to.lng);
    final dynamicFare = distKm != null
        ? dynamicFromRoadKm(distKm)
        : estimateDynamicFare(from.lat, from.lng, to.lat, to.lng);
    final fare = _mode == 'dynamic' ? dynamicFare : privateFare;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Map ───────────────────────────────────────────────────────
          SizedBox(
            height: screenH * 0.38,
            child: Stack(children: [
              FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.coordinates(
                    coordinates: [LatLng(from.lat, from.lng), LatLng(to.lat, to.lng)],
                    padding: const EdgeInsets.fromLTRB(40, 60, 40, 80),
                  ),
                ),
                children: [
                  if (kShowMapTiles)
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.twambo.app',
                    )
                  else
                    SizedBox.expand(child: _mockBaseTile()),
                  routeAsync.maybeWhen(
                    data: (r) => PolylineLayer(polylines: [
                      Polyline(
                        points: r.points,
                        color: _mode == 'dynamic' ? TwamboColors.secondary : TwamboColors.primary,
                        strokeWidth: 4,
                        borderColor: Colors.white,
                        borderStrokeWidth: 1.5,
                      ),
                    ]),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(from.lat, from.lng),
                      width: 36, height: 36,
                      child: Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.primary),
                        child: const Icon(Icons.circle, size: 10, color: TwamboColors.textPrimary),
                      ),
                    ),
                    Marker(
                      point: LatLng(to.lat, to.lng),
                      width: 36, height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: TwamboColors.error,
                          boxShadow: [BoxShadow(color: TwamboColors.error.withValues(alpha: 0.4), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.location_on, size: 18, color: Colors.white),
                      ),
                    ),
                  ]),
                ],
              ),

              // Back button + title
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () {
                          if (context.canPop()) { context.pop(); }
                          else { context.go('/search'); }
                        },
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: const Border(left: BorderSide(color: TwamboColors.primary, width: 3)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                          ),
                          child: const Icon(Icons.arrow_back, size: 18, color: TwamboColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: Colors.white,
                        child: Text('REQUEST A RIDE',
                            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800,
                                color: TwamboColors.textPrimary, letterSpacing: 1.5)),
                      ),
                    ]),
                  ),
                ),
              ),

              if (routeAsync.isLoading)
                Positioned(
                  bottom: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: Colors.white,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: TwamboColors.secondary)),
                      const SizedBox(width: 8),
                      Text('Plotting route…', style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, color: TwamboColors.textSecondary)),
                    ]),
                  ),
                ),
            ]),
          ),

          // ── Details ───────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route display
                  Row(children: [
                    const Icon(Icons.circle, size: 10, color: TwamboColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(from.name,
                        style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700,
                            color: textColor))),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(width: 2, height: 14, color: TwamboColors.line),
                  ),
                  Row(children: [
                    Icon(Icons.location_on, size: 14, color: TwamboColors.error),
                    const SizedBox(width: 6),
                    Expanded(child: Text(to.name,
                        style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700,
                            color: TwamboColors.secondary))),
                  ]),

                  if (distKm != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      _InfoChip(Icons.straighten, '${distKm.toStringAsFixed(1)} km'),
                      const SizedBox(width: 16),
                      if (durMin != null) _InfoChip(Icons.timer_outlined, '~$durMin min'),
                    ]),
                  ],

                  const SizedBox(height: 20),
                  _sectionLabel('SELECT RIDE TYPE'),
                  const SizedBox(height: 10),

                  // Mode selector
                  Row(children: [
                    Expanded(child: _ModeCard(
                      title: 'DYNAMIC',
                      subtitle: 'Pool with others\nFare splits as riders join',
                      icon: Icons.people_alt_rounded,
                      fare: dynamicFare,
                      selected: _mode == 'dynamic',
                      onTap: () => setState(() => _mode = 'dynamic'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _ModeCard(
                      title: 'PRIVATE',
                      subtitle: 'Solo ride\nNo waiting, full fare',
                      icon: Icons.person_rounded,
                      fare: privateFare,
                      selected: _mode == 'private',
                      onTap: () => setState(() => _mode = 'private'),
                    )),
                  ]),

                  const SizedBox(height: 20),

                  // Fare breakdown
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel('ESTIMATED FARE'),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text(
                          _mode == 'dynamic'
                              ? 'Your share (3 riders est.)'
                              : 'Full private fare',
                          style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary))),
                        Text('K${fare.toStringAsFixed(0)}',
                            style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w800,
                                color: textColor)),
                      ]),
                      if (_mode == 'dynamic')
                        Text('* Fare drops further as more riders join',
                            style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
                      Text('* Cash to driver on boarding',
                          style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
                    ]),
                  ),

                  if (_mode == 'dynamic') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: TwamboColors.secondary.withValues(alpha: 0.08),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: TwamboColors.secondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Request is broadcast to drivers heading your way. '
                          'Other riders nearby can join and split the fare.',
                          style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.secondary),
                        )),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Submit button
                  GestureDetector(
                    onTap: _submitting ? null : _submit,
                    child: Container(
                      height: 54, width: double.infinity,
                      color: _submitting ? TwamboColors.line : TwamboColors.primary,
                      child: Center(
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2,
                                    color: TwamboColors.textPrimary))
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(
                                  _mode == 'dynamic'
                                      ? 'BROADCAST DYNAMIC REQUEST'
                                      : 'REQUEST PRIVATE RIDE',
                                  style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w800,
                                      color: TwamboColors.textPrimary, letterSpacing: 1),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.send_rounded, size: 16,
                                    color: TwamboColors.textPrimary),
                              ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final fare = _mode == 'dynamic'
        ? estimateDynamicFare(widget.from.lat, widget.from.lng, widget.to.lat, widget.to.lng)
        : estimatePrivateFare(widget.from.lat, widget.from.lng, widget.to.lat, widget.to.lng);
    try {
      if (kUseMockData) {
        await Future.delayed(const Duration(milliseconds: 900));
        addMockRequest(fromName: widget.from.name, toName: widget.to.name, mode: _mode, fare: fare);
      } else {
        await ApiClient.dio.post(Endpoints.createRideRequest, data: {
          'origin_name': widget.from.name,
          'origin_lat': widget.from.lat,
          'origin_lng': widget.from.lng,
          'destination_name': widget.to.name,
          'destination_lat': widget.to.lat,
          'destination_lng': widget.to.lng,
          'mode': _mode,
          'fare_estimate': fare.toStringAsFixed(2),
        });
      }
      if (mounted) context.go('/bookings');
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        final body = e.response?.data;
        String msg;
        if (body is Map) {
          msg = body.entries
              .map((kv) => kv.value is List ? kv.value.join(', ') : kv.value.toString())
              .join('\n');
        } else {
          msg = body?.toString() ?? e.message ?? 'Request failed';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: TwamboColors.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: TwamboColors.error,
        ));
      }
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final double fare;
  final bool selected;
  final VoidCallback onTap;
  const _ModeCard({required this.title, required this.subtitle, required this.icon,
      required this.fare, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? TwamboColors.primary : unselBg,
          border: Border.all(
            color: selected ? TwamboColors.primaryDark : TwamboColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18,
                color: selected ? TwamboColors.textPrimary : TwamboColors.secondary),
            const SizedBox(width: 6),
            Text(title, style: GoogleFonts.spaceGrotesk(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: selected ? TwamboColors.textPrimary : textColor,
                letterSpacing: 1.2)),
          ]),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.manrope(
              fontSize: 10,
              color: selected ? const Color(0xFF333333) : TwamboColors.textSecondary),
              maxLines: 2),
          const SizedBox(height: 10),
          Text('~K${fare.toStringAsFixed(0)}', style: GoogleFonts.spaceGrotesk(
              fontSize: 20, fontWeight: FontWeight.w800,
              color: selected ? const Color(0xFF1A1A1A) : textColor)),
          Text('per seat', style: GoogleFonts.manrope(fontSize: 9,
              color: selected ? const Color(0xFF444444) : TwamboColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: TwamboColors.textSecondary),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
    ]);
  }
}

Widget _sectionLabel(String text) => Text(text,
    style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
        color: TwamboColors.textSecondary, letterSpacing: 2));
