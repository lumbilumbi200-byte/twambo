import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../dev/all_places.dart';
import '../../../dev/city_regions.dart';
import '../../../dev/copperbelt/kitwe_places.dart' show haversineKm;
import '../../../dev/twambo_place.dart';
import '../../../dev/mock_trips.dart' show kShowMapTiles, kUseMockData, addMockDriverTrip;
import '../../../features/auth/auth_provider.dart';
import '../../../shared/place_picker.dart';
import '../../../shared/theme.dart';
import 'driver_home_screen.dart';

final _createTripRouteProvider = FutureProvider.family<List<LatLng>, String>((ref, key) async {
  final p = key.split(',');
  final oLat = double.parse(p[0]); final oLng = double.parse(p[1]);
  final dLat = double.parse(p[2]); final dLng = double.parse(p[3]);

  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
  final resp = await dio.get(
    'https://router.project-osrm.org/route/v1/driving/$oLng,$oLat;$dLng,$dLat',
    queryParameters: {'overview': 'full', 'geometries': 'geojson'},
  );
  if (resp.data['code'] != 'Ok') throw Exception('no route');
  return (resp.data['routes'][0]['geometry']['coordinates'] as List).map<LatLng>((c) {
    final coord = c as List;
    return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
  }).toList();
});

class CreateTripScreen extends ConsumerStatefulWidget {
  final String? initialTripType;
  const CreateTripScreen({super.key, this.initialTripType});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  TwamboPlace? _origin;
  TwamboPlace? _destination;
  DateTime? _departureTime;
  late String _tripType = widget.initialTripType == 'hike' ? 'hike' : 'city';  // city | hike
  String _mode = 'shared';     // shared | private | dynamic
  CityRegion? _detectedCity;
  int _seats = 4;
  int _minRiders = 1;
  bool _loading = false;
  String? _error;
  int _bookingCutoffMinutes = 60; // hike only — how many minutes before departure to close booking

  List<TwamboPlace> get _places =>
      _tripType == 'hike' ? intercityTwamboPlaces() : placesForCity(_detectedCity?.id ?? 'kitwe');

  String get _cityLabel =>
      _tripType == 'hike' ? 'all cities' : (_detectedCity?.name ?? 'Kitwe');

  @override
  void initState() {
    super.initState();
    _detectDriverCity();
  }

