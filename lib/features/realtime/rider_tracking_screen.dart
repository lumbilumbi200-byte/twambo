import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/models/trip.dart';
import '../../shared/theme.dart';

final _trackingTripProvider = FutureProvider.family<Trip, int>((ref, tripId) async {
  final resp = await ApiClient.dio.get(Endpoints.tripDetail(tripId));
  return Trip.fromJson(resp.data);
});

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

  LatLng? _driverPos;
  bool _connected = false;
  int _reconnectAttempts = 0;

  static const _wsBaseUrl = 'ws://127.0.0.1:8000/ws/driver/';
  static const _defaultPos = LatLng(-12.8167, 28.2167);

  LatLng get _pickupPos {
    if (widget.pickupLat == 0 && widget.pickupLng == 0) return _defaultPos;
    return LatLng(widget.pickupLat, widget.pickupLng);
  }

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    if (widget.driverId <= 0) { return; }
    try {
      _ws = WebSocketChannel.connect(Uri.parse('$_wsBaseUrl${widget.driverId}/'));
      _wsSub = _ws!.stream.listen(
        (msg) {
          final data = jsonDecode(msg as String) as Map<String, dynamic>;
          final pos = LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());
          if (mounted) {
            setState(() { _driverPos = pos; _connected = true; _reconnectAttempts = 0; });
            _mapCtrl.move(pos, 15);
          }
        },
        onDone: () {
          if (mounted) {
            setState(() => _connected = false);
            _scheduleReconnect();
          }
        },
        onError: (_) {
          if (mounted) {
            setState(() => _connected = false);
            _scheduleReconnect();
          }
        },
      );
      setState(() => _connected = true);
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= 5) { return; }
    _reconnectAttempts++;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) { _connect(); }
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    super.dispose();
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(_trackingTripProvider(widget.tripId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final center = _driverPos ?? _pickupPos;

    return Scaffold(
      body: Stack(children: [
        // ── Map ──────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(initialCenter: center, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.twambo.app',
            ),
            MarkerLayer(markers: [
              // Pickup marker
              Marker(
                point: _pickupPos,
                width: 40, height: 40,
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.success),
                  child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 24),
                ),
              ),
              // Driver car marker
              if (_driverPos != null)
                Marker(
                  point: _driverPos!,
                  width: 44, height: 44,
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.primary),
                    child: const Icon(Icons.directions_car, color: TwamboColors.textPrimary, size: 24),
                  ),
                ),
            ]),
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
                      color: isDark ? const Color(0xFF1A1A1A).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                      border: const Border(left: BorderSide(color: TwamboColors.secondary, width: 4)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _connected ? TwamboColors.success : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.driverName,
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 12, fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : TwamboColors.textPrimary)),
                        Text(
                          _connected
                              ? (_driverPos == null ? 'Waiting for driver location…' : 'Driver is on the way')
                              : 'Reconnecting…',
                          style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary),
                        ),
                      ])),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Bottom info card ────────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              border: const Border(left: BorderSide(color: TwamboColors.secondary, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
            child: tripAsync.when(
              loading: () => const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator(color: TwamboColors.primary, strokeWidth: 2)),
              ),
              error: (_, __) => _PickupRow(originName: widget.originName, isDark: isDark),
              data: (trip) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Status badge + trip info
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    color: trip.isActive
                        ? TwamboColors.success.withValues(alpha: 0.12)
                        : TwamboColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      trip.isActive ? 'TRIP IN PROGRESS' : 'DEPARTING ${_fmtTime(trip.departureTime)}',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1.5,
                          color: trip.isActive ? TwamboColors.success : TwamboColors.textPrimary),
                    ),
                  ),
                  const Spacer(),
                  Text('K${trip.currentSharedFare.toStringAsFixed(0)} cash',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 16, fontWeight: FontWeight.w800, color: TwamboColors.primary)),
                ]),
                const SizedBox(height: 10),
                // Route
                Row(children: [
                  const Icon(Icons.circle, size: 8, color: TwamboColors.primary),
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
                // Pickup
                Container(
                  padding: const EdgeInsets.all(10),
                  color: TwamboColors.success.withValues(alpha: 0.07),
                  child: Row(children: [
                    const Icon(Icons.person_pin_circle, size: 16, color: TwamboColors.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Your pickup: ${widget.originName}',
                        style: GoogleFonts.manrope(fontSize: 12,
                            fontWeight: FontWeight.w600, color: TwamboColors.success),
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
