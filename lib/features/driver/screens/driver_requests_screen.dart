import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../dev/kitwe_places.dart';
import '../../../dev/mock_trips.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../shared/driver_nav_bar.dart';
import '../../../shared/theme.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class BroadcastRequest {
  final int id;
  final String riderInitials;
  final String originName;
  final double originLat;
  final double originLng;
  final String destinationName;
  final double fareEstimate;
  final String mode;
  final int createdMinsAgo;

  const BroadcastRequest({
    required this.id,
    required this.riderInitials,
    required this.originName,
    required this.originLat,
    required this.originLng,
    required this.destinationName,
    required this.fareEstimate,
    required this.mode,
    required this.createdMinsAgo,
  });

  factory BroadcastRequest.fromJson(Map<String, dynamic> j) => BroadcastRequest(
        id: j['id'] as int,
        riderInitials: j['rider_initials'] as String? ?? '?',
        originName: j['origin_name'] as String? ?? '',
        originLat: double.tryParse((j['origin_lat'] ?? '0').toString()) ?? 0,
        originLng: double.tryParse((j['origin_lng'] ?? '0').toString()) ?? 0,
        destinationName: j['destination_name'] as String? ?? '',
        fareEstimate: double.tryParse((j['fare_estimate'] ?? '0').toString()) ?? 0,
        mode: j['mode'] as String? ?? 'dynamic',
        createdMinsAgo: j['created_mins_ago'] as int? ?? 0,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final broadcastRequestsProvider = FutureProvider.autoDispose<List<BroadcastRequest>>((ref) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 250));
    return mockBroadcastRequests
        .map((j) => BroadcastRequest.fromJson(j))
        .toList();
  }
  try {
    final resp = await ApiClient.dio.get(Endpoints.driverBroadcastRequests);
    final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
    return raw.map<BroadcastRequest>((j) => BroadcastRequest.fromJson(j as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

// ── Screen ────────────────────────────────────────────────────────────────────

class DriverRequestsScreen extends ConsumerWidget {
  const DriverRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final requestsAsync = ref.watch(broadcastRequestsProvider);
    final badgeCount = kUseMockData ? mockBroadcastRequests.length : 0;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: DriverNavBar(currentIndex: 1, requestsBadge: badgeCount),
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              border: Border(bottom: BorderSide(
                color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.line)),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('RIDE REQUESTS', style: GoogleFonts.spaceGrotesk(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: TwamboColors.textSecondary, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('Broadcast requests from riders', style: GoogleFonts.manrope(
                    fontSize: 13, color: textColor)),
              ])),
              requestsAsync.maybeWhen(
                data: (list) => list.isEmpty ? const SizedBox.shrink() : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: TwamboColors.primary,
                  child: Text('${list.length}', style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: Colors.black)),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ]),
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: requestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
              error: (e, _) => Center(child: Text('Error: $e',
                  style: TextStyle(color: TwamboColors.error))),
              data: (requests) {
                if (requests.isEmpty) {
                  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inbox_outlined, size: 48, color: TwamboColors.textSecondary),
                    const SizedBox(height: 16),
                    Text('NO PENDING REQUESTS', style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: TwamboColors.textSecondary, letterSpacing: 1.5)),
                    const SizedBox(height: 6),
                    Text('Rider broadcasts will appear here', style: GoogleFonts.manrope(
                        fontSize: 13, color: TwamboColors.textSecondary)),
                  ]));
                }
                return RefreshIndicator(
                  color: TwamboColors.primary,
                  onRefresh: () => ref.refresh(broadcastRequestsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _RequestCard(
                      r: requests[i],
                      isDark: isDark,
                      ref: ref,
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Request card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatefulWidget {
  final BroadcastRequest r;
  final bool isDark;
  final WidgetRef ref;
  const _RequestCard({required this.r, required this.isDark, required this.ref});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _accepting = false;
  bool _declining = false;
  bool _handled = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      if (kUseMockData) {
        await Future.delayed(const Duration(milliseconds: 500));
        final user = widget.ref.read(authProvider).user;
        acceptMockBroadcastRequest(
          widget.r.id,
          driverId: user?.id ?? 0,
          driverName: user?.fullName ?? 'Driver',
        );
      } else {
        await ApiClient.dio.post(Endpoints.acceptBroadcastRequest(widget.r.id));
      }
      widget.ref.invalidate(broadcastRequestsProvider);
      if (mounted) setState(() => _handled = true);
    } catch (_) {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _declining = true);
    try {
      if (kUseMockData) {
        await Future.delayed(const Duration(milliseconds: 300));
        declineMockBroadcastRequest(widget.r.id);
      } else {
        await ApiClient.dio.post(Endpoints.declineBroadcastRequest(widget.r.id));
      }
      widget.ref.invalidate(broadcastRequestsProvider);
      if (mounted) setState(() => _handled = true);
    } catch (_) {
      if (mounted) setState(() => _declining = false);
    }
  }

  void _showMap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestMapSheet(r: widget.r, isDark: widget.isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_handled) return const SizedBox.shrink();

    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final r = widget.r;

    final distKm = haversineKm(
      -12.7986, 28.2045, // driver's active trip origin (Parklands mock)
      r.originLat, r.originLng,
    );
    final minsAgoText = r.createdMinsAgo < 1
        ? 'Just now'
        : r.createdMinsAgo == 1
            ? '1 min ago'
            : '${r.createdMinsAgo} mins ago';

    return GestureDetector(
      onTap: () => _showMap(context),
      child: Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: const Border(left: BorderSide(color: TwamboColors.primary, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Top row: avatar + time + mode ─────────────────────────────
        Row(children: [
          Container(
            width: 36, height: 36,
            color: TwamboColors.primary,
            alignment: Alignment.center,
            child: Text(r.riderInitials, style: GoogleFonts.spaceGrotesk(
                fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RIDER', style: GoogleFonts.spaceGrotesk(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: TwamboColors.textSecondary, letterSpacing: 1.5)),
            Text(minsAgoText, style: GoogleFonts.manrope(
                fontSize: 11, color: TwamboColors.textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: r.mode == 'dynamic'
                ? TwamboColors.primary.withValues(alpha: 0.15)
                : TwamboColors.secondary.withValues(alpha: 0.15),
            child: Text(r.mode.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                fontSize: 8, fontWeight: FontWeight.w800,
                color: r.mode == 'dynamic' ? TwamboColors.primary : TwamboColors.secondary,
                letterSpacing: 1.2)),
          ),
        ]),

        const SizedBox(height: 12),

        // ── Route ─────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            const Icon(Icons.circle, size: 8, color: TwamboColors.primary),
            Container(width: 1, height: 20, color: TwamboColors.line),
            const Icon(Icons.location_on_rounded, size: 14, color: TwamboColors.error),
          ]),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.originName, style: GoogleFonts.manrope(
                fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Text(r.destinationName, style: GoogleFonts.manrope(
                fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),

        const SizedBox(height: 12),

        // ── Stats row ─────────────────────────────────────────────────
        Row(children: [
          _Chip(Icons.payments_outlined,
              'K${r.fareEstimate.toStringAsFixed(0)} est.', TwamboColors.success),
          const SizedBox(width: 8),
          _Chip(Icons.near_me_outlined,
              '${distKm.toStringAsFixed(1)} km away', TwamboColors.textSecondary),
        ]),

        const SizedBox(height: 14),
        Container(height: 1, color: isDark ? const Color(0xFF2A2A2A) : TwamboColors.line),
        const SizedBox(height: 12),

        // ── Actions ───────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: (_accepting || _declining) ? null : _accept,
              child: Container(
                height: 40,
                color: (_accepting || _declining)
                    ? TwamboColors.success.withValues(alpha: 0.5)
                    : TwamboColors.success,
                alignment: Alignment.center,
                child: _accepting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('ACCEPT', style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 1)),
                      ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: (_accepting || _declining) ? null : _decline,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: (_accepting || _declining)
                        ? TwamboColors.error.withValues(alpha: 0.4)
                        : TwamboColors.error,
                  ),
                ),
                alignment: Alignment.center,
                child: _declining
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: TwamboColors.error, strokeWidth: 2))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.close_rounded, size: 16, color: TwamboColors.error),
                        const SizedBox(width: 6),
                        Text('DECLINE', style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: TwamboColors.error, letterSpacing: 1)),
                      ]),
              ),
            ),
          ),
        ]),
      ]),
    )); // closes Container + GestureDetector
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.manrope(
            fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]);
}