  Future<void> _detectDriverCity() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final city = detectCity(pos.latitude, pos.longitude) ??
          nearestCity(pos.latitude, pos.longitude);
      if (mounted) setState(() => _detectedCity = city);
    } catch (_) {
      // GPS unavailable — fall back to Kitwe
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _departureTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_origin == null || _destination == null) {
      setState(() => _error = 'Choose both origin and destination');
      return;
    }
    if (_departureTime == null) {
      setState(() => _error = 'Select departure time');
      return;
    }
    if (_tripType == 'hike' && _departureTime!.difference(DateTime.now()).inMinutes < 60) {
      setState(() => _error = 'Long distance trips require at least 1 hour notice');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      if (kUseMockData) {
        await Future.delayed(const Duration(milliseconds: 500));
        final user = ref.read(authProvider).user;
        final rf = _tripType == 'hike' ? _routeFare() : null;
        addMockDriverTrip(
          originName: _origin!.name,
          originLat: _origin!.lat,
          originLng: _origin!.lng,
          destinationName: _destination!.name,
          destinationLat: _destination!.lat,
          destinationLng: _destination!.lng,
          departureTime: _departureTime!,
          totalSeats: _seats,
          minimumRiders: _minRiders,
          mode: _mode,
          tripType: _tripType,
          fare: _mode == 'private' ? 80.0 : 20.0,
          routeFare: rf,
          bookingCutoffMinutes: _tripType == 'hike' ? _bookingCutoffMinutes : 0,
          driverId: user?.id ?? 0,
          driverName: user?.fullName ?? 'Driver',
        );
      } else {
        await ApiClient.dio.post(Endpoints.driverTripCreate, data: {
          'origin_name': _origin!.name,
          'origin_lat': double.parse(_origin!.lat.toStringAsFixed(6)),
          'origin_lng': double.parse(_origin!.lng.toStringAsFixed(6)),
          'destination_name': _destination!.name,
          'destination_lat': double.parse(_destination!.lat.toStringAsFixed(6)),
          'destination_lng': double.parse(_destination!.lng.toStringAsFixed(6)),
          'departure_time': _departureTime!.toUtc().toIso8601String(),
          'total_seats': _seats,
          'minimum_riders': _minRiders,
          'mode': _mode,
          'trip_type': _tripType,
          if (_tripType == 'hike') 'booking_cutoff_minutes': _bookingCutoffMinutes,
        });
      }
      ref.invalidate(driverTripsProvider);
      // For hike trips, offer to create the return leg immediately
      if (mounted && _tripType == 'hike') {
        final savedOrigin = _origin;
        final savedDest = _destination;
        final doReturn = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Post return trip?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
            content: Text(
              'Create the return leg: ${savedDest?.name} → ${savedOrigin?.name}?',
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, create return', style: TextStyle(color: Color(0xFFE65100))),
              ),
            ],
          ),
        );
        if (doReturn == true && mounted) {
          setState(() {
            _origin = savedDest;
            _destination = savedOrigin;
            _departureTime = null;
            _loading = false;
            _error = null;
          });
          return;
        }
      }
      if (mounted) context.go('/driver');
    } catch (e) {
      String msg = 'Failed to create trip.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) { msg = data.values.first?.toString() ?? msg; }
        else if (data is String) { msg = data; }
      } catch (_) {}
      setState(() { _loading = false; _error = msg; });
    }
  }

  String _fmtDt(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d  $t';
  }

  // Mirrors the backend FareEngine tiered formula — used for mock route_fare only.
  double _routeFare() {
    if (_origin == null || _destination == null) return 20.0;
    final distKm = haversineKm(_origin!.lat, _origin!.lng, _destination!.lat, _destination!.lng);
    double fare = 0, rem = distKm;
    final local = rem.clamp(0, 5.0);    fare += local * 5.0;  rem -= local;
    final city  = rem.clamp(0, 10.0);   fare += city  * 2.5;  rem -= city;
    final ic    = rem.clamp(0, 35.0);   fare += ic    * 0.8;  rem -= ic;
    fare += rem * 0.6;
    return fare < 15.0 ? 15.0 : fare;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E2E) : TwamboColors.line;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/driver'),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: cardBg, border: Border.all(color: borderColor),
                  ),
                  child: Icon(Icons.arrow_back_ios_new, size: 16, color: textColor),
                ),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('NEW TRIP', style: GoogleFonts.spaceGrotesk(
                    fontSize: 20, fontWeight: FontWeight.w800, color: textColor,
                    letterSpacing: 0.5)),
                Text('Schedule a ride for passengers', style: GoogleFonts.manrope(
                    fontSize: 11, color: TwamboColors.textSecondary)),
              ]),
            ]),
          ),
          const SizedBox(height: 4),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

              // ── Trip Type selector ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(left: BorderSide(
                    color: _tripType == 'hike' ? const Color(0xFFE65100) : TwamboColors.primary,
                    width: 4,
                  )),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TRIP TYPE', style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: _tripType == 'hike' ? const Color(0xFFE65100) : TwamboColors.primary,
                      letterSpacing: 1.5)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _TypeToggle(
                      label: 'City Trip',
                      icon: Icons.location_city_outlined,
                      subtitle: 'Local routes',
                      active: _tripType == 'city',
                      activeColor: TwamboColors.primary,
                      onTap: () => setState(() {
                        _tripType = 'city';
                        _origin = null;
                        _destination = null;
                        if (_mode == 'dynamic') _mode = 'shared';
                      }),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _TypeToggle(
                      label: 'Long Distance',
                      icon: Icons.route_outlined,
                      subtitle: 'Intercity hike',
                      active: _tripType == 'hike',
                      activeColor: const Color(0xFFE65100),
                      onTap: () => setState(() {
                        _tripType = 'hike';
                        _origin = null;
                        _destination = null;
                      }),
                    )),
                  ]),
                  if (_tripType == 'hike') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      color: const Color(0xFFE65100).withValues(alpha: 0.08),
                      child: Row(children: [
                        const Icon(Icons.info_outline, size: 14, color: Color(0xFFE65100)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Origin and destination can be in different cities. '
                          'Riders may pay a pickup detour fee (up to K50).',
                          style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFFE65100)),
                        )),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 12),

              // ── Route card ─────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(left: const BorderSide(color: TwamboColors.primary, width: 4)),
                  boxShadow: isDark ? [] : [BoxShadow(color: TwamboColors.primary.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ROUTE', style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: TwamboColors.primary, letterSpacing: 1.5)),
                  const SizedBox(height: 14),
                  PlacePicker(
                    label: 'ORIGIN',
                    placeholder: _tripType == 'hike'
                        ? 'Departure city / bus station'
                        : 'Where are you starting from?',
                    icon: Icons.trip_origin,
                    selected: _origin,
                    places: _places,
                    cityLabel: _cityLabel,
                    onSelected: (p) => setState(() => _origin = p),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(children: List.generate(3, (_) => Container(
                      width: 2, height: 5, margin: const EdgeInsets.symmetric(vertical: 1),
                      color: TwamboColors.line,
                    ))),
                  ),
                  const SizedBox(height: 4),
                  PlacePicker(
                    label: 'DESTINATION',
                    placeholder: _tripType == 'hike'
                        ? 'Arrival city / final stop'
                        : 'Where are you going?',
                    icon: Icons.flag_outlined,
                    selected: _destination,
                    places: _places,
                    cityLabel: _cityLabel,
                    onSelected: (p) => setState(() => _destination = p),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Route map preview
              if (_origin != null && _destination != null) ...[
                _TripRouteMap(origin: _origin!, destination: _destination!, isDark: isDark),
                const SizedBox(height: 12),
              ],

              // ── Departure time card ────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(left: const BorderSide(color: TwamboColors.secondary, width: 4)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DEPARTURE', style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: TwamboColors.secondary, letterSpacing: 1.5)),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt,
                        border: Border.all(
                          color: _departureTime != null ? TwamboColors.secondary : borderColor,
                          width: _departureTime != null ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.schedule_outlined, size: 18,
                            color: _departureTime != null ? TwamboColors.secondary : TwamboColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          _departureTime == null ? 'Tap to choose date & time' : _fmtDt(_departureTime!),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: _departureTime != null ? FontWeight.w600 : FontWeight.w400,
                            color: _departureTime != null ? textColor : TwamboColors.textSecondary,
                          ),
                        )),
                        Icon(Icons.chevron_right, size: 18,
                            color: _departureTime != null ? TwamboColors.secondary : TwamboColors.textSecondary),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Booking cutoff (hike only) ────────────────────────────────
              if (_tripType == 'hike') ...[
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: const Border(left: BorderSide(color: Color(0xFFE65100), width: 4)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('BOOKING CLOSES', style: GoogleFonts.spaceGrotesk(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: const Color(0xFFE65100), letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text('Stop accepting bookings before departure:',
                        style: GoogleFonts.manrope(fontSize: 11,
                            color: TwamboColors.textSecondary)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (label, mins) in [
                        ('30 min', 30), ('1 hr', 60), ('1.5 hr', 90),
                        ('2 hr', 120), ('3 hr', 180),
                      ])
                        _CutoffChip(
                          label: label, mins: mins,
                          selected: _bookingCutoffMinutes == mins,
                          onTap: () => setState(() => _bookingCutoffMinutes = mins),
                        ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // ── Capacity card ──────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(left: const BorderSide(color: TwamboColors.accent, width: 4)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('CAPACITY', style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: TwamboColors.accent, letterSpacing: 1.5)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _CounterField(
                      label: 'TOTAL SEATS',
                      value: _seats, min: 1, max: 14,
                      onChanged: (v) => setState(() => _seats = v),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _CounterField(
                      label: 'MIN. RIDERS',
                      value: _minRiders, min: 1, max: _seats,
                      onChanged: (v) => setState(() => _minRiders = v),
                    )),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Pricing mode card ──────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(left: const BorderSide(color: TwamboColors.success, width: 4)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PRICING MODE', style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: TwamboColors.success, letterSpacing: 1.5)),
                  const SizedBox(height: 14),
                  if (_tripType == 'hike') ...[
                    // Long distance: shared only
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: TwamboColors.success.withValues(alpha: 0.08),
                        border: const Border(left: BorderSide(color: TwamboColors.success, width: 3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.people_outline, size: 16, color: TwamboColors.success),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('SHARED — FIXED RATE', style: GoogleFonts.spaceGrotesk(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: TwamboColors.success, letterSpacing: 1)),
                          const SizedBox(height: 2),
                          Text('Each city pickup pays the full route fare. Roadside pickups are half price — your call.',
                              style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
                        ])),
                      ]),
                    ),
                  ] else ...[
                    Row(children: [
                      Expanded(child: _ModeToggle(
                        label: 'Shared',
                        icon: Icons.people_outline,
                        subtitle: 'Split with riders',
                        active: _mode == 'shared',
                        onTap: () => setState(() => _mode = 'shared'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _ModeToggle(
                        label: 'Private',
                        icon: Icons.person_outline,
                        subtitle: 'One booking only',
                        active: _mode == 'private',
                        onTap: () => setState(() => _mode = 'private'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _ModeToggle(
                        label: 'Dynamic',
                        icon: Icons.bolt_outlined,
                        subtitle: 'Accept requests',
                        active: _mode == 'dynamic',
                        onTap: () => setState(() => _mode = 'dynamic'),
                      )),
                    ]),
                  ],
                ]),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: TwamboColors.error, width: 3)),
                    color: Color(0x0FD32F2F),
                  ),
                  child: Text(_error!, style: GoogleFonts.manrope(
                      fontSize: 13, color: TwamboColors.error)),
                ),
              ],

              const SizedBox(height: 24),

              GestureDetector(
                onTap: _loading ? null : _submit,
                child: Container(
                  height: 52,
                  color: _tripType == 'hike' ? const Color(0xFFE65100) : TwamboColors.primary,
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : Text(
                          _tripType == 'hike' ? 'CREATE LONG DISTANCE TRIP' : 'CREATE TRIP',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 14, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ── Route map preview ─────────────────────────────────────────────────────────

class _TripRouteMap extends ConsumerWidget {
  final TwamboPlace origin;
  final TwamboPlace destination;
  final bool isDark;
  const _TripRouteMap({required this.origin, required this.destination, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeKey = '${origin.lat},${origin.lng},${destination.lat},${destination.lng}';
    final routeAsync = ref.watch(_createTripRouteProvider(routeKey));

    return ClipRect(
      child: SizedBox(
        height: 200,
        child: Stack(children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.coordinates(
                coordinates: [
                  LatLng(origin.lat, origin.lng),
                  LatLng(destination.lat, destination.lng),
                ],
                padding: const EdgeInsets.fromLTRB(40, 40, 40, 50),
              ),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              if (kShowMapTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.twambo.app',
                )
              else
                const ColoredBox(color: Color(0xFFD8DADB), child: SizedBox.expand()),
              routeAsync.maybeWhen(
                data: (pts) => PolylineLayer(polylines: [
                  Polyline(
                    points: pts,
                    color: TwamboColors.primary,
                    strokeWidth: 4,
                    borderColor: Colors.white,
                    borderStrokeWidth: 1.5,
                  ),
                ]),
                orElse: () => const SizedBox.shrink(),
              ),
              MarkerLayer(markers: [
                Marker(
                  point: LatLng(origin.lat, origin.lng),
                  width: 30, height: 30,
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.primary),
                    child: const Icon(Icons.circle, size: 8, color: Colors.black),
                  ),
                ),
                Marker(
                  point: LatLng(destination.lat, destination.lng),
                  width: 30, height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: TwamboColors.error,
                      boxShadow: [BoxShadow(color: TwamboColors.error.withValues(alpha: 0.4), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.location_on, size: 16, color: Colors.white),
                  ),
                ),
              ]),
            ],
          ),
          Positioned(left: 0, top: 0, bottom: 0,
            child: Container(width: 4, color: TwamboColors.primary)),
          Positioned(
            top: 10, left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.white,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.trip_origin, size: 10, color: TwamboColors.primary),
                const SizedBox(width: 4),
                Text(origin.name.split(',').first,
                    style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700,
                        color: TwamboColors.textPrimary)),
              ]),
            ),
          ),
          Positioned(
            bottom: 10, left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.white,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.flag_outlined, size: 10, color: TwamboColors.error),
                const SizedBox(width: 4),
                Text(destination.name.split(',').first,
                    style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700,
                        color: TwamboColors.textPrimary)),
              ]),
            ),
          ),
          if (routeAsync.isLoading)
            const Positioned(
              right: 10, bottom: 10,
              child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: TwamboColors.primary)),
            ),
        ]),
      ),
    );
  }
}

