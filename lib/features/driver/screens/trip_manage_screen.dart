import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
import '../../../shared/rating_dialog.dart';
import 'driver_home_screen.dart' show driverTripsProvider;

// ── Providers ─────────────────────────────────────────────────────────────────

final _tripRouteProvider = FutureProvider.family<List<LatLng>, String>((ref, key) async {
  final p = key.split(',');
  final oLat = double.parse(p[0]); final oLng = double.parse(p[1]);
  final dLat = double.parse(p[2]); final dLng = double.parse(p[3]);
  try {
    final url = 'https://router.project-osrm.org/route/v1/driving/$oLng,$oLat;$dLng,$dLat?overview=full&geometries=geojson';
    final resp = await ApiClient.dio.get(url);
    final coords = resp.data['routes'][0]['geometry']['coordinates'] as List;
    return coords.map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
  } catch (_) {
    return [LatLng(oLat, oLng), LatLng(dLat, dLng)];
  }
});

final driverTripDetailProvider = FutureProvider.autoDispose.family<Trip, int>((ref, id) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 200));
    return mockDriverTripById(id) ?? mockDriverTrips.first;
  }
  final resp = await ApiClient.dio.get(Endpoints.driverTripDetail(id));
  return Trip.fromJson(resp.data);
});

final _bookingsProvider = FutureProvider.autoDispose.family<List<_ManageBooking>, int>((ref, tripId) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 150));
    return (mockTripBookings[tripId] ?? [])
        .map<_ManageBooking>((j) => _ManageBooking.fromJson(j))
        .toList();
  }
  final resp = await ApiClient.dio.get(Endpoints.tripBookings(tripId));
  final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
  return raw.map<_ManageBooking>((j) => _ManageBooking.fromJson(j as Map<String, dynamic>)).toList();
});

