import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/trip.dart';
import '../../../dev/mock_trips.dart';
import '../../../shared/theme.dart';

// ── OSRM route ─────────────────────────────────────────────────────────────────

class _OsrmResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;
  const _OsrmResult({required this.points, required this.distanceKm, required this.durationMin});
}

// key = "oLat,oLng,dLat,dLng"
final osrmProvider = FutureProvider.family<_OsrmResult, String>((ref, key) async {
  final p = key.split(',');
  final oLat = p[0]; final oLng = p[1];
  final dLat = p[2]; final dLng = p[3];

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

  return _OsrmResult(
    points: coords,
    distanceKm: (route['distance'] as num).toDouble() / 1000,
    durationMin: ((route['duration'] as num).toDouble() / 60).round(),
  );
});

final tripDetailProvider = FutureProvider.family<Trip, int>((ref, id) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 300));
    final trip = mockTripById(id);
    if (trip == null) throw Exception('Trip #$id not found in mock data');
    return trip;
  }
  final resp = await ApiClient.dio.get(Endpoints.tripDetail(id));
  return Trip.fromJson(resp.data);
});

// ── Join event (new rider notification) ───────────────────────────────────────

class _JoinEvent {
  final String name;
  final String boarding;
  const _JoinEvent(this.name, this.boarding);
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class TripDetailScreen extends ConsumerStatefulWidget {
  final int tripId;
  final String? pickupName;
  final double? pickupLat;
  final double? pickupLng;
  final String? dropoffName;
  final double? dropoffLat;
  final double? dropoffLng;
  const TripDetailScreen({
    super.key, required this.tripId,
    this.pickupName, this.pickupLat, this.pickupLng,
    this.dropoffName, this.dropoffLat, this.dropoffLng,
  });

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  final Set<int> _selected = {};
  Timer? _joinTimer;
  Timer? _dismissTimer;
  bool _showNotif = false;
  _JoinEvent? _joinEvent;

  @override
  void initState() {
    super.initState();
    if (kUseMockData) {
      _joinTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() {
          _joinEvent = const _JoinEvent('Mwila K.', 'Mukuba Mall');
          _showNotif = true;
        });
        _dismissTimer = Timer(const Duration(seconds: 5), () {
          if (!mounted) return;
          setState(() => _showNotif = false);
        });
      });
    }
  }

  @override
  void dispose() {
    _joinTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _onSeatTap(int index, int maxSeats) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else if (_selected.length < maxSeats) {
        _selected.add(index);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Only $maxSeats seat${maxSeats == 1 ? '' : 's'} available'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });
  }

  Future<void> _book(BuildContext context, Trip trip) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookSheet(
        trip: trip, seatCount: _selected.length,
        pickupName: widget.pickupName,
        pickupLat: widget.pickupLat, pickupLng: widget.pickupLng,
        dropoffName: widget.dropoffName,
        dropoffLat: widget.dropoffLat, dropoffLng: widget.dropoffLng,
      ),
    );
    if (ok == true && context.mounted) {
      context.go('/bookings');
    }
  }

  Future<void> _joinActive(BuildContext context, Trip trip) async {
    final seatCount = _selected.isEmpty ? 1 : _selected.length;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookSheet(
        trip: trip, seatCount: seatCount,
        pickupName: widget.pickupName,
        pickupLat: widget.pickupLat, pickupLng: widget.pickupLng,
        dropoffName: widget.dropoffName,
        dropoffLat: widget.dropoffLat, dropoffLng: widget.dropoffLng,
      ),
    );
    if (ok == true && context.mounted) {
      context.go('/bookings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final screenH = MediaQuery.of(context).size.height;

    return tripAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: TwamboColors.primary))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (trip) {
        final routeKey = '${trip.originLat},${trip.originLng},${trip.destinationLat},${trip.destinationLng}';
        final routeAsync = ref.watch(osrmProvider(routeKey));
        final canBook = trip.isScheduled && trip.bookingWindowOpen && trip.availableSeats > 0;
        final canJoin = trip.isActive && trip.availableSeats > 0;

        final safeTop = MediaQuery.of(context).padding.top;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          bottomNavigationBar: (canBook || canJoin) && _selected.isNotEmpty
              ? _BookButton(
                  seatCount: _selected.length,
                  total: trip.currentSharedFare * _selected.length,
                  onTap: () => canBook ? _book(context, trip) : _joinActive(context, trip),
                )
              : canJoin
                  ? _JoinButton(onTap: () => _joinActive(context, trip))
                  : null,
          body: Stack(
            children: [
              Column(
                children: [
                  // ── Map (fixed height) ─────────────────────────────
                  SizedBox(
                    height: screenH * 0.38,
                    child: _MapZone(trip: trip, routeAsync: routeAsync),
                  ),

                  // ── Scrollable content ─────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TripHeader(trip: trip, routeAsync: routeAsync),
                          _divider(),
                          if (canBook || canJoin) ...[
                            _SeatSelector(
                              trip: trip,
                              selected: _selected,
                              onTap: (i) => _onSeatTap(i, trip.availableSeats),
                            ),
                            _divider(),
                            _FarePanel(trip: trip, selectedCount: _selected.length),
                          ] else
                            _ClosedBanner(trip: trip),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── New rider joined notification ──────────────────────
              if (_joinEvent != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  top: _showNotif ? safeTop + 10 : -160,
                  left: 16, right: 16,
                  child: _JoinNotification(event: _joinEvent!),
                ),
            ],
          ),
        );
      },
    );
  }
}

