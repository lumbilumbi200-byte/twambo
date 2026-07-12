import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/storage.dart';
import '../../core/models/trip.dart';
import '../../shared/theme.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _PickupStop {
  final int bookingId;
  final String riderName;
  final String pickupName;
  final LatLng pickupPos;
  final String dropoffName;
  final bool isPickedUp;

  const _PickupStop({
    required this.bookingId, required this.riderName,
    required this.pickupName, required this.pickupPos,
    required this.dropoffName, required this.isPickedUp,
  });

  factory _PickupStop.fromJson(Map<String, dynamic> j) => _PickupStop(
    bookingId: j['id'],
    riderName: j['rider_name'] ?? '',
    pickupName: j['pickup_name'] ?? '',
    pickupPos: LatLng(
      double.parse(j['pickup_lat'].toString()),
      double.parse(j['pickup_lng'].toString()),
    ),
    dropoffName: j['dropoff_name'] ?? '',
    isPickedUp: j['is_picked_up'] as bool? ?? false,
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DriverGpsScreen extends StatefulWidget {
  final int driverId;
  final int tripId;
  const DriverGpsScreen({super.key, required this.driverId, required this.tripId});

  @override
  State<DriverGpsScreen> createState() => _DriverGpsScreenState();
}

class _DriverGpsScreenState extends State<DriverGpsScreen> {
  final MapController _mapCtrl = MapController();
  WebSocketChannel? _ws;
  StreamSubscription<Position>? _posSub;
  Timer? _clock;
  Timer? _routeTimer;

  LatLng? _currentPos;
  LatLng? _lastRoutePos;
  LatLng? _lastCameraPos;
  bool _broadcasting = false;
  bool _followDriver = true;
  String _status = 'Getting location...';
  Duration _elapsed = Duration.zero;
  int _updateCount = 0;

  Trip? _trip;
  List<_PickupStop> _pickups = [];
  List<LatLng> _routePoints = [];
  static final _tileCache = MemCacheStore();

  static const _wsBaseUrl = '${Endpoints.wsBase}/ws/driver/';
  static const _defaultPos = LatLng(-12.8167, 28.2167);

  @override
  void initState() {
    super.initState();
    _connect();
    _fetchTripData();
  }

  // ── Data fetching ────────────────────────────────────────────────────────────

  Future<void> _fetchTripData() async {
    try {
      final results = await Future.wait([
        ApiClient.dio.get(Endpoints.tripDetail(widget.tripId)),
        ApiClient.dio.get(Endpoints.tripPassengers(widget.tripId)),
      ]);
      if (!mounted) return;
      final trip = Trip.fromJson(results[0].data as Map<String, dynamic>);
      final raw = results[1].data is List
          ? results[1].data as List
          : (results[1].data['results'] as List? ?? []);
      final pickups = raw
          .map((j) => _PickupStop.fromJson(j as Map<String, dynamic>))
          .toList();
      setState(() {
        _trip = trip;
        _pickups = pickups;
      });
      await _refreshRoute();
      // Refresh every 60s to reflect pick-up status changes
      _routeTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
        await _fetchPassengers();
        await _refreshRoute();
      });
    } catch (_) {}
  }

  Future<void> _fetchPassengers() async {
    try {
      final resp = await ApiClient.dio.get(Endpoints.tripPassengers(widget.tripId));
      if (!mounted) return;
      final raw = resp.data is List
          ? resp.data as List
          : (resp.data['results'] as List? ?? []);
      setState(() {
        _pickups = raw.map((j) => _PickupStop.fromJson(j as Map<String, dynamic>)).toList();
      });
    } catch (_) {}
  }

  Future<void> _refreshRoute() async {
    if (_trip == null) return;
    final origin = _currentPos ?? LatLng(_trip!.originLat, _trip!.originLng);
    final dest = LatLng(_trip!.destinationLat, _trip!.destinationLng);

    final pending = _pickups.where((p) => !p.isPickedUp).toList();
    final waypoints = [origin, ...pending.map((p) => p.pickupPos), dest];

    final route = await _fetchOsrmRoute(waypoints);
    if (mounted) setState(() => _routePoints = route);
    _lastRoutePos = origin;
  }

  Future<List<LatLng>> _fetchOsrmRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return waypoints;
    try {
      final coords = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
      final resp = await ApiClient.dio.get(
        'https://router.project-osrm.org/route/v1/driving/$coords',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      final routes = resp.data['routes'] as List?;
      if (routes == null || routes.isEmpty) return waypoints;
      final coordList = (routes[0]['geometry']['coordinates'] as List);
      return coordList
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (_) {
      return waypoints;
    }
  }

  // ── GPS + WebSocket ──────────────────────────────────────────────────────────

  Future<void> _connect() async {
    if (!await _ensurePermission()) {
      setState(() => _status = 'Location permission denied');
      return;
    }
    try {
      final token = await AppStorage.getAccessToken() ?? '';
      _ws = WebSocketChannel.connect(
          Uri.parse('$_wsBaseUrl${widget.driverId}/?token=$token'));
      setState(() { _broadcasting = true; _status = 'Live'; });
      _startClock();
      _startSending();
    } catch (_) {
      setState(() => _status = 'Connection failed');
    }
  }

  Future<bool> _ensurePermission() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  }

  void _startSending() {
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      final ll = LatLng(pos.latitude, pos.longitude);
      _ws?.sink.add(jsonEncode({'lat': pos.latitude, 'lng': pos.longitude, 'ts': pos.timestamp.toIso8601String()}));
      if (mounted) {
        setState(() { _currentPos = ll; _updateCount++; });
        // Throttle camera: only move if driver went >40m from last camera position
        if (_followDriver) {
          if (_lastCameraPos == null) {
            _mapCtrl.move(ll, 16);
            _lastCameraPos = ll;
          } else {
            final camDist = const Distance().as(LengthUnit.Meter, ll, _lastCameraPos!);
            if (camDist > 40) { _mapCtrl.move(ll, 16); _lastCameraPos = ll; }
          }
        }
        // Refresh route if driver moved >200m from last route fetch
        if (_lastRoutePos != null) {
          final dist = const Distance().as(LengthUnit.Meter, ll, _lastRoutePos!);
          if (dist > 200) _refreshRoute();
        }
      }
    });
  }

  void _startClock() {
    _clock = Timer.periodic(const Duration(seconds: 1),
        (_) { if (mounted) setState(() => _elapsed += const Duration(seconds: 1)); });
  }

  String get _elapsedStr {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ws?.sink.close();
    _clock?.cancel();
    _routeTimer?.cancel();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pos = _currentPos ?? _defaultPos;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingPickups = _pickups.where((p) => !p.isPickedUp).toList();
    final donePickups = _pickups.where((p) => p.isPickedUp).toList();

    return Scaffold(
      body: Stack(children: [
        // ── Map ──────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: pos,
            initialZoom: 15,
            onPositionChanged: (_, hasGesture) {
              if (hasGesture && _followDriver) setState(() => _followDriver = false);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.twambo.app',
              tileProvider: CachedTileProvider(store: _tileCache),
            ),

            // Route polyline
            if (_routePoints.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                  points: _routePoints,
                  color: TwamboColors.primary,
                  strokeWidth: 4,
                ),
              ]),

            // Markers
            MarkerLayer(markers: [
              // Destination marker
              if (_trip != null)
                Marker(
                  point: LatLng(_trip!.destinationLat, _trip!.destinationLng),
                  width: 40, height: 40,
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.error),
                    child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                  ),
                ),

              // Pending pickup markers (numbered)
              ...pendingPickups.asMap().entries.map((e) => Marker(
                point: e.value.pickupPos,
                width: 36, height: 36,
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.success),
                  child: Center(child: Text(
                    '${e.key + 1}',
                    style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  )),
                ),
              )),

              // Done pickup markers (greyed)
              ...donePickups.map((p) => Marker(
                point: p.pickupPos,
                width: 28, height: 28,
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: TwamboColors.textSecondary.withValues(alpha: 0.6)),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              )),

              // Driver car marker
              if (_currentPos != null)
                Marker(
                  point: _currentPos!,
                  width: 48, height: 48,
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.primary),
                    child: const Icon(Icons.directions_car, color: TwamboColors.textPrimary, size: 26),
                  ),
                ),
            ]),
          ],
        ),

        // ── Top bar ──────────────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.canPop() ? context.pop() : context.go('/driver'),
                  child: Container(
                    width: 40, height: 40,
                    color: Colors.white.withValues(alpha: 0.95),
                    child: const Icon(Icons.arrow_back, size: 20, color: TwamboColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF1A1A1A) : Colors.white).withValues(alpha: 0.95),
                      border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
                    ),
                    child: Row(children: [
                      Container(width: 10, height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: _broadcasting ? TwamboColors.success : TwamboColors.error)),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_broadcasting ? 'BROADCASTING GPS' : _status.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
                            color: _broadcasting ? TwamboColors.success : TwamboColors.error, letterSpacing: 1.5)),
                        if (_broadcasting)
                          Text(_elapsedStr,
                            style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : TwamboColors.textPrimary)),
                      ])),
                      Text('${_pickups.where((p) => p.isPickedUp).length}/${_pickups.length} picked up',
                        style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Re-center button ─────────────────────────────────────────────────
        if (!_followDriver && _currentPos != null)
          Positioned(
            right: 16, bottom: _pickups.isEmpty ? 120 : 220,
            child: GestureDetector(
              onTap: () {
                setState(() => _followDriver = true);
                _mapCtrl.move(_currentPos!, 16);
              },
              child: Container(
                width: 44, height: 44,
                color: TwamboColors.primary,
                child: const Icon(Icons.my_location, color: TwamboColors.textPrimary, size: 22),
              ),
            ),
          ),

        // ── Bottom panel ─────────────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Stats row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  _StatBox(label: 'UPDATES', value: '$_updateCount', color: TwamboColors.success),
                  const SizedBox(width: 8),
                  _StatBox(label: 'STOPS LEFT', value: '${pendingPickups.length}', color: TwamboColors.accent),
                  const SizedBox(width: 8),
                  _StatBox(label: 'DURATION', value: _elapsedStr, color: TwamboColors.secondary),
                ]),
              ),

              if (_pickups.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(children: [
                    Text('PICKUP STOPS', style: GoogleFonts.spaceGrotesk(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: TwamboColors.textSecondary, letterSpacing: 1.5)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _fetchPassengers,
                      child: const Icon(Icons.refresh, size: 14, color: TwamboColors.textSecondary),
                    ),
                  ]),
                ),
                // Scrollable stop list
                SizedBox(
                  height: 130,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _pickups.length,
                    itemBuilder: (_, i) {
                      final stop = _pickups[i];
                      final num = pendingPickups.indexOf(stop);
                      return _StopRow(
                        stop: stop,
                        number: stop.isPickedUp ? null : (num + 1),
                        isDark: isDark,
                      );
                    },
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('No confirmed bookings yet',
                    style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
                ),
              ],
            ]),
          ),
        ),

        // ── Acquiring spinner ─────────────────────────────────────────────────
        if (_currentPos == null && _broadcasting)
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: Colors.white.withValues(alpha: 0.9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: TwamboColors.primary, strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('Acquiring GPS signal…',
                style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textPrimary)),
            ]),
          )),
      ]),
    );
  }
}

// ── Stop row widget ───────────────────────────────────────────────────────────

class _StopRow extends StatelessWidget {
  final _PickupStop stop;
  final int? number;
  final bool isDark;
  const _StopRow({required this.stop, required this.number, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final done = stop.isPickedUp;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? TwamboColors.textSecondary.withValues(alpha: 0.3)
                : TwamboColors.success,
          ),
          child: Center(child: done
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : Text('$number', style: GoogleFonts.spaceGrotesk(
                  fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(stop.riderName,
            style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700,
              color: done
                  ? TwamboColors.textSecondary
                  : (isDark ? Colors.white : TwamboColors.textPrimary))),
          Text(stop.pickupName,
            style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (done)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: TwamboColors.success.withValues(alpha: 0.12),
            child: Text('ON BOARD', style: GoogleFonts.spaceGrotesk(
                fontSize: 7, fontWeight: FontWeight.w800, color: TwamboColors.success, letterSpacing: 1)),
          ),
      ]),
    );
  }
}

// ── Stat box ──────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: isDark ? const Color(0xFF242424) : TwamboColors.bg,
      child: Column(children: [
        Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.manrope(fontSize: 8, color: TwamboColors.textSecondary, letterSpacing: 1.2)),
      ]),
    ));
  }
}