final _rideRequestsProvider = FutureProvider.autoDispose.family<List<_DriveableRequest>, int>((ref, tripId) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 150));
    return (mockTripRideRequests[tripId] ?? [])
        .map<_DriveableRequest>((j) => _DriveableRequest.fromJson(j))
        .toList();
  }
  try {
    final resp = await ApiClient.dio.get(Endpoints.tripRideRequests(tripId));
    final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
    return raw.map<_DriveableRequest>((j) => _DriveableRequest.fromJson(j as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

// ── Models ────────────────────────────────────────────────────────────────────

class _ManageBooking {
  final int id;
  final String riderName;
  final String riderPhone;
  final String pickupName;
  final double pickupLat;
  final double pickupLng;
  final String dropoffName;
  final double dropoffLat;
  final double dropoffLng;
  final double amountDue;
  final String status;
  final bool isPickedUp;
  const _ManageBooking({
    required this.id, required this.riderName, required this.riderPhone,
    required this.pickupName, required this.pickupLat, required this.pickupLng,
    required this.dropoffName, required this.dropoffLat, required this.dropoffLng,
    required this.amountDue, required this.status, required this.isPickedUp,
  });
  factory _ManageBooking.fromJson(Map<String, dynamic> j) => _ManageBooking(
        id: j['id'],
        riderName: j['rider_name'] ?? 'Rider',
        riderPhone: j['rider_phone'] ?? '',
        pickupName: j['pickup_name'] ?? '',
        pickupLat: double.tryParse((j['pickup_lat'] ?? '0').toString()) ?? 0,
        pickupLng: double.tryParse((j['pickup_lng'] ?? '0').toString()) ?? 0,
        dropoffName: j['dropoff_name'] ?? '',
        dropoffLat: double.tryParse((j['dropoff_lat'] ?? '0').toString()) ?? 0,
        dropoffLng: double.tryParse((j['dropoff_lng'] ?? '0').toString()) ?? 0,
        amountDue: double.tryParse((j['amount_due'] ?? '0').toString()) ?? 0,
        status: j['status'] ?? 'confirmed',
        isPickedUp: j['is_picked_up'] == true,
      );
}

class _DriveableRequest {
  final int id;
  final String originName;
  final double originLat;
  final double originLng;
  final String destinationName;
  final double fareEstimate;
  final String mode;
  final String riderInitials;
  final int createdMinsAgo;
  const _DriveableRequest({
    required this.id, required this.originName, required this.originLat,
    required this.originLng, required this.destinationName, required this.fareEstimate,
    required this.mode, required this.riderInitials, required this.createdMinsAgo,
  });
  factory _DriveableRequest.fromJson(Map<String, dynamic> j) => _DriveableRequest(
        id: j['id'],
        originName: j['origin_name'] ?? '',
        originLat: double.tryParse((j['origin_lat'] ?? '0').toString()) ?? 0,
        originLng: double.tryParse((j['origin_lng'] ?? '0').toString()) ?? 0,
        destinationName: j['destination_name'] ?? '',
        fareEstimate: double.tryParse((j['fare_estimate'] ?? '0').toString()) ?? 0,
        mode: j['mode'] ?? 'dynamic',
        riderInitials: j['rider_initials'] as String? ?? '?',
        createdMinsAgo: j['created_mins_ago'] as int? ?? 0,
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TripManageScreen extends ConsumerWidget {
  final int tripId;
  const TripManageScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(driverTripDetailProvider(tripId));

    return Scaffold(
      body: tripAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Manage Trip')),
          body: Center(child: Text('Error: $e')),
        ),
        data: (trip) => _ManageBody(trip: trip, ref: ref, tripId: tripId),
      ),
    );
  }

  // Called from both Start and Cancel confirm dialogs
  static Future<void> confirmAction(
    BuildContext context,
    WidgetRef ref,
    int tripId,
    String label,
    Future<void> Function() fn, {
    bool popOnSuccess = false,
    Future<void> Function(BuildContext ctx)? onSuccess,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('$label trip?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, color: textColor)),
        content: Text('Are you sure you want to $label this trip?',
            style: GoogleFonts.manrope(color: TwamboColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: GoogleFonts.spaceGrotesk(
                fontSize: 11, fontWeight: FontWeight.w700, color: TwamboColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                fontSize: 11, fontWeight: FontWeight.w700, color: TwamboColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await fn();
      ref.invalidate(driverTripDetailProvider(tripId));
      ref.invalidate(driverTripsProvider);
      if (onSuccess != null && context.mounted) {
        await onSuccess(context);
      } else if (popOnSuccess && context.mounted) {
        context.canPop() ? context.pop() : context.go('/driver');
      }
    }
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ManageBody extends StatelessWidget {
  final Trip trip;
  final WidgetRef ref;
  final int tripId;
  const _ManageBody({required this.trip, required this.ref, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final screenH = MediaQuery.of(context).size.height;

    final originLatLng = LatLng(trip.originLat, trip.destinationLat == 0 ? trip.originLng + 0.05 : trip.originLng);
    final destLatLng = LatLng(trip.destinationLat, trip.destinationLng);
    final midLat = (originLatLng.latitude + destLatLng.latitude) / 2;
    final midLng = (originLatLng.longitude + destLatLng.longitude) / 2;
    final midpoint = LatLng(midLat, midLng);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── MAP (top 42%) ────────────────────────────────────────────────
          SizedBox(
            height: screenH * 0.42,
            child: _TripMap(
              trip: trip,
              originLatLng: originLatLng,
              destLatLng: destLatLng,
              midpoint: midpoint,
              ref: ref,
              tripId: tripId,
            ),
          ),

          // ── SCROLLABLE CONTENT (bottom 58%) ──────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderCard(trip: trip, isDark: isDark),
                  _StatsRow(trip: trip, isDark: isDark),
                  if (trip.isHike) _LongDistanceBanner(trip: trip, isDark: isDark),
                  if (trip.isHike && trip.isScheduled)
                    _HikeManifestSection(tripId: tripId, isDark: isDark),
                  if (trip.isScheduled &&
                      trip.bookingWindowOpen &&
                      trip.bookingWindowClosesAt != null &&
                      trip.mode != 'private')
                    _BookingWindowBanner(
                      closesAt: trip.bookingWindowClosesAt!,
                      tripId: tripId,
                      ridersCount: trip.seatsTaken,
                      minimumRiders: trip.minimumRiders,
                    ),
                  _PassengerSection(tripId: tripId, isDark: isDark),
                  _RequestsSection(tripId: tripId, isDark: isDark),
                  _ActionButtons(trip: trip, ref: ref, tripId: tripId, isDark: isDark),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map section ───────────────────────────────────────────────────────────────

class _TripMap extends ConsumerWidget {
  final Trip trip;
  final LatLng originLatLng;
  final LatLng destLatLng;
  final LatLng midpoint;
  final WidgetRef ref;
  final int tripId;
  const _TripMap({
    required this.trip, required this.originLatLng, required this.destLatLng,
    required this.midpoint, required this.ref, required this.tripId,
  });

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final bookingsAsync = innerRef.watch(_bookingsProvider(tripId));
    final bookings = bookingsAsync.maybeWhen(data: (b) => b, orElse: () => <_ManageBooking>[]);
    final routeKey = '${originLatLng.latitude},${originLatLng.longitude},${destLatLng.latitude},${destLatLng.longitude}';
    final routePts = innerRef.watch(_tripRouteProvider(routeKey)).maybeWhen(
      data: (pts) => pts,
      orElse: () => <LatLng>[originLatLng, destLatLng],
    );

    final activeBookings = bookings.where((b) => b.status != 'cancelled').toList();

    // Numbered pickup markers (yellow = waiting, green = picked up)
    final pickupMarkers = activeBookings.asMap().entries
        .where((e) => e.value.pickupLat != 0)
        .map((e) {
          final b = e.value;
          final seq = e.key + 1;
          final done = b.isPickedUp;
          return Marker(
            point: LatLng(b.pickupLat, b.pickupLng),
            width: 28, height: 28,
            child: Container(
              decoration: BoxDecoration(
                color: done ? TwamboColors.success : TwamboColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(child: Text('$seq',
                style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
          );
        }).toList();

    // Dropoff markers (red circle with letter A, B, C…) — shown for all passengers with coords
    final dropoffMarkers = activeBookings.asMap().entries
        .where((e) => e.value.dropoffLat != 0)
        .map((e) {
          final b = e.value;
          final letter = String.fromCharCode(65 + e.key); // A, B, C…
          return Marker(
            point: LatLng(b.dropoffLat, b.dropoffLng),
            width: 28, height: 28,
            child: Container(
              decoration: BoxDecoration(
                color: TwamboColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(child: Text(letter,
                style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
          );
        }).toList();

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: midpoint, initialZoom: 12),
          children: [
            if (kShowMapTiles)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.twambo.app',
              )
            else
              const ColoredBox(color: Color(0xFFD8DADB), child: SizedBox.expand()),
            PolylineLayer(polylines: [
              Polyline(
                points: routePts,
                color: trip.isActive ? TwamboColors.success : TwamboColors.secondary,
                strokeWidth: 4,
              ),
            ]),
            MarkerLayer(markers: [
              // Origin
              Marker(
                point: originLatLng, width: 36, height: 36,
                child: const Icon(Icons.location_on, color: TwamboColors.success, size: 32),
              ),
              // Destination
              Marker(
                point: destLatLng, width: 36, height: 36,
                child: const Icon(Icons.flag_rounded, color: TwamboColors.error, size: 28),
              ),
              // Rider pickups (numbered)
              ...pickupMarkers,
              // Rider dropoffs (lettered)
              ...dropoffMarkers,
            ]),
          ],
        ),

        // ── Back button overlay (top-left) ─────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.canPop() ? context.pop() : context.go('/driver'),
                  child: Container(
                    width: 40, height: 40,
                    color: Colors.white.withValues(alpha: 0.92),
                    child: const Icon(Icons.arrow_back, size: 20, color: TwamboColors.textPrimary),
                  ),
                ),
                const Spacer(),
                if (trip.isActive)
                  GestureDetector(
                    onTap: () => context.go('/driver/gps/${trip.id}/${trip.driverId}'),
                    child: Container(
                      width: 40, height: 40,
                      color: TwamboColors.primary,
                      child: const Icon(Icons.my_location, size: 18, color: TwamboColors.textPrimary),
                    ),
                  ),
              ]),
            ),
          ),
        ),

        // ── Route label overlay (bottom of map) ──────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(children: [
              const Icon(Icons.location_on, size: 12, color: TwamboColors.success),
              const SizedBox(width: 6),
              Expanded(child: Text(
                '${trip.originName}  →  ${trip.destinationName}',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              )),
              const SizedBox(width: 8),
              const Icon(Icons.flag_rounded, size: 12, color: TwamboColors.error),
            ]),
          ),
        ),

        // ── Legend (bottom-right) ─────────────────────────────────────────
        Positioned(
          bottom: 36, right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.black.withValues(alpha: 0.6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _LegendItem(color: TwamboColors.success, label: 'Origin'),
              const SizedBox(height: 3),
              _LegendItem(color: TwamboColors.error, label: 'Destination'),
              if (pickupMarkers.isNotEmpty) ...[
                const SizedBox(height: 3),
                _LegendItem(color: TwamboColors.primary, label: 'Pickup'),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, color: color),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.manrope(fontSize: 9, color: Colors.white70)),
    ]);
  }
}

// ── Header card ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final Trip trip;
  final bool isDark;
  const _HeaderCard({required this.trip, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final statusColor = trip.isActive ? TwamboColors.success
        : trip.isScheduled ? TwamboColors.primary
        : trip.isCancelled ? TwamboColors.error
        : TwamboColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MANAGE TRIP', style: GoogleFonts.spaceGrotesk(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: TwamboColors.textSecondary, letterSpacing: 2)),
          const SizedBox(height: 3),
          Text('${trip.originName} → ${trip.destinationName}',
              style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          color: statusColor.withValues(alpha: 0.12),
          child: Text(trip.status.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 9, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 1.5)),
        ),
      ]),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Trip trip;
  final bool isDark;
  const _StatsRow({required this.trip, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final divColor = isDark ? const Color(0xFF2E2E2E) : TwamboColors.line;

    return Container(
      color: cardBg,
      margin: const EdgeInsets.only(top: 8),
      child: Row(children: [
        _Stat(icon: Icons.event_seat_rounded, label: 'SEATS',
            value: '${trip.seatsTaken}/${trip.totalSeats}', isDark: isDark),
        Container(width: 1, height: 40, color: divColor),
        _Stat(icon: Icons.payments_outlined, label: 'FARE',
            value: 'K${trip.currentSharedFare.toStringAsFixed(0)}', isDark: isDark),
        Container(width: 1, height: 40, color: divColor),
        _Stat(icon: Icons.route_rounded, label: 'MODE',
            value: trip.mode.toUpperCase(), isDark: isDark),
        Container(width: 1, height: 40, color: divColor),
        _Stat(icon: Icons.access_time_rounded, label: 'DEPARTS',
            value: _fmtTime(trip.departureTime), isDark: isDark),
      ]),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  const _Stat({required this.icon, required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    return Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Icon(icon, size: 16, color: TwamboColors.secondary),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.spaceGrotesk(
            fontSize: 12, fontWeight: FontWeight.w800, color: textColor)),
        Text(label, style: GoogleFonts.manrope(
            fontSize: 9, color: TwamboColors.textSecondary, letterSpacing: 1)),
      ]),
    ));
  }
}

// ── Long Distance banner ──────────────────────────────────────────────────────

class _LongDistanceBanner extends StatelessWidget {
  final Trip trip;
  final bool isDark;
  const _LongDistanceBanner({required this.trip, required this.isDark});

  static const _hikeOrange = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2A1800) : const Color(0xFFFFF3E0);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(left: BorderSide(color: _hikeOrange, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: _hikeOrange,
            child: Text('LONG DISTANCE', style: GoogleFonts.spaceGrotesk(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 1.5)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${trip.originName} → ${trip.destinationName}',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _hikeOrange),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: _hikeOrange),
          const SizedBox(width: 5),
          Expanded(child: Text(
            'Riders may pay a home pickup detour fee (up to K50). '
            'This is charged automatically based on how far their pickup is from your departure point.',
            style: GoogleFonts.manrope(fontSize: 11, color: _hikeOrange, height: 1.4),
          )),
        ]),
      ]),
    );
  }
}

