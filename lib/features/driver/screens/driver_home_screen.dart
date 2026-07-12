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
import '../../../features/auth/auth_provider.dart';
import '../../../shared/app_providers.dart';
import '../../../shared/driver_nav_bar.dart';
import '../../../shared/theme.dart';

const _kitwe = LatLng(-12.8167, 28.2167);

final _broadcastCountProvider = FutureProvider.autoDispose<int>((ref) async {
  if (kUseMockData) return mockBroadcastRequests.length;
  try {
    final resp = await ApiClient.dio.get(Endpoints.driverBroadcastRequests);
    final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
    return raw.length;
  } catch (_) {
    return 0;
  }
});

final _tripPendingCountProvider = FutureProvider.autoDispose.family<int, int>((ref, tripId) async {
  if (kUseMockData) return mockTripRideRequests[tripId]?.length ?? 0;
  try {
    final resp = await ApiClient.dio.get(Endpoints.tripRideRequests(tripId));
    final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
    return raw.length;
  } catch (_) {
    return 0;
  }
});

final driverTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 350));
    final uid = ref.read(authProvider).user?.id ?? 0;
    return mockDriverTrips.where((t) => t.driverId == uid).toList();
  }
  final resp = await ApiClient.dio.get(Endpoints.driverTrips);
  final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
  return raw.map<Trip>((j) => Trip.fromJson(j as Map<String, dynamic>)).toList();
});

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool? _isOnline;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _loadOnlineStatus();
  }

  Future<void> _loadOnlineStatus() async {
    if (kUseMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _isOnline = mockDriverProfile['is_online'] as bool? ?? false);
      return;
    }
    try {
      final resp = await ApiClient.dio.get(Endpoints.driverProfile);
      if (mounted) setState(() => _isOnline = resp.data['is_online'] as bool? ?? false);
    } catch (_) {
      if (mounted) setState(() => _isOnline = false);
    }
  }

  Future<void> _toggleOnline() async {
    if (_isOnline == null || _toggling) return;
    setState(() => _toggling = true);
    final newVal = !_isOnline!;
    try {
      if (kUseMockData) {
        await Future.delayed(const Duration(milliseconds: 300));
        mockDriverProfile['is_online'] = newVal;
      } else {
        await ApiClient.dio.post(Endpoints.driverOnline, data: {'is_online': newVal});
      }
      if (mounted) setState(() { _isOnline = newVal; _toggling = false; });
    } catch (_) {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final tripsAsync = ref.watch(driverTripsProvider);
    final broadcastCount = ref.watch(_broadcastCountProvider).whenData((v) => v).value ?? 0;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final firstName = user?.fullName.split(' ').first ?? 'Driver';
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'GOOD MORNING' : hour < 17 ? 'GOOD AFTERNOON' : 'GOOD EVENING';

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: DriverNavBar(
        currentIndex: 0,
        requestsBadge: broadcastCount,
      ),
      body: SafeArea(
        bottom: false,
        child: tripsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: TwamboColors.error))),
          data: (trips) {
            final active = trips.where((t) => t.isActive).toList();
            final scheduled = trips.where((t) => t.isScheduled).toList();
            final upcoming = scheduled.where((t) => t.isCityTrip).toList();
            final hikePlanned = scheduled.where((t) => t.isHike).toList();

            return RefreshIndicator(
              color: TwamboColors.primary,
              onRefresh: () => ref.refresh(driverTripsProvider.future),
              child: CustomScrollView(
                slivers: [
                  // ── Header ────────────────────────────────────────────────
                  SliverToBoxAdapter(child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(greeting, style: GoogleFonts.spaceGrotesk(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: TwamboColors.textSecondary, letterSpacing: 2)),
                        Text(firstName.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                            fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
                      ])),
                      // Dark mode toggle
                      GestureDetector(
                        onTap: () => ref.read(themeModeProvider.notifier).toggle(),
                        child: Container(
                          width: 36, height: 36,
                          margin: const EdgeInsets.only(right: 10),
                          color: isDark
                              ? const Color(0xFF2E2E2E)
                              : TwamboColors.surfaceAlt,
                          child: Icon(
                            themeMode == ThemeMode.dark
                                ? Icons.wb_sunny_rounded
                                : Icons.nights_stay_rounded,
                            size: 18,
                            color: themeMode == ThemeMode.dark
                                ? TwamboColors.primary
                                : TwamboColors.secondary,
                          ),
                        ),
                      ),
                      // Online toggle
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(
                          _isOnline == null ? '···' : (_isOnline! ? 'ONLINE' : 'OFFLINE'),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5,
                            color: _isOnline == true ? TwamboColors.success : TwamboColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: _toggleOnline,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 48, height: 26,
                            decoration: BoxDecoration(
                              color: _isOnline == true
                                  ? TwamboColors.success.withValues(alpha: 0.15)
                                  : TwamboColors.line,
                              border: Border.all(
                                color: _isOnline == true ? TwamboColors.success : TwamboColors.textSecondary,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              alignment: _isOnline == true ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                width: 20, height: 20,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: _isOnline == true ? TwamboColors.success : TwamboColors.textSecondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  )),

                  // ── Map ───────────────────────────────────────────────────
                  SliverToBoxAdapter(child: _HomeMap(trips: trips, active: active)),

                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  // ── Active trip ─────────────────────────────────────────
                  if (active.isNotEmpty) ...[
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Text('ACTIVE TRIP', style: GoogleFonts.spaceGrotesk(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: TwamboColors.success, letterSpacing: 2)),
                    )),
                    SliverList(delegate: SliverChildBuilderDelegate(
                      (_, i) => _ActiveTripCard(
                        trip: active[i],
                        driverId: user?.id ?? 0,
                      ),
                      childCount: active.length,
                    )),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],

                  // ── Upcoming city trips ───────────────────────────────────
                  if (upcoming.isNotEmpty) ...[
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Text('UPCOMING CITY (${upcoming.length})', style: GoogleFonts.spaceGrotesk(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: TwamboColors.textSecondary, letterSpacing: 2)),
                    )),
                    SliverList(delegate: SliverChildBuilderDelegate(
                      (_, i) => _UpcomingTripCard(trip: upcoming[i]),
                      childCount: upcoming.length,
                    )),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],

                  // ── Long distance trips ───────────────────────────────────
                  if (hikePlanned.isNotEmpty) ...[
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Row(children: [
                        Container(
                          width: 3, height: 12,
                          color: const Color(0xFFE65100),
                          margin: const EdgeInsets.only(right: 8),
                        ),
                        Text('LONG DISTANCE (${hikePlanned.length})', style: GoogleFonts.spaceGrotesk(
                            fontSize: 9, fontWeight: FontWeight.w800,
                            color: const Color(0xFFE65100), letterSpacing: 2)),
                      ]),
                    )),
                    SliverList(delegate: SliverChildBuilderDelegate(
                      (_, i) => _HikeTripCard(trip: hikePlanned[i]),
                      childCount: hikePlanned.length,
                    )),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],

                  // ── Empty state ───────────────────────────────────────────
                  if (active.isEmpty && upcoming.isEmpty && hikePlanned.isEmpty)
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : TwamboColors.surfaceAlt,
                            border: const Border(left: BorderSide(color: TwamboColors.primary, width: 3)),
                          ),
                          child: const Icon(Icons.directions_car_outlined, size: 36, color: TwamboColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        Text('NO TRIPS SCHEDULED', style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: TwamboColors.textSecondary, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text('Create a trip below to start accepting riders',
                            style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
                      ]),
                    )),

                  // ── Action buttons ─────────────────────────────────────────
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.go('/driver/create'),
                            child: Container(
                              height: 52,
                              color: TwamboColors.primary,
                              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.add, size: 18, color: TwamboColors.textPrimary),
                                const SizedBox(width: 6),
                                Text('NEW CITY TRIP', style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11, fontWeight: FontWeight.w800,
                                    color: TwamboColors.textPrimary, letterSpacing: 1)),
                              ])),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.go('/driver/create', extra: 'hike'),
                            child: Container(
                              height: 52,
                              color: const Color(0xFFE65100),
                              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.route_rounded, size: 18, color: Colors.white),
                                const SizedBox(width: 6),
                                Text('LONG DISTANCE', style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: 1)),
                              ])),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => context.go('/driver/recurring'),
                        child: Container(
                          height: 48, width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: TwamboColors.secondary, width: 1.5),
                          ),
                          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.repeat_rounded, size: 16, color: TwamboColors.secondary),
                            const SizedBox(width: 8),
                            Text('RECURRING TRIPS', style: GoogleFonts.spaceGrotesk(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: TwamboColors.secondary, letterSpacing: 1)),
                          ])),
                        ),
                      ),
                    ]),
                  )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Home map ──────────────────────────────────────────────────────────────────