Widget _divider() => Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 12), color: TwamboColors.line);

// ── Map zone ───────────────────────────────────────────────────────────────────

class _MapZone extends StatelessWidget {
  final Trip trip;
  final AsyncValue<_OsrmResult> routeAsync;
  const _MapZone({required this.trip, required this.routeAsync});

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(trip.originLat, trip.originLng);
    final dest   = LatLng(trip.destinationLat, trip.destinationLng);

    final routePoints = routeAsync.maybeWhen(
      data: (r) => r.points,
      orElse: () => <LatLng>[],
    );

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: [origin, dest],
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
              const ColoredBox(color: Color(0xFFD8DADB), child: SizedBox.expand()),
            if (routePoints.isNotEmpty)
              PolylineLayer(polylines: [
                Polyline(
                  points: routePoints,
                  color: TwamboColors.secondary,
                  strokeWidth: 4,
                  borderColor: Colors.white,
                  borderStrokeWidth: 1.5,
                ),
              ]),
            MarkerLayer(markers: [
              // Origin — yellow
              Marker(
                point: origin,
                width: 36, height: 36,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: TwamboColors.primary,
                  ),
                  child: const Icon(Icons.circle, size: 10, color: TwamboColors.textPrimary),
                ),
              ),
              // Destination — red
              Marker(
                point: dest,
                width: 36, height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TwamboColors.error,
                    boxShadow: [BoxShadow(color: TwamboColors.error.withValues(alpha: 0.4), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.location_on, size: 18, color: Colors.white),
                ),
              ),
            ]),
          ],
        ),

        // Back button
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
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
                ],
              ),
            ),
          ),
        ),

        // Route loading indicator
        if (routeAsync.isLoading)
          Positioned(
            bottom: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: Colors.white,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: TwamboColors.secondary)),
                  const SizedBox(width: 8),
                  Text('Loading route…', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: TwamboColors.textSecondary)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Trip header ────────────────────────────────────────────────────────────────

class _TripHeader extends StatelessWidget {
  final Trip trip;
  final AsyncValue<_OsrmResult> routeAsync;
  const _TripHeader({required this.trip, required this.routeAsync});

  @override
  Widget build(BuildContext context) {
    final dist = routeAsync.maybeWhen(data: (r) => '${r.distanceKm.toStringAsFixed(1)} km', orElse: () => null);
    final dur  = routeAsync.maybeWhen(data: (r) => '${r.durationMin} min', orElse: () => null);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: TwamboColors.primary,
            child: Text(
              '${trip.mode.toUpperCase()} · ${_fmt(trip.departureTime)}',
              style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
                  color: TwamboColors.textPrimary, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 10),

          // Route
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: TwamboColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(trip.originName,
                  style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: textColor))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(width: 2, height: 16, color: TwamboColors.line),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: TwamboColors.error),
              const SizedBox(width: 8),
              Expanded(child: Text(trip.destinationName,
                  style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: TwamboColors.secondary))),
            ],
          ),
          const SizedBox(height: 12),

          // Stats row
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (dist != null) _Stat(Icons.straighten, dist),
              if (dur != null) _Stat(Icons.timer_outlined, dur),
              _Stat(Icons.person_outline, trip.driverName),
              _Stat(Icons.directions_car_outlined, trip.vehicleMakeModel),
              _Stat(Icons.event_seat_outlined, '${trip.availableSeats} of ${trip.totalSeats} seats free'),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: TwamboColors.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
      ],
    );
  }
}