// ── Hike passenger manifest ───────────────────────────────────────────────────

class _HikeManifestSection extends ConsumerWidget {
  final int tripId;
  final bool isDark;
  const _HikeManifestSection({required this.tripId, required this.isDark});

  static const _hikeOrange = Color(0xFFE65100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_bookingsProvider(tripId));
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return bookingsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (bookings) {
        final confirmed = bookings.where((b) => b.status == 'confirmed').toList();
        if (confirmed.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: bg,
            border: const Border(left: BorderSide(color: _hikeOrange, width: 4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(children: [
                const Icon(Icons.format_list_numbered_rounded, size: 14, color: _hikeOrange),
                const SizedBox(width: 6),
                Text('PASSENGER MANIFEST', style: GoogleFonts.spaceGrotesk(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: _hikeOrange, letterSpacing: 1.5)),
                const Spacer(),
                Text('${confirmed.length} confirmed', style: GoogleFonts.manrope(
                    fontSize: 10, color: TwamboColors.textSecondary)),
              ]),
            ),
            const Divider(height: 1),
            ...confirmed.asMap().entries.map((e) {
              final i = e.key;
              final b = e.value;
              return Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  border: i < confirmed.length - 1
                      ? Border(bottom: BorderSide(
                          color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.line))
                      : null,
                ),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    color: _hikeOrange.withValues(alpha: 0.12),
                    alignment: Alignment.center,
                    child: Text('${i + 1}', style: GoogleFonts.spaceGrotesk(
                        fontSize: 10, fontWeight: FontWeight.w800, color: _hikeOrange)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.riderName, style: GoogleFonts.spaceGrotesk(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : TwamboColors.textPrimary)),
                    if (b.pickupName.isNotEmpty)
                      Text('Boards: ${b.pickupName}', style: GoogleFonts.manrope(
                          fontSize: 10, color: TwamboColors.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  if (b.riderPhone.isNotEmpty)
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse('tel:${b.riderPhone}')),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: _hikeOrange.withValues(alpha: 0.10),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.phone_outlined, size: 12, color: _hikeOrange),
                          const SizedBox(width: 4),
                          Text(b.riderPhone, style: GoogleFonts.manrope(
                              fontSize: 10, fontWeight: FontWeight.w600, color: _hikeOrange)),
                        ]),
                      ),
                    ),
                ]),
              );
            }),
          ]),
        );
      },
    );
  }
}

