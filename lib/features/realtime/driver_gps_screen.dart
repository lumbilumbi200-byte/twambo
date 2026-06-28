import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api/endpoints.dart';
import '../../core/storage.dart';
import '../../shared/theme.dart';

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

  LatLng? _currentPos;
  bool _broadcasting = false;
  String _status = 'Getting location...';
  Duration _elapsed = Duration.zero;
  Timer? _clock;
  int _updateCount = 0;

  static const _wsBaseUrl = '${Endpoints.wsBase}/ws/driver/';
  static const _defaultPos = LatLng(-12.8167, 28.2167);

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final permission = await _ensurePermission();
    if (!permission) {
      setState(() => _status = 'Location permission denied');
      return;
    }
    try {
      final token = await AppStorage.getAccessToken() ?? '';
      _ws = WebSocketChannel.connect(
        Uri.parse('$_wsBaseUrl${widget.driverId}/?token=$token'),
      );
      setState(() { _broadcasting = true; _status = 'Live'; });
      _startClock();
      _startSending();
    } catch (e) {
      setState(() => _status = 'Connection failed');
    }
  }

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse || perm == LocationPermission.always;
  }

  void _startSending() {
    const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      final payload = jsonEncode({'lat': pos.latitude, 'lng': pos.longitude, 'ts': pos.timestamp.toIso8601String()});
      _ws?.sink.add(payload);
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() { _currentPos = latLng; _updateCount++; });
        _mapCtrl.move(latLng, 16);
      }
    });
  }

  void _startClock() {
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = _elapsed + const Duration(seconds: 1));
    });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = _currentPos ?? _defaultPos;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(children: [
        // ── Map ────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(initialCenter: pos, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.twambo.app',
            ),
            if (_currentPos != null)
              MarkerLayer(markers: [
                Marker(
                  point: _currentPos!,
                  width: 44, height: 44,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: TwamboColors.primary,
                    ),
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
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                      border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _broadcasting ? TwamboColors.success : TwamboColors.error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          _broadcasting ? 'BROADCASTING GPS' : _status.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              color: _broadcasting ? TwamboColors.success : TwamboColors.error,
                              letterSpacing: 1.5),
                        ),
                        if (_broadcasting)
                          Text(_elapsedStr,
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13, fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : TwamboColors.textPrimary)),
                      ])),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Bottom status card ──────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Row(children: [
              _StatBox(
                label: 'UPDATES',
                value: '$_updateCount',
                color: TwamboColors.success,
              ),
              const SizedBox(width: 12),
              _StatBox(
                label: 'STATUS',
                value: _broadcasting ? 'LIVE' : 'OFFLINE',
                color: _broadcasting ? TwamboColors.success : TwamboColors.error,
              ),
              const SizedBox(width: 12),
              _StatBox(
                label: 'DURATION',
                value: _elapsedStr,
                color: TwamboColors.secondary,
              ),
            ]),
          ),
        ),

        // ── Location acquiring spinner ────────────────────────────────────
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

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: isDark ? const Color(0xFF242424) : TwamboColors.bg,
      child: Column(children: [
        Text(value, style: GoogleFonts.spaceGrotesk(
            fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.manrope(
            fontSize: 8, color: TwamboColors.textSecondary, letterSpacing: 1.2)),
      ]),
    ));
  }
}
