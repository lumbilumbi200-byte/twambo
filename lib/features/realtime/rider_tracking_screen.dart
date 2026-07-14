import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/storage.dart';
import '../../core/models/trip.dart';
import '../../shared/theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _trackingTripProvider = FutureProvider.family<Trip, int>((ref, tripId) async {
  final resp = await ApiClient.dio.get(Endpoints.tripDetail(tripId));
  return Trip.fromJson(resp.data);
});

// ── Data ──────────────────────────────────────────────────────────────────────

class _PassengerStop {
  final int bookingId;
  final String pickupName;
  final LatLng pickupPos;
  final String dropoffName;
  final LatLng? dropoffPos;
  final bool isPickedUp;

  const _PassengerStop({
    required this.bookingId, required this.pickupName,
    required this.pickupPos, required this.dropoffName,
    this.dropoffPos, required this.isPickedUp,
  });

  factory _PassengerStop.fromJson(Map<String, dynamic> j) {
    final dLat = double.tryParse(j['dropoff_lat']?.toString() ?? '');
    final dLng = double.tryParse(j['dropoff_lng']?.toString() ?? '');
    return _PassengerStop(
      bookingId: j['id'],
      pickupName: j['pickup_name'] ?? '',
      pickupPos: LatLng(
        double.parse(j['pickup_lat'].toString()),
        double.parse(j['pickup_lng'].toString()),
      ),
      dropoffName: j['dropoff_name'] ?? '',
      dropoffPos: (dLat != null && dLng != null) ? LatLng(dLat, dLng) : null,
      isPickedUp: j['is_picked_up'] as bool? ?? false,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class RiderTrackingScreen extends ConsumerStatefulWidget {
  final int tripId;
  final int driverId;
  final String driverName;
  final String originName;
  final double pickupLat;
  final double pickupLng;

  const RiderTrackingScreen({
    super.key,
    required this.tripId,
    required this.driverId,
    required this.driverName,
    required this.originName,
    required this.pickupLat,
    required this.pickupLng,
  });

  @override
  ConsumerState<RiderTrackingScreen> createState() => _RiderTrackingScreenState();
}

class _RiderTrackingScreenState extends ConsumerState<RiderTrackingScreen> {
  final MapController _mapCtrl = MapController();
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Timer? _routeTimer;

  // Position updates via ValueNotifier so only the map layer rebuilds
  final _driverPosNotifier = ValueNotifier<LatLng?>(null);
  LatLng? _lastCameraPos;
  LatLng? _lastRoutePos;

  bool _connected = false;
  int _reconnectAttempts = 0;
  bool _mapFitted = false;

  String? _emergencyPhone;
  String? _emergencyName;

  List<_PassengerStop> _passengers = [];
  List<LatLng> _routePoints = [];
  static final _tileCache = MemCacheStore();

  static const _wsBaseUrl = '${Endpoints.wsBase}/ws/driver/';
  static const _defaultPos = LatLng(-12.8167, 28.2167);

  LatLng get _pickupPos {
    if (widget.pickupLat == 0 && widget.pickupLng == 0) return _defaultPos;
    return LatLng(widget.pickupLat, widget.pickupLng);
  }

  @override
  void initState() {
    super.initState();
    _connect();
    _loadEmergencyContact();
    _fetchPassengers();
    // Refresh passenger list every 30s (pick-up status changes)
    _routeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchPassengers());
  }

  // ── Data fetching ────────────────────────────────────────────────────────────

  Future<void> _fetchPassengers() async {
    try {
      final results = await Future.wait([
        ApiClient.dio.get(Endpoints.tripPassengers(widget.tripId)),
        if (_routePoints.isEmpty)
          ApiClient.dio.get(Endpoints.tripDetail(widget.tripId)),
      ]);
      if (!mounted) return;
      final raw = results[0].data is List
          ? results[0].data as List
          : (results[0].data['results'] as List? ?? []);
      final passengers = raw.map((j) => _PassengerStop.fromJson(j as Map<String, dynamic>)).toList();
      if (mounted) setState(() => _passengers = passengers);

      if (results.length > 1) {
        final trip = Trip.fromJson(results[1].data as Map<String, dynamic>);
        await _refreshRoute(trip: trip, passengers: passengers);
      } else {
        final trip = ref.read(_trackingTripProvider(widget.tripId)).asData?.value;
        if (trip != null) await _refreshRoute(trip: trip, passengers: passengers);
      }
    } catch (_) {}
  }

  Future<void> _refreshRoute({Trip? trip, List<_PassengerStop>? passengers}) async {
    final t = trip ?? ref.read(_trackingTripProvider(widget.tripId)).asData?.value;
    if (t == null) return;
    final stops = passengers ?? _passengers;

    final driverPos = _driverPosNotifier.value;
    final origin = driverPos ?? LatLng(t.originLat, t.originLng);
    final dest = LatLng(t.destinationLat, t.destinationLng);

    // Route: driver → all pending stops → destination
    final pending = stops.where((p) => !p.isPickedUp).toList();
    final waypoints = [origin, ...pending.map((p) => p.pickupPos), dest];

    final route = await _fetchOsrmRoute(waypoints);
    if (mounted) {
      setState(() => _routePoints = route);
      if (!_mapFitted) {
        _fitMapToBounds(waypoints);
        _mapFitted = true;
      }
    }
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
      final coordList = routes[0]['geometry']['coordinates'] as List;
      return coordList
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (_) {
      return waypoints;
    }
  }

  void _fitMapToBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints(points);
      _mapCtrl.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } catch (_) {}
  }