// ── Passenger section ─────────────────────────────────────────────────────────

class _PassengerSection extends ConsumerWidget {
  final int tripId;
  final bool isDark;
  const _PassengerSection({required this.tripId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_bookingsProvider(tripId));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text('PASSENGERS', style: GoogleFonts.spaceGrotesk(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: TwamboColors.textSecondary, letterSpacing: 2)),
      ),
      bookingsAsync.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: TwamboColors.primary, strokeWidth: 2)),
        error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Could not load passengers', style: GoogleFonts.manrope(
                fontSize: 12, color: TwamboColors.textSecondary))),
        data: (bookings) {
          if (bookings.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  border: const Border(left: BorderSide(color: TwamboColors.line, width: 2)),
                ),
                child: Row(children: [
                  const Icon(Icons.group_outlined, size: 20, color: TwamboColors.textSecondary),
                  const SizedBox(width: 10),
                  Text('No riders booked yet', style: GoogleFonts.manrope(
                      fontSize: 12, color: TwamboColors.textSecondary)),
                ]),
              ),
            );
          }
          return Column(children: bookings.map((b) => _BookingCard(b: b, isDark: isDark, tripId: tripId)).toList());
        },
      ),
    ]);
  }
}

class _BookingCard extends ConsumerStatefulWidget {
  final _ManageBooking b;
  final bool isDark;
  final int tripId;
  const _BookingCard({required this.b, required this.isDark, required this.tripId});
  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  bool _pickingUp = false;

  Future<void> _markPickedUp() async {
    setState(() => _pickingUp = true);
    try {
      await ApiClient.dio.post(Endpoints.markPickedUp(widget.b.id));
      ref.invalidate(_bookingsProvider(widget.tripId));
    } catch (_) {}
    if (mounted) setState(() => _pickingUp = false);
  }