// ── Trip type toggle ──────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label, required this.subtitle,
    required this.icon, required this.active,
    required this.activeColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: active ? activeColor : (isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt),
          border: Border.all(
            color: active ? activeColor : (isDark ? const Color(0xFF3E3E3E) : TwamboColors.line),
            width: active ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon, size: 22, color: active ? Colors.white : TwamboColors.textSecondary),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: active ? Colors.white : TwamboColors.textSecondary)),
          Text(subtitle, style: GoogleFonts.manrope(
              fontSize: 9, color: active ? Colors.white.withValues(alpha: 0.8) : TwamboColors.textSecondary),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Reusable counter ─────────────────────────────────────────────────────────

class _CounterField extends StatelessWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;

  const _CounterField({
    required this.label, required this.value,
    required this.min, required this.max, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: TwamboColors.textSecondary, letterSpacing: 1.5)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt,
          border: Border.all(color: isDark ? const Color(0xFF3E3E3E) : TwamboColors.line),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: value > min ? () => onChanged(value - 1) : null,
            child: Container(width: 38, height: 42, alignment: Alignment.center,
                child: Icon(Icons.remove, size: 16,
                    color: value > min ? TwamboColors.textSecondary : TwamboColors.line)),
          ),
          Expanded(child: Text('$value', textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : TwamboColors.textPrimary))),
          GestureDetector(
            onTap: value < max ? () => onChanged(value + 1) : null,
            child: Container(width: 38, height: 42, alignment: Alignment.center,
                child: Icon(Icons.add, size: 16,
                    color: value < max ? TwamboColors.primary : TwamboColors.line)),
          ),
        ]),
      ),
    ]);
  }
}

// ── Mode toggle tile ─────────────────────────────────────────────────────────

class _CutoffChip extends StatelessWidget {
  final String label;
  final int mins;
  final bool selected;
  final VoidCallback onTap;
  const _CutoffChip({required this.label, required this.mins, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE65100)
              : (isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt),
          border: Border.all(
            color: selected ? const Color(0xFFE65100) : TwamboColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(label, style: GoogleFonts.spaceGrotesk(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : TwamboColors.textSecondary)),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ModeToggle({
    required this.label, required this.subtitle,
    required this.icon, required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? TwamboColors.primary : (isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt),
          border: Border.all(
            color: active ? TwamboColors.primary : (isDark ? const Color(0xFF3E3E3E) : TwamboColors.line),
            width: active ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon, size: 20, color: active ? TwamboColors.textPrimary : TwamboColors.textSecondary),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: active ? TwamboColors.textPrimary : TwamboColors.textSecondary)),
          Text(subtitle, style: GoogleFonts.manrope(
              fontSize: 8, color: active ? const Color(0xFF3A3A3A) : TwamboColors.textSecondary),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