// ── Seat selector ──────────────────────────────────────────────────────────────

class _SeatSelector extends StatelessWidget {
  final Trip trip;
  final Set<int> selected;
  final Function(int) onTap;
  const _SeatSelector({required this.trip, required this.selected, required this.onTap});

  // Build seat rows. Seat 0 = driver, 1..totalSeats = passengers
  // seatsTaken = how many passenger seats are already booked (seats 1..seatsTaken)
  List<List<int?>> _rows() {
    final total = trip.totalSeats; // passenger seats only
    final rows = <List<int?>>[];
    // Front row
    rows.add([0, total >= 1 ? 1 : null]);
    // Back seats (2 cols for ≤3 pass, else 3 cols)
    final cols = total <= 3 ? 2 : 3;
    for (int i = 2; i <= total; i += cols) {
      final row = <int?>[];
      for (int j = 0; j < cols; j++) {
        final idx = i + j;
        row.add(idx <= total ? idx : null);
      }
      rows.add(row);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final carBg = isDark ? const Color(0xFF1A1A1A) : TwamboColors.surfaceAlt;
    final carBorder = isDark ? const Color(0xFF2E2E2E) : TwamboColors.line;
    final availColor = isDark ? const Color(0xFF2E2E2E) : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SELECT SEATS',
              style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800,
                  color: TwamboColors.textSecondary, letterSpacing: 2)),
          const SizedBox(height: 12),

          // Car outline
          Container(
            decoration: BoxDecoration(
              color: carBg,
              border: Border.all(color: carBorder),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                // Front bumper label
                _CarLabel('FRONT', isBack: false),
                const SizedBox(height: 10),

                // Seat rows
                ...rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: row.map((idx) {
                      if (idx == null) return const SizedBox(width: 48);
                      final isDriver = idx == 0;
                      final isTaken = !isDriver && idx <= trip.seatsTaken;
                      final isSel = selected.contains(idx);
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _SeatTile(
                          index: idx,
                          isDriver: isDriver,
                          isTaken: isTaken,
                          isSelected: isSel,
                          onTap: () => onTap(idx),
                        ),
                      );
                    }).toList(),
                  ),
                )),

                // Back bumper label
                _CarLabel('BACK', isBack: true),
                const SizedBox(height: 10),

                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Legend(TwamboColors.primary, 'Selected'),
                    const SizedBox(width: 16),
                    _Legend(availColor, 'Available'),
                    const SizedBox(width: 16),
                    _Legend(TwamboColors.line, 'Taken'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarLabel extends StatelessWidget {
  final String text;
  final bool isBack;
  const _CarLabel(this.text, {required this.isBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!isBack) ...[
          Expanded(child: Container(height: 1, color: TwamboColors.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(text, style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w700,
                color: TwamboColors.textSecondary, letterSpacing: 2)),
          ),
          Expanded(child: Container(height: 1, color: TwamboColors.line)),
        ] else ...[
          Expanded(child: Container(height: 1, color: TwamboColors.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(text, style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w700,
                color: TwamboColors.textSecondary, letterSpacing: 2)),
          ),
          Expanded(child: Container(height: 1, color: TwamboColors.line)),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: TwamboColors.line),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
      ],
    );
  }
}

// ── Seat tile ──────────────────────────────────────────────────────────────────

class _SeatTile extends StatelessWidget {
  final int index;
  final bool isDriver, isTaken, isSelected;
  final VoidCallback onTap;
  const _SeatTile({
    required this.index, required this.isDriver,
    required this.isTaken, required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Widget child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDriver) {
      bg = const Color(0xFF444444);
      border = const Color(0xFF666666);
      child = const Icon(Icons.airline_seat_recline_normal_rounded, size: 18, color: Colors.white);
    } else if (isTaken) {
      bg = isDark ? const Color(0xFF2E2E2E) : TwamboColors.line;
      border = isDark ? const Color(0xFF3E3E3E) : TwamboColors.line;
      child = const Icon(Icons.person, size: 16, color: TwamboColors.textSecondary);
    } else if (isSelected) {
      bg = TwamboColors.primary;
      border = TwamboColors.primaryDark;
      child = const Icon(Icons.check_rounded, size: 18, color: TwamboColors.textPrimary);
    } else {
      bg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
      border = isDark ? const Color(0xFF3E3E3E) : TwamboColors.line;
      child = Text(
        '$index',
        style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: TwamboColors.textSecondary),
      );
    }