  void _showContact(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactSheet(name: widget.b.riderName, phone: widget.b.riderPhone, role: 'Rider'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final cardBg = widget.isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDark ? Colors.white : TwamboColors.textPrimary;
    final statusColor = b.isPickedUp ? TwamboColors.success
        : b.status == 'confirmed' ? TwamboColors.primary
        : b.status == 'cancelled' ? TwamboColors.error : TwamboColors.secondary;
    final initial = b.riderName.isNotEmpty ? b.riderName[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _showContact(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(left: BorderSide(color: statusColor, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              color: statusColor.withValues(alpha: 0.15),
              child: Center(child: Text(initial, style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w800, color: statusColor))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.riderName, style: GoogleFonts.spaceGrotesk(
                  fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 10,
                    color: b.isPickedUp ? TwamboColors.success : TwamboColors.textSecondary),
                const SizedBox(width: 3),
                Expanded(child: Text(
                  b.isPickedUp ? '→ ${b.dropoffName}' : b.pickupName,
                  style: GoogleFonts.manrope(fontSize: 10,
                      color: b.isPickedUp ? TwamboColors.success : TwamboColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('K${b.amountDue.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800,
                      color: TwamboColors.primary)),
              const SizedBox(height: 2),
              const Icon(Icons.phone_outlined, size: 11, color: TwamboColors.primary),
            ]),
          ]),

          // PICKED UP button (only for active trips with unconfirmed pickup)
          if (b.status == 'confirmed' && !b.isPickedUp) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickingUp ? null : _markPickedUp,
              child: Container(
                height: 32, width: double.infinity,
                color: _pickingUp ? TwamboColors.line : TwamboColors.success,
                child: Center(
                  child: _pickingUp
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle_outline, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('PICKED UP', style: GoogleFonts.spaceGrotesk(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 1)),
                        ]),
                ),
              ),
            ),
          ] else if (b.isPickedUp) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.check_circle, size: 12, color: TwamboColors.success),
              const SizedBox(width: 4),
              Text('ON BOARD · DROP OFF AT ${b.dropoffName.split(',').first.toUpperCase()}',
                  style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w700,
                      color: TwamboColors.success, letterSpacing: 0.8),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ── Shared contact sheet ──────────────────────────────────────────────────────

class _ContactSheet extends StatelessWidget {
  final String name;
  final String phone;
  final String role;
  const _ContactSheet({required this.name, required this.phone, required this.role});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone.isNotEmpty;
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, color: Colors.black12),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: TwamboColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(23),
            ),
            child: Center(child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 20, fontWeight: FontWeight.w800, color: TwamboColors.primary),
            )),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.spaceGrotesk(
                fontSize: 15, fontWeight: FontWeight.w700, color: TwamboColors.textPrimary)),
            Text(role, style: GoogleFonts.manrope(
                fontSize: 12, color: TwamboColors.textSecondary)),
          ])),
        ]),
        const SizedBox(height: 16),
        if (hasPhone) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFF5F5F5),
            child: Row(children: [
              const Icon(Icons.phone_outlined, size: 16, color: TwamboColors.textSecondary),
              const SizedBox(width: 10),
              Text(phone, style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w600, color: TwamboColors.textPrimary)),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ActionBtn(
              icon: Icons.call,
              label: 'Call',
              color: TwamboColors.success,
              onTap: () => _launch('tel:$clean'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _ActionBtn(
              icon: Icons.message_outlined,
              label: 'SMS',
              color: TwamboColors.primary,
              onTap: () => _launch('sms:$clean'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _ActionBtn(
              icon: Icons.chat_bubble_outline,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () => _launch('https://wa.me/${clean.replaceAll('+', '')}'),
            )),
          ]),
        ] else
          Text('No phone number available',
              style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary)),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: color.withValues(alpha: 0.1),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.manrope(
            fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
  );
}

// ── Incoming requests section ─────────────────────────────────────────────────

class _RequestsSection extends ConsumerStatefulWidget {
  final int tripId;
  final bool isDark;
  const _RequestsSection({required this.tripId, required this.isDark});

  @override
  ConsumerState<_RequestsSection> createState() => _RequestsSectionState();
}

class _RequestsSectionState extends ConsumerState<_RequestsSection> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        ref.invalidate(_rideRequestsProvider(widget.tripId));
        ref.invalidate(_bookingsProvider(widget.tripId));
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripId = widget.tripId;
    final isDark = widget.isDark;
    final requestsAsync = ref.watch(_rideRequestsProvider(tripId));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Row(children: [
          Text('INCOMING REQUESTS', style: GoogleFonts.spaceGrotesk(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: TwamboColors.accent, letterSpacing: 2)),
          const SizedBox(width: 8),
          requestsAsync.maybeWhen(
            data: (r) => r.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: TwamboColors.accent,
                    child: Text('${r.length}', style: GoogleFonts.spaceGrotesk(
                        fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ]),
      ),
      requestsAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(color: TwamboColors.primary, strokeWidth: 2)),
        error: (_, __) => const SizedBox.shrink(),
        data: (requests) {
          if (requests.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  border: Border(left: BorderSide(
                      color: TwamboColors.accent.withValues(alpha: 0.4), width: 2)),
                ),
                child: Row(children: [
                  Icon(Icons.hail_rounded, size: 20, color: TwamboColors.accent.withValues(alpha: 0.5)),
                  const SizedBox(width: 10),
                  Text('No incoming requests nearby',
                      style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
                ]),
              ),
            );
          }
          return Column(children: requests.map((r) => _RequestCard(r: r, isDark: isDark, tripId: tripId, outerRef: ref)).toList()); // ref is ConsumerState.ref
        },
      ),
    ]);
  }
}