  // ── Safety ────────────────────────────────────────────────────────────────────

  Future<void> _loadEmergencyContact() async {
    try {
      final resp = await ApiClient.dio.get(Endpoints.riderProfile);
      if (mounted) {
        setState(() {
          _emergencyPhone = resp.data['emergency_contact_phone'] as String?;
          _emergencyName  = resp.data['emergency_contact_name']  as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _callSOS() async {
    final phone = (_emergencyPhone?.isNotEmpty == true) ? _emergencyPhone! : '999';
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _shareTrip(Trip trip) async {
    final name    = _emergencyName?.isNotEmpty == true ? _emergencyName! : 'someone';
    final contact = _emergencyPhone?.isNotEmpty == true ? _emergencyPhone! : null;
    final msg = 'Hi $name, I\'m in a Twambo ride.\n'
        'Driver: ${trip.driverName} (${trip.vehicleMakeModel})\n'
        '${trip.originName} → ${trip.destinationName}\n'
        'Please check on me if I\'m late. — via TWMB app';
    final encoded = Uri.encodeComponent(msg);
    final waUri = contact != null
        ? Uri.parse('https://wa.me/$contact?text=$encoded')
        : Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(waUri)) launchUrl(waUri, mode: LaunchMode.externalApplication);
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────────

  Future<void> _connect() async {
    if (widget.driverId <= 0) return;
    try {
      final token = await AppStorage.getAccessToken() ?? '';
      _ws = WebSocketChannel.connect(Uri.parse('$_wsBaseUrl${widget.driverId}/?token=$token'));
      _wsSub = _ws!.stream.listen(
        (msg) {
          final data = jsonDecode(msg as String) as Map<String, dynamic>;
          final pos = LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());
          _driverPosNotifier.value = pos;
          if (mounted) setState(() { _connected = true; _reconnectAttempts = 0; });

          // Throttle camera — only move if driver went >40m from last camera pos
          if (_lastCameraPos == null) {
            _mapCtrl.move(pos, 15);
            _lastCameraPos = pos;
          } else {
            final dist = const Distance().as(LengthUnit.Meter, pos, _lastCameraPos!);
            if (dist > 40) {
              _mapCtrl.move(pos, 15);
              _lastCameraPos = pos;
            }
          }

          // Refresh route if driver moved >200m from last route fetch
          if (_lastRoutePos != null) {
            final dist = const Distance().as(LengthUnit.Meter, pos, _lastRoutePos!);
            if (dist > 200) _refreshRoute();
          }
        },
        onDone: () { if (mounted) { setState(() => _connected = false); _scheduleReconnect(); } },
        onError: (_) { if (mounted) { setState(() => _connected = false); _scheduleReconnect(); } },
      );
      if (mounted) setState(() => _connected = true);
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= 5) return;
    _reconnectAttempts++;
    _reconnectTimer = Timer(const Duration(seconds: 5), () { if (mounted) _connect(); });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _routeTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    _driverPosNotifier.dispose();
    super.dispose();
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(_trackingTripProvider(widget.tripId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find my stop sequence position
    final pending = _passengers.where((p) => !p.isPickedUp).toList();
    final myStopIndex = pending.indexWhere((p) {
      final d = const Distance().as(LengthUnit.Meter, p.pickupPos, _pickupPos);
      return d < 80;
    });
    final stopsBeforeMe = myStopIndex == -1 ? 0 : myStopIndex;

    return Scaffold(
      body: Stack(children: [
        // ── Map ────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(initialCenter: _pickupPos, initialZoom: 14),
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
                  color: TwamboColors.secondary,
                  strokeWidth: 4,
                ),
              ]),

            // Markers
            ValueListenableBuilder<LatLng?>(
              valueListenable: _driverPosNotifier,
              builder: (_, driverPos, __) => MarkerLayer(markers: [
                // Destination
                ...tripAsync.asData != null ? [
                  Marker(
                    point: LatLng(tripAsync.asData!.value.destinationLat, tripAsync.asData!.value.destinationLng),
                    width: 40, height: 40,
                    child: Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.error),
                      child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ] : [],

                // Other passengers' pickup markers (blue numbered)
                ..._passengers.where((p) {
                  final d = const Distance().as(LengthUnit.Meter, p.pickupPos, _pickupPos);
                  return d > 80; // not my stop
                }).toList().asMap().entries.map((e) {
                  final stop = e.value;
                  final num = pending.indexOf(stop);
                  return Marker(
                    point: stop.pickupPos,
                    width: 32, height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: stop.isPickedUp
                            ? TwamboColors.textSecondary.withValues(alpha: 0.4)
                            : TwamboColors.secondary.withValues(alpha: 0.85),
                      ),
                      child: Center(child: stop.isPickedUp
                          ? const Icon(Icons.check, color: Colors.white, size: 13)
                          : Text('${num + 1}', style: GoogleFonts.spaceGrotesk(
                              fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
                    ),
                  );
                }),

                // Other passengers' drop-off markers (orange flag — only when picked up or hike trip)
                ..._passengers.expand((p) {
                  final pos = p.dropoffPos;
                  if (pos == null) return <Marker>[];
                  // Only show drop-off if it differs meaningfully from the trip destination
                  if (tripAsync.asData != null) {
                    final dest = LatLng(tripAsync.asData!.value.destinationLat,
                        tripAsync.asData!.value.destinationLng);
                    final d = const Distance().as(LengthUnit.Meter, pos, dest);
                    if (d < 200) return <Marker>[]; // same as destination — no extra marker
                  }
                  return [
                    Marker(
                      point: pos,
                      width: 28, height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE65100).withValues(alpha: 0.85),
                        ),
                        child: const Icon(Icons.flag, color: Colors.white, size: 14),
                      ),
                    ),
                  ];
                }),

                // My pickup (green, larger)
                Marker(
                  point: _pickupPos,
                  width: 44, height: 44,
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.success),
                    child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 26),
                  ),
                ),

                // Driver car
                if (driverPos != null)
                  Marker(
                    point: driverPos,
                    width: 48, height: 48,
                    child: Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.primary),
                      child: const Icon(Icons.directions_car, color: TwamboColors.textPrimary, size: 26),
                    ),
                  ),
              ]),
            ),
          ],
        ),

        // ── Top bar ────────────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.canPop() ? context.pop() : context.go('/bookings'),
                  child: Container(
                    width: 40, height: 40,
                    color: Colors.white.withValues(alpha: 0.95),
                    child: const Icon(Icons.arrow_back, size: 20, color: TwamboColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF1A1A1A) : Colors.white).withValues(alpha: 0.95),
                      border: const Border(left: BorderSide(color: TwamboColors.secondary, width: 4)),
                    ),
                    child: Row(children: [
                      Container(width: 10, height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: _connected ? TwamboColors.success : Colors.grey)),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.driverName,
                          style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : TwamboColors.textPrimary)),
                        ValueListenableBuilder<LatLng?>(
                          valueListenable: _driverPosNotifier,
                          builder: (_, pos, __) => Text(
                            _connected
                                ? (pos == null ? 'Waiting for driver location…' : 'Driver is on the way')
                                : 'Reconnecting…',
                            style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary),
                          ),
                        ),
                      ])),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Safety buttons ─────────────────────────────────────────────────
        Positioned(
          right: 16, top: 110,
          child: SafeArea(child: Column(children: [
            _SafetyBtn(icon: Icons.sos_rounded, label: 'SOS',
              color: TwamboColors.error, textColor: Colors.white, onTap: _callSOS),
            const SizedBox(height: 8),
            _SafetyBtn(icon: Icons.share_rounded, label: 'Share',
              color: TwamboColors.primary, textColor: TwamboColors.textPrimary,
              onTap: () {
                final trip = ref.read(_trackingTripProvider(widget.tripId)).asData?.value;
                if (trip != null) _shareTrip(trip);
              }),
          ])),
        ),

        // ── Fit all button ─────────────────────────────────────────────────
        Positioned(
          right: 16, bottom: 260,
          child: GestureDetector(
            onTap: () {
              final driverPos = _driverPosNotifier.value;
              final all = <LatLng>[
                if (driverPos != null) driverPos,
                _pickupPos,
                if (tripAsync.asData != null)
                  LatLng(tripAsync.asData!.value.destinationLat, tripAsync.asData!.value.destinationLng),
              ];
              if (all.isNotEmpty) _fitMapToBounds(all);
            },
            child: Container(
              width: 44, height: 44,
              color: TwamboColors.secondary,
              child: const Icon(Icons.fit_screen, color: Colors.white, size: 22),
            ),
          ),
        ),

        // ── Bottom panel ───────────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              border: const Border(left: BorderSide(color: TwamboColors.secondary, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
            child: tripAsync.when(
              loading: () => const SizedBox(height: 48,
                child: Center(child: CircularProgressIndicator(color: TwamboColors.secondary, strokeWidth: 2))),
              error: (_, __) => _PickupRow(originName: widget.originName, isDark: isDark),
              data: (trip) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                // Status + fare row
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    color: trip.isActive
                        ? TwamboColors.success.withValues(alpha: 0.12)
                        : TwamboColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      trip.isActive ? 'TRIP IN PROGRESS' : 'DEPARTING ${_fmtTime(trip.departureTime)}',
                      style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: trip.isActive ? TwamboColors.success : TwamboColors.textPrimary),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    trip.isPrivate
                        ? 'K${trip.privateFare.toStringAsFixed(0)}'
                        : 'K${trip.currentSharedFare.toStringAsFixed(0)}',
                    style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w800,
                      color: TwamboColors.secondary),
                  ),
                  const SizedBox(width: 4),
                  Text('cash', style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
                ]),
                const SizedBox(height: 10),

                // Route line
                Row(children: [
                  const Icon(Icons.circle, size: 8, color: TwamboColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(trip.originName,
                    style: GoogleFonts.manrope(fontSize: 12,
                      color: isDark ? Colors.white70 : TwamboColors.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Container(width: 2, height: 12, color: TwamboColors.line),
                ),
                Row(children: [
                  const Icon(Icons.location_on, size: 12, color: TwamboColors.error),
                  const SizedBox(width: 6),
                  Expanded(child: Text(trip.destinationName,
                    style: GoogleFonts.manrope(fontSize: 12,
                      color: isDark ? Colors.white70 : TwamboColors.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 10),

                // Stop sequence badge
                if (_passengers.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      color: TwamboColors.accent.withValues(alpha: 0.10),
                      child: Row(children: [
                        const Icon(Icons.route, size: 14, color: TwamboColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          stopsBeforeMe == 0
                              ? 'Driver is heading to your pickup next'
                              : '$stopsBeforeMe stop${stopsBeforeMe > 1 ? 's' : ''} before yours',
                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600,
                            color: TwamboColors.accent),
                        ),
                      ]),
                    ),
                  ),

                // My pickup
                Container(
                  padding: const EdgeInsets.all(10),
                  color: TwamboColors.success.withValues(alpha: 0.07),
                  child: Row(children: [
                    const Icon(Icons.person_pin_circle, size: 16, color: TwamboColors.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Your pickup: ${widget.originName}',
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600,
                        color: TwamboColors.success),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SafetyBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  const _SafetyBtn({required this.icon, required this.label,
    required this.color, required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52, color: color,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 8, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 1)),
        ]),
      ),
    );
  }
}

class _PickupRow extends StatelessWidget {
  final String originName;
  final bool isDark;
  const _PickupRow({required this.originName, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.person_pin_circle, size: 16, color: TwamboColors.success),
      const SizedBox(width: 8),
      Expanded(child: Text('Your pickup: $originName',
          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : TwamboColors.textPrimary))),
    ]);
  }
}