    return GestureDetector(
      onTap: (isDriver || isTaken) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1.5),
          boxShadow: isSelected
              ? [BoxShadow(color: TwamboColors.primary.withValues(alpha: 0.3), blurRadius: 6)]
              : null,
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── Fare panel ─────────────────────────────────────────────────────────────────

class _FarePanel extends StatelessWidget {
  final Trip trip;
  final int selectedCount;
  const _FarePanel({required this.trip, required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    final total = trip.currentSharedFare * (selectedCount == 0 ? 1 : selectedCount);
    final saving = (trip.privateFare / trip.totalSeats * (selectedCount == 0 ? 1 : selectedCount)) - total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        decoration: const BoxDecoration(
          color: TwamboColors.surfaceAlt,
          border: Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FARE BREAKDOWN',
                style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
                    color: TwamboColors.textSecondary, letterSpacing: 2)),
            const SizedBox(height: 10),

            // Per seat price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('K${trip.currentSharedFare.toStringAsFixed(0)} × ${selectedCount == 0 ? 1 : selectedCount} seat${selectedCount > 1 ? 's' : ''}',
                    style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary)),
                Text('K${total.toStringAsFixed(0)}',
                    style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w800, color: TwamboColors.textPrimary)),
              ],
            ),

            // Vs private
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Private price would be',
                    style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
                Text('K${trip.privateFare.toStringAsFixed(0)}',
                    style: GoogleFonts.manrope(fontSize: 12,
                        color: TwamboColors.textSecondary,
                        decoration: TextDecoration.lineThrough)),
              ],
            ),

            if (saving > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: TwamboColors.success.withValues(alpha: 0.12),
                child: Text(
                  'You save K${saving.toStringAsFixed(0)} by sharing',
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: TwamboColors.success),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text('* Shared fare drops as more riders join',
                style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
            Text('* Payment is cash to driver on boarding',
                style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Closed/unavailable banner ──────────────────────────────────────────────────

class _ClosedBanner extends StatelessWidget {
  final Trip trip;
  const _ClosedBanner({required this.trip});

  @override
  Widget build(BuildContext context) {
    final msg = trip.availableSeats == 0
        ? 'This trip is fully booked'
        : !trip.bookingWindowOpen
            ? 'Booking window is closed'
            : 'This trip is no longer accepting bookings';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: TwamboColors.error, width: 4)),
          color: TwamboColors.surfaceAlt,
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.block, color: TwamboColors.error, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.error, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}

// ── Book button ────────────────────────────────────────────────────────────────

class _BookButton extends StatelessWidget {
  final int seatCount;
  final double total;
  final VoidCallback onTap;
  const _BookButton({required this.seatCount, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            color: TwamboColors.primary,
            child: Center(
              child: Text(
                'BOOK $seatCount SEAT${seatCount > 1 ? 'S' : ''} — K${total.toStringAsFixed(0)} CASH',
                style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800,
                    color: TwamboColors.textPrimary, letterSpacing: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Join button (live/active trips) ──────────────────────────────────────────

class _JoinButton extends StatelessWidget {
  final VoidCallback onTap;
  const _JoinButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            color: TwamboColors.success,
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.directions_run_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text('JOIN THIS RIDE', style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 1)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── New rider joined notification banner ──────────────────────────────────────

class _JoinNotification extends StatelessWidget {
  final _JoinEvent event;
  const _JoinNotification({required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D2210) : const Color(0xFFE8F5E9),
        border: const Border(left: BorderSide(color: TwamboColors.success, width: 4)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 16, offset: const Offset(0, 6),
        )],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        // Avatar initial
        Container(
          width: 40, height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: TwamboColors.success,
          ),
          child: Center(child: Text(
            event.name[0],
            style: GoogleFonts.spaceGrotesk(
                fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
          )),
        ),
        const SizedBox(width: 12),

        // Text
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NEW RIDER JOINED', style: GoogleFonts.spaceGrotesk(
              fontSize: 8, fontWeight: FontWeight.w800,
              color: TwamboColors.success, letterSpacing: 1.8)),
          const SizedBox(height: 2),
          Text(
            '${event.name} boards at ${event.boarding}',
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : TwamboColors.textPrimary),
          ),
          Text('Driver is on the way to pick them up',
              style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
        ])),

        const Icon(Icons.person_add_rounded, size: 22, color: TwamboColors.success),
      ]),
    );
  }
}