class _HomeMap extends StatelessWidget {
  final List<Trip> trips;
  final List<Trip> active;
  const _HomeMap({required this.trips, required this.active});

  @override
  Widget build(BuildContext context) {
    // Build map center: use active trip origin or first upcoming or default
    LatLng center = _kitwe;
    if (active.isNotEmpty) {
      center = LatLng(active.first.originLat, active.first.originLng);
    } else if (trips.isNotEmpty) {
      center = LatLng(trips.first.originLat, trips.first.originLng);
    }

    // Build polylines for all trips
    final polylines = trips.map((t) {
      final isActive = t.isActive;
      return Polyline(
        points: [LatLng(t.originLat, t.originLng), LatLng(t.destinationLat, t.destinationLng)],
        color: isActive ? TwamboColors.success : TwamboColors.primary.withValues(alpha: 0.6),
        strokeWidth: isActive ? 4 : 2.5,
      );
    }).toList();

    // Build origin markers (pickup points)
    final markers = trips.map((t) => Marker(
          point: LatLng(t.originLat, t.originLng),
          width: 28, height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: t.isActive ? TwamboColors.success : TwamboColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              t.isActive ? Icons.directions_car_rounded : Icons.location_on,
              size: 14, color: t.isActive ? Colors.white : TwamboColors.textPrimary,
            ),
          ),
        )).toList();

    // Destination markers
    final destMarkers = trips.map((t) => Marker(
          point: LatLng(t.destinationLat, t.destinationLng),
          width: 22, height: 22,
          child: Container(
            decoration: const BoxDecoration(
              color: TwamboColors.error, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
            ),
            child: const Icon(Icons.flag_rounded, size: 12, color: Colors.white),
          ),
        )).toList();

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              if (kShowMapTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.twambo.app',
                )
              else
                const ColoredBox(color: Color(0xFFD8DADB), child: SizedBox.expand()),
              if (polylines.isNotEmpty)
                PolylineLayer(polylines: polylines),
              MarkerLayer(markers: [...markers, ...destMarkers]),
            ],
          ),
          // Map legend overlay (bottom-left)
          Positioned(
            bottom: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: Colors.black.withValues(alpha: 0.6),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 3, color: TwamboColors.success),
                  const SizedBox(width: 5),
                  Text('Active', style: GoogleFonts.manrope(fontSize: 9, color: Colors.white70)),
                ]),
                const SizedBox(height: 3),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 3, color: TwamboColors.primary),
                  const SizedBox(width: 5),
                  Text('Scheduled', style: GoogleFonts.manrope(fontSize: 9, color: Colors.white70)),
                ]),
              ]),
            ),
          ),
          // Trip count chip (top-right)
          if (trips.isNotEmpty)
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: Colors.black.withValues(alpha: 0.65),
                child: Text(
                  '${trips.length} TRIP${trips.length == 1 ? '' : 'S'} ON MAP',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 8, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Active Trip Card ──────────────────────────────────────────────────────────

class _ActiveTripCard extends ConsumerWidget {
  final Trip trip;
  final int driverId;
  const _ActiveTripCard({required this.trip, required this.driverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingRequests = ref.watch(_tripPendingCountProvider(trip.id)).whenData((v) => v).value ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: const Border(left: BorderSide(color: TwamboColors.success, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: TwamboColors.success.withValues(alpha: 0.1),
            child: Text('ACTIVE', style: GoogleFonts.spaceGrotesk(
                fontSize: 8, fontWeight: FontWeight.w800,
                color: TwamboColors.success, letterSpacing: 2)),
          ),
          const Spacer(),
          Text('${trip.seatsTaken}/${trip.totalSeats} RIDERS',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, fontWeight: FontWeight.w700, color: TwamboColors.textSecondary)),
        ]),
        const SizedBox(height: 10),
        Text('${trip.originName} → ${trip.destinationName}',
            style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
        const SizedBox(height: 4),
        Text('K${trip.currentSharedFare.toStringAsFixed(0)}/rider · ${trip.mode.toUpperCase()}',
            style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
        if (pendingRequests > 0) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.go('/driver/trip/${trip.id}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              color: TwamboColors.primary,
              child: Row(children: [
                const Icon(Icons.notifications_active_rounded, size: 14, color: Colors.black),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '$pendingRequests INCOMING RIDE REQUEST${pendingRequests > 1 ? 'S' : ''} — TAP TO REVIEW',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: Colors.black, letterSpacing: 1.2),
                )),
                const Icon(Icons.chevron_right, size: 16, color: Colors.black),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(height: 1, color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.line),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _ActionBtn(
            label: 'MANAGE',
            color: pendingRequests > 0 ? TwamboColors.secondary : TwamboColors.primary,
            textColor: pendingRequests > 0 ? Colors.white : TwamboColors.textPrimary,
            onTap: () => context.go('/driver/trip/${trip.id}'),
          )),
          const SizedBox(width: 10),
          Expanded(child: _ActionBtn(
            label: 'BROADCAST GPS',
            color: TwamboColors.secondary,
            textColor: Colors.white,
            onTap: () => context.go('/driver/gps/${trip.id}/$driverId'),
          )),
        ]),
      ]),
    );
  }
}