class _RequestCard extends StatefulWidget {
  final _DriveableRequest r;
  final bool isDark;
  final int tripId;
  final WidgetRef outerRef;
  const _RequestCard({required this.r, required this.isDark, required this.tripId, required this.outerRef});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _accepting = false;
  bool _rejecting = false;
  bool _handled = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      if (kUseMockData) {
        await Future.delayed(const Duration(milliseconds: 500));
        acceptMockRideRequest(widget.tripId, widget.r.id);
      } else {
        await ApiClient.dio.post(Endpoints.acceptRideRequest(widget.tripId, widget.r.id));
      }
      widget.outerRef.invalidate(_rideRequestsProvider(widget.tripId));
      widget.outerRef.invalidate(_bookingsProvider(widget.tripId));
      widget.outerRef.invalidate(driverTripDetailProvider(widget.tripId));
      if (mounted) setState(() => _handled = true);
    } catch (e) {
      String msg = 'Failed to accept';
      try { msg = (e as dynamic).response?.data['detail'] ?? msg; } catch (_) {}
      if (mounted) {
        setState(() => _accepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: TwamboColors.error),
        );
      }
    }
  }

  Future<void> _reject() async {
    setState(() => _rejecting = true);
    try {
      if (kUseMockData) {
        await Future.delayed(const Duration(milliseconds: 300));
        rejectMockRideRequest(widget.tripId, widget.r.id);
      } else {
        await ApiClient.dio.post(Endpoints.rejectRideRequest(widget.tripId, widget.r.id));
      }
      widget.outerRef.invalidate(_rideRequestsProvider(widget.tripId));
      if (mounted) setState(() => _handled = true);
    } catch (e) {
      String msg = 'Failed to reject';
      try { msg = (e as dynamic).response?.data['detail'] ?? msg; } catch (_) {}
      if (mounted) {
        setState(() => _rejecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: TwamboColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_handled) { return const SizedBox.shrink(); }

    final cardBg = widget.isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDark ? Colors.white : TwamboColors.textPrimary;
    final r = widget.r;
    final minsText = r.createdMinsAgo < 1 ? 'Just now'
        : r.createdMinsAgo == 1 ? '1 min ago'
        : '${r.createdMinsAgo} mins ago';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      decoration: BoxDecoration(
        color: cardBg,
        border: const Border(left: BorderSide(color: TwamboColors.accent, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            color: TwamboColors.accent.withValues(alpha: 0.15),
            child: Center(child: Text(r.riderInitials, style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w800, color: TwamboColors.accent))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.originName} → ${r.destinationName}',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: TwamboColors.accent.withValues(alpha: 0.1),
                child: Text(r.mode.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                    fontSize: 7, fontWeight: FontWeight.w800, color: TwamboColors.accent, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Text(minsText, style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
            ]),
          ])),
          Text('K${r.fareEstimate.toStringAsFixed(0)}',
              style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w800, color: TwamboColors.accent)),
        ]),
        const SizedBox(height: 10),
        // ── Accept / Reject buttons ────────────────────────────────────────
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: (_accepting || _rejecting) ? null : _accept,
            child: Container(
              height: 36,
              color: TwamboColors.success,
              alignment: Alignment.center,
              child: _accepting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check, size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                      Text('ACCEPT', style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                    ]),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(
            onTap: (_accepting || _rejecting) ? null : _reject,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(color: TwamboColors.error, width: 1.5),
              ),
              alignment: Alignment.center,
              child: _rejecting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: TwamboColors.error, strokeWidth: 2))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.close, size: 14, color: TwamboColors.error),
                      const SizedBox(width: 5),
                      Text('DECLINE', style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, fontWeight: FontWeight.w800, color: TwamboColors.error, letterSpacing: 1)),
                    ]),
            ),
          )),
        ]),
      ]),
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final Trip trip;
  final WidgetRef ref;
  final int tripId;
  final bool isDark;
  const _ActionButtons({required this.trip, required this.ref, required this.tripId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(children: [
        if (trip.isScheduled) ...[
          _Btn(
            label: 'START TRIP',
            icon: Icons.play_arrow_rounded,
            color: TwamboColors.success,
            textColor: Colors.white,
            onTap: () => TripManageScreen.confirmAction(context, ref, tripId, 'Start', () async {
              if (kUseMockData) { await Future.delayed(const Duration(milliseconds: 400)); startMockTrip(trip.id); return; }
              await ApiClient.dio.post(Endpoints.tripStart(trip.id));
            }),
          ),
          const SizedBox(height: 8),
          _Btn(
            label: 'CANCEL TRIP',
            icon: Icons.cancel_outlined,
            color: Colors.transparent,
            textColor: TwamboColors.error,
            border: TwamboColors.error,
            onTap: () => TripManageScreen.confirmAction(
              context, ref, tripId, 'Cancel',
              () async {
                if (kUseMockData) { await Future.delayed(const Duration(milliseconds: 400)); cancelMockTrip(trip.id); return; }
                await ApiClient.dio.post(Endpoints.tripCancel(trip.id));
              },
              popOnSuccess: true,
            ),
          ),
        ],
        if (trip.isActive) ...[
          _Btn(
            label: 'BROADCAST GPS',
            icon: Icons.my_location,
            color: TwamboColors.secondary,
            textColor: Colors.white,
            onTap: () => context.go('/driver/gps/${trip.id}/${trip.driverId}'),
          ),
          if (trip.isHike) ...[
            const SizedBox(height: 8),
            _Btn(
              label: 'ANNOUNCE DROP-OFF',
              icon: Icons.person_pin_circle_outlined,
              color: const Color(0xFFE65100),
              textColor: Colors.white,
              onTap: () => _showAnnounceDropoffSheet(context, trip),
            ),
          ],
          const SizedBox(height: 8),
          _Btn(
            label: 'COMPLETE TRIP',
            icon: Icons.check_circle_outline,
            color: TwamboColors.success,
            textColor: Colors.white,
            onTap: () => TripManageScreen.confirmAction(
              context, ref, tripId, 'Complete',
              () async {
                if (kUseMockData) { await Future.delayed(const Duration(milliseconds: 400)); completeMockTrip(trip.id); return; }
                await ApiClient.dio.post(Endpoints.tripComplete(trip.id));
              },
              onSuccess: (ctx) async {
                if (kUseMockData) {
                  if (ctx.mounted) { ctx.canPop() ? ctx.pop() : ctx.go('/driver'); }
                  return;
                }
                // Prompt driver to rate each rider
                final bookingsResp = await ApiClient.dio.get(Endpoints.tripBookings(trip.id));
                final raw = bookingsResp.data is List
                    ? bookingsResp.data as List
                    : (bookingsResp.data['results'] as List? ?? []);
                for (final b in raw) {
                  if (b['status'] == 'completed' && ctx.mounted) {
                    await showRatingDialog(ctx,
                      bookingId: b['id'] as int,
                      ratedUserName: b['rider_name'] as String? ?? 'Rider',
                      ratingAsDriver: true,
                    );
                  }
                }
                if (ctx.mounted) { ctx.canPop() ? ctx.pop() : ctx.go('/driver'); }
              },
            ),
          ),
        ],
      ]),
    );
  }
}