// ── Booking confirmation sheet ─────────────────────────────────────────────────

class _BookSheet extends ConsumerStatefulWidget {
  final Trip trip;
  final int seatCount;
  final String? pickupName;
  final double? pickupLat;
  final double? pickupLng;
  final String? dropoffName;
  final double? dropoffLat;
  final double? dropoffLng;
  const _BookSheet({
    required this.trip, required this.seatCount,
    this.pickupName, this.pickupLat, this.pickupLng,
    this.dropoffName, this.dropoffLat, this.dropoffLng,
  });

  @override
  ConsumerState<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends ConsumerState<_BookSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (kUseMockData) {
        await Future.delayed(const Duration(milliseconds: 700));
        addMockBookingConfirmed(
          trip: widget.trip,
          seatCount: widget.seatCount,
          pickupName: widget.pickupName,
        );
        if (mounted) Navigator.pop(context, true);
        return;
      }
      // Use rider's chosen pickup, fallback to trip origin
      final pName = widget.pickupName ?? widget.trip.originName;
      final pLat = double.parse((widget.pickupLat ?? widget.trip.originLat).toStringAsFixed(6));
      final pLng = double.parse((widget.pickupLng ?? widget.trip.originLng).toStringAsFixed(6));
      // Use rider's chosen dropoff, fallback to trip destination
      final dName = widget.dropoffName ?? widget.trip.destinationName;
      final dLat = double.parse((widget.dropoffLat ?? widget.trip.destinationLat).toStringAsFixed(6));
      final dLng = double.parse((widget.dropoffLng ?? widget.trip.destinationLng).toStringAsFixed(6));

      if (widget.trip.isActive) {
        // EN ROUTE — send a join request; driver must approve before booking is created
        await ApiClient.dio.post(Endpoints.joinTripRequest(widget.trip.id), data: {
          'pickup_name': pName, 'pickup_lat': pLat, 'pickup_lng': pLng,
          'dropoff_name': dName, 'dropoff_lat': dLat, 'dropoff_lng': dLng,
        });
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Join request sent — waiting for driver approval'),
            duration: Duration(seconds: 4),
          ));
        }
      } else {
        // Scheduled trip — direct booking
        await ApiClient.dio.post(Endpoints.createBooking, data: {
          'trip_id': widget.trip.id,
          'seats_booked': widget.seatCount,
          'pickup_name': pName, 'pickup_lat': pLat, 'pickup_lng': pLng,
          'dropoff_name': dName, 'dropoff_lat': dLat, 'dropoff_lng': dLng,
        });
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      String msg = 'Booking failed — try again';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) msg = data['detail']?.toString() ?? msg;
      } catch (_) {}
      setState(() { _loading = false; _error = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.trip.currentSharedFare * widget.seatCount;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: TwamboColors.primary, width: 4),
          top: BorderSide(color: TwamboColors.line),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONFIRM BOOKING',
              style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800,
                  color: TwamboColors.textSecondary, letterSpacing: 2)),
          const SizedBox(height: 12),

          Text('${widget.trip.originName} → ${widget.trip.destinationName}',
              style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: TwamboColors.textPrimary)),
          const SizedBox(height: 4),
          Text('${widget.seatCount} seat${widget.seatCount > 1 ? 's' : ''} · ${_fmt(widget.trip.departureTime)}',
              style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
          if (widget.pickupName != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.pin_drop_outlined, size: 12, color: TwamboColors.secondary),
              const SizedBox(width: 4),
              Text('Board at: ${widget.pickupName}',
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600,
                      color: TwamboColors.secondary)),
            ]),
          ],

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total (cash to driver)',
                  style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary)),
              Text('K${total.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceGrotesk(fontSize: 26, fontWeight: FontWeight.w800, color: TwamboColors.textPrimary)),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: TwamboColors.error, fontSize: 12)),
          ],

          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loading ? null : _confirm,
            child: Container(
              height: 52, width: double.infinity,
              color: _loading ? TwamboColors.line : TwamboColors.primary,
              child: Center(
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: TwamboColors.textPrimary))
                    : Text(widget.trip.isActive ? 'REQUEST TO JOIN' : 'CONFIRM — PAY CASH ON BOARDING',
                        style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800,
                            letterSpacing: 1, color: TwamboColors.textPrimary)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Center(
              child: Text('Cancel',
                  style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