// ── Map modal sheet ───────────────────────────────────────────────────────────

final _requestRouteProvider = FutureProvider.family<List<LatLng>, String>((ref, key) async {
  final parts = key.split(',');
  final oLat = double.parse(parts[0]); final oLng = double.parse(parts[1]);
  final dLat = double.parse(parts[2]); final dLng = double.parse(parts[3]);
  try {
    final url = 'https://router.project-osrm.org/route/v1/driving/$oLng,$oLat;$dLng,$dLat?overview=full&geometries=geojson';
    final dio = ApiClient.dio;
    final resp = await dio.get(url);
    final coords = resp.data['routes'][0]['geometry']['coordinates'] as List;
    return coords.map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
  } catch (_) {
    return [LatLng(oLat, oLng), LatLng(dLat, dLng)];
  }
});

class _RequestMapSheet extends ConsumerWidget {
  final BroadcastRequest r;
  final bool isDark;
  const _RequestMapSheet({required this.r, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    // Build key from origin to a lookup for destination
    final destPlace = kitwePlaces.firstWhere(
      (p) => r.destinationName.toLowerCase().contains(p.name.toLowerCase().split(',').first.toLowerCase()),
      orElse: () => KitwePlace('', -12.8024, 28.2132),
    );
    final destLat = destPlace.lat;
    final destLng = destPlace.lng;
    final mapKey = '${r.originLat},${r.originLng},$destLat,$destLng';
    final routeAsync = ref.watch(_requestRouteProvider(mapKey));

    final midLat = (r.originLat + destLat) / 2;
    final midLng = (r.originLng + destLng) / 2;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: sheetBg,
        border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
      ),
      child: Column(children: [
        // Handle + header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(children: [
            Container(width: 36, height: 4, color: TwamboColors.line),
            const SizedBox(height: 14),
            Row(children: [
              Container(
                width: 34, height: 34, color: TwamboColors.primary, alignment: Alignment.center,
                child: Text(r.riderInitials, style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.originName, style: GoogleFonts.manrope(
                    fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  const Icon(Icons.arrow_downward_rounded, size: 10, color: TwamboColors.textSecondary),
                  const SizedBox(width: 3),
                  Expanded(child: Text(r.destinationName, style: GoogleFonts.manrope(
                      fontSize: 12, color: TwamboColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: TwamboColors.success.withValues(alpha: 0.12),
                child: Text('K${r.fareEstimate.toStringAsFixed(0)}', style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w800, color: TwamboColors.success)),
              ),
            ]),
          ]),
        ),

        // Map
        Expanded(child: Stack(children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(midLat, midLng),
              initialZoom: 13,
            ),
            children: [
              if (kShowMapTiles) TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.twambo.app',
              ) else const ColoredBox(color: Color(0xFFD8DADB)),
              routeAsync.when(
                data: (pts) => PolylineLayer(polylines: [
                  Polyline(points: pts, strokeWidth: 4, color: TwamboColors.primary),
                ]),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              MarkerLayer(markers: [
                Marker(
                  point: LatLng(r.originLat, r.originLng),
                  width: 20, height: 20,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: TwamboColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                Marker(
                  point: LatLng(destLat, destLng),
                  width: 28, height: 28,
                  child: const Icon(Icons.location_on_rounded, color: TwamboColors.error, size: 28),
                ),
              ]),
            ],
          ),
          if (routeAsync.isLoading)
            const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
        ])),
      ]),
    );
  }
}