Future<void> _showAnnounceDropoffSheet(BuildContext context, Trip trip) async {
  const hikeCities = <(String, String)>[
    ('kitwe', 'Kitwe'), ('ndola', 'Ndola'), ('chingola', 'Chingola'),
    ('chililabombwe', 'Chililabombwe'), ('luanshya', 'Luanshya'),
    ('chambishi', 'Chambishi'), ('solwezi', 'Solwezi'),
    ('lumwana_kalumbila', 'Lumwana / Kalumbila'),
  ];

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

  final selected = await showModalBottomSheet<(String, String)>(
    context: context,
    backgroundColor: bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DROP-OFF CITY', style: GoogleFonts.spaceGrotesk(
            fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1,
            color: const Color(0xFFE65100),
          )),
          const SizedBox(height: 4),
          Text('Which city are you dropping a passenger at?',
              style: GoogleFonts.manrope(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: hikeCities.map((c) {
              final (id, name) = c;
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE65100)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(name, style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: const Color(0xFFE65100),
                  )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    ),
  );

  if (selected == null || !context.mounted) return;
  final (cityId, cityName) = selected;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: bg,
      title: Text('Announce drop-off?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
      content: Text('Riders in $cityName will be notified that a seat opens soon. They can request to join — you choose who boards.',
          style: GoogleFonts.manrope(fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('ANNOUNCE', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, color: const Color(0xFFE65100))),
        ),
      ],
    ),
  );

  if (ok != true || !context.mounted) return;
  try {
    await ApiClient.dio.post(
      Endpoints.announceDropoff(trip.id),
      data: {'city_name': cityName, 'city_id': cityId, 'seats': 1},
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Announced! Riders in $cityName will see this.'),
        backgroundColor: const Color(0xFFE65100),
      ));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Announcement failed. Check your connection.'),
        backgroundColor: Colors.red,
      ));
    }
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color? border;
  final VoidCallback onTap;
  const _Btn({
    required this.label, required this.icon, required this.color,
    required this.textColor, this.border, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52, width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          border: border != null ? Border.all(color: border!, width: 1.5) : null,
        ),
        child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 1)),
        ])),
      ),
    );
  }
}

// ── Booking window countdown banner ───────────────────────────────────────────

class _BookingWindowBanner extends ConsumerStatefulWidget {
  final DateTime closesAt;
  final int tripId;
  final int ridersCount;
  final int minimumRiders;