// ── Hike Trip Card ────────────────────────────────────────────────────────────

class _HikeTripCard extends StatelessWidget {
  final Trip trip;
  const _HikeTripCard({required this.trip});

  static const _orange = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final seatsBooked = trip.seatsTaken;
    final earningsPotential = trip.currentSharedFare * seatsBooked;
    final countdown = _countdown(trip.departureTime);
    final bookingClosed = !trip.bookingWindowOpen;

    return GestureDetector(
      onTap: () => context.go('/driver/trip/${trip.id}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: cardBg,
          border: const Border(left: BorderSide(color: _orange, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: _orange.withValues(alpha: 0.12),
              child: Text('LONG DISTANCE', style: GoogleFonts.spaceGrotesk(
                  fontSize: 7, fontWeight: FontWeight.w800,
                  color: _orange, letterSpacing: 2)),
            ),
            const SizedBox(width: 8),
            if (bookingClosed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                color: TwamboColors.textSecondary.withValues(alpha: 0.12),
                child: Text('BOOKING CLOSED', style: GoogleFonts.spaceGrotesk(
                    fontSize: 7, fontWeight: FontWeight.w700,
                    color: TwamboColors.textSecondary, letterSpacing: 1.5)),
              ),
            const Spacer(),
            Text('$seatsBooked/${trip.totalSeats} BOOKED',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: seatsBooked > 0 ? TwamboColors.success : TwamboColors.textSecondary)),
          ]),
          const SizedBox(height: 10),
          Text('${trip.originName} → ${trip.destinationName}',
              style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 12, color: TwamboColors.textSecondary),
            const SizedBox(width: 4),
            Text(_fmtDateTime(trip.departureTime),
                style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
            if (countdown != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.timer_outlined, size: 12, color: _orange),
              const SizedBox(width: 3),
              Text(countdown,
                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: _orange)),
            ],
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.payments_outlined, size: 12, color: TwamboColors.textSecondary),
            const SizedBox(width: 4),
            Text('K${trip.currentSharedFare.toStringAsFixed(0)}/seat',
                style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
            if (seatsBooked > 0) ...[
              const SizedBox(width: 8),
              Text('· K${earningsPotential.toStringAsFixed(0)} earnings',
                  style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: TwamboColors.success)),
            ],
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.go('/driver/trip/${trip.id}'),
                child: Container(
                  height: 34, color: _orange,
                  child: Center(child: Text('MANAGE TRIP',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 1))),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  String _fmtDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}  $h:$m';
  }

  String? _countdown(DateTime departure) {
    final diff = departure.toLocal().difference(DateTime.now());
    if (diff.isNegative) return null;
    if (diff.inDays >= 2) return '${diff.inDays}d away';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h >= 1) return m > 0 ? '${h}h ${m}m' : '${h}h';
    return '${diff.inMinutes}m';
  }
}

// ── Upcoming Trip Card ────────────────────────────────────────────────────────

class _UpcomingTripCard extends StatelessWidget {
  final Trip trip;
  const _UpcomingTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return GestureDetector(
      onTap: () => context.go('/driver/trip/${trip.id}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: cardBg,
          border: const Border(left: BorderSide(color: TwamboColors.primary, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${trip.originName} → ${trip.destinationName}',
                style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 11, color: TwamboColors.textSecondary),
              const SizedBox(width: 4),
              Text(_fmtTime(trip.departureTime),
                  style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
              const SizedBox(width: 12),
              const Icon(Icons.event_seat_rounded, size: 11, color: TwamboColors.textSecondary),
              const SizedBox(width: 4),
              Text('${trip.seatsTaken}/${trip.totalSeats}',
                  style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
            ]),
          ])),
          Text('K${trip.currentSharedFare.toStringAsFixed(0)}',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w800, color: TwamboColors.primary)),
        ]),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}  $h:$m';
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38, color: color,
        child: Center(child: Text(label,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 10, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 1))),
      ),
    );
  }
}