  const _BookingWindowBanner({
    required this.closesAt, required this.tripId,
    required this.ridersCount, required this.minimumRiders,
  });

  @override
  ConsumerState<_BookingWindowBanner> createState() => _BookingWindowBannerState();
}

class _BookingWindowBannerState extends ConsumerState<_BookingWindowBanner> {
  late Timer _timer;
  Duration _remaining = Duration.zero;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) { return; }
      setState(_updateRemaining);
      if (_remaining == Duration.zero && !_dialogShown) {
        _dialogShown = true;
        Future.delayed(const Duration(milliseconds: 300), _showClosedDialog);
      }
    });
  }

  void _updateRemaining() {
    final diff = widget.closesAt.difference(DateTime.now());
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _showClosedDialog() async {
    if (!mounted) { return; }
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WindowClosedDialog(
        ridersCount: widget.ridersCount,
        minimumRiders: widget.minimumRiders,
      ),
    );
    if (!mounted) { return; }

    if (result == 'proceed') {
      if (!kUseMockData) await ApiClient.dio.post(Endpoints.closeBookingWindow(widget.tripId));
      ref.invalidate(driverTripDetailProvider(widget.tripId));
      ref.invalidate(driverTripsProvider);
    } else if (result == 'cancel') {
      if (!kUseMockData) await ApiClient.dio.post(Endpoints.tripCancel(widget.tripId));
      ref.invalidate(driverTripDetailProvider(widget.tripId));
      ref.invalidate(driverTripsProvider);
      if (mounted) { context.canPop() ? context.pop() : context.go('/driver'); }
    }
    // 'wait' → dialog dismissed, driver waits for more riders
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expired = _remaining == Duration.zero;
    final mins = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    final borderColor = expired ? TwamboColors.error : TwamboColors.primary;
    final bgColor = expired
        ? TwamboColors.error.withValues(alpha: 0.08)
        : TwamboColors.primary.withValues(alpha: 0.07);
    final labelColor = expired ? TwamboColors.error : TwamboColors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : bgColor,
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Row(children: [
        Icon(
          expired ? Icons.timer_off : Icons.timer_outlined,
          size: 18,
          color: labelColor,
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            expired ? 'BOOKING WINDOW CLOSED' : 'BOOKING WINDOW',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 8, fontWeight: FontWeight.w800, color: labelColor, letterSpacing: 1.5),
          ),
          const SizedBox(height: 2),
          Text(
            expired
                ? '${widget.ridersCount} rider(s) aboard'
                : '${widget.ridersCount} rider(s) · closes in $mins:$secs',
            style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary),
          ),
        ])),
        if (!expired)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: TwamboColors.primary,
            child: Text('$mins:$secs', style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w800, color: TwamboColors.textPrimary)),
          ),
        if (expired)
          GestureDetector(
            onTap: _showClosedDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: TwamboColors.error,
              child: Text('DECIDE', style: GoogleFonts.spaceGrotesk(
                  fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
            ),
          ),
      ]),
    );
  }
}

// ── Window closed decision dialog ─────────────────────────────────────────────

class _WindowClosedDialog extends StatelessWidget {
  final int ridersCount;
  final int minimumRiders;
  const _WindowClosedDialog({required this.ridersCount, required this.minimumRiders});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final meetsMin = ridersCount >= minimumRiders;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: const Border(left: BorderSide(color: TwamboColors.primary, width: 5)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BOOKING WINDOW CLOSED', style: GoogleFonts.spaceGrotesk(
              fontSize: 11, fontWeight: FontWeight.w800, color: TwamboColors.primary, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              width: 48, height: 48,
              color: (meetsMin ? TwamboColors.success : TwamboColors.error).withValues(alpha: 0.1),
              child: Center(child: Text('$ridersCount', style: GoogleFonts.spaceGrotesk(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: meetsMin ? TwamboColors.success : TwamboColors.error))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${ridersCount == 1 ? '1 rider' : '$ridersCount riders'} aboard',
                  style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
              Text(
                meetsMin ? 'Minimum met — ready to go' : 'Below minimum of $minimumRiders rider(s)',
                style: GoogleFonts.manrope(fontSize: 11,
                    color: meetsMin ? TwamboColors.success : TwamboColors.error),
              ),
            ])),
          ]),
          const SizedBox(height: 20),
          if (meetsMin || ridersCount > 0) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context, 'proceed'),
              child: Container(
                height: 48, width: double.infinity,
                color: TwamboColors.success,
                alignment: Alignment.center,
                child: Text(
                  'PROCEED WITH $ridersCount RIDER${ridersCount != 1 ? 'S' : ''}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            onTap: () => Navigator.pop(context, 'wait'),
            child: Container(
              height: 44, width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: TwamboColors.primary, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text('KEEP WAITING FOR MORE RIDERS', style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: isDark ? TwamboColors.primary : TwamboColors.textPrimary, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.pop(context, 'cancel'),
            child: Container(
              height: 44, width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: TwamboColors.error, width: 1.5)),
              alignment: Alignment.center,
              child: Text('CANCEL TRIP', style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, fontWeight: FontWeight.w800, color: TwamboColors.error, letterSpacing: 1)),
            ),
          ),
        ]),
      ),
    );
  }
}
