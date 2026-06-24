import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../dev/mock_trips.dart';
import '../../../shared/driver_nav_bar.dart';
import '../../../shared/theme.dart';
import 'driver_home_screen.dart' show driverTripsProvider;

class _Passenger {
  final int id;
  final String riderName;
  final String riderPhone;
  final String pickupName;
  final String dropoffName;
  final int seatsBooked;
  final double amountDue;
  final String status;

  const _Passenger({
    required this.id,
    required this.riderName,
    required this.riderPhone,
    required this.pickupName,
    required this.dropoffName,
    required this.seatsBooked,
    required this.amountDue,
    required this.status,
  });

  factory _Passenger.fromJson(Map<String, dynamic> j) => _Passenger(
        id: j['id'],
        riderName: j['rider_name'] ?? 'Passenger',
        riderPhone: j['rider_phone'] ?? '',
        pickupName: j['pickup_name'] ?? '',
        dropoffName: j['dropoff_name'] ?? '',
        seatsBooked: j['seats_booked'] ?? 1,
        amountDue: double.parse((j['amount_due'] ?? '0').toString()),
        status: j['status'] ?? 'confirmed',
      );
}

final _passengersProvider = FutureProvider.family<List<_Passenger>, int>((ref, tripId) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 200));
    return (mockPassengers[tripId] ?? [])
        .map<_Passenger>((j) => _Passenger.fromJson(j))
        .toList();
  }
  final resp = await ApiClient.dio.get(Endpoints.tripBookings(tripId));
  final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
  return raw.map<_Passenger>((j) => _Passenger.fromJson(j as Map<String, dynamic>)).toList();
});

class DriverRidersScreen extends ConsumerWidget {
  const DriverRidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(driverTripsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const DriverNavBar(currentIndex: 2),
      body: SafeArea(
        bottom: false,
        child: tripsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (trips) {
            final active = trips.where((t) => t.isActive).toList();

            return Column(children: [
              // ── Header ───────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('MY RIDERS', style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: TwamboColors.textSecondary, letterSpacing: 2)),
                  Text(
                    active.isEmpty
                        ? 'No active trip'
                        : '${active.first.originName} → ${active.first.destinationName}',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),

              // ── Body ─────────────────────────────────────────────────────
              Expanded(child: active.isEmpty
                  ? _EmptyState(isDark: isDark)
                  : _PassengerList(tripId: active.first.id, isDark: isDark)),
            ]);
          },
        ),
      ),
    );
  }
}

// ── Passenger list (loads when active trip exists) ─────────────────────────

class _PassengerList extends ConsumerWidget {
  final int tripId;
  final bool isDark;
  const _PassengerList({required this.tripId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passengersAsync = ref.watch(_passengersProvider(tripId));

    return passengersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: TwamboColors.error))),
      data: (passengers) {
        if (passengers.isEmpty) {
          return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.group_outlined, size: 48, color: TwamboColors.textSecondary),
            const SizedBox(height: 12),
            Text('NO RIDERS YET', style: GoogleFonts.spaceGrotesk(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: TwamboColors.textSecondary, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text('Riders will appear here when they book',
                style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
          ]);
        }

        return RefreshIndicator(
          color: TwamboColors.primary,
          onRefresh: () => ref.refresh(_passengersProvider(tripId).future),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: passengers.length,
            itemBuilder: (_, i) => _PassengerCard(p: passengers[i], isDark: isDark),
          ),
        );
      },
    );
  }
}

// ── Passenger card ────────────────────────────────────────────────────────

class _PassengerCard extends StatelessWidget {
  final _Passenger p;
  final bool isDark;
  const _PassengerCard({required this.p, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final statusColor = _statusColor(p.status);
    final initial = p.riderName.isNotEmpty ? p.riderName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          color: TwamboColors.primary.withValues(alpha: 0.15),
          child: Center(child: Text(initial,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w800, color: TwamboColors.primary))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p.riderName,
                style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: textColor))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: statusColor.withValues(alpha: 0.1),
              child: Text(p.status.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 8, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 1.5)),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 11, color: TwamboColors.textSecondary),
            const SizedBox(width: 3),
            Expanded(child: Text(p.pickupName,
                style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          if (p.dropoffName.isNotEmpty && p.dropoffName != p.pickupName) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.flag_outlined, size: 11, color: TwamboColors.textSecondary),
              const SizedBox(width: 3),
              Expanded(child: Text(p.dropoffName,
                  style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ])),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('K${p.amountDue.toStringAsFixed(0)}',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w800, color: TwamboColors.primary)),
          if (p.seatsBooked > 1) ...[
            const SizedBox(height: 2),
            Text('${p.seatsBooked} seats',
                style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
          ],
        ]),
      ]),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return TwamboColors.success;
      case 'cancelled': return TwamboColors.error;
      case 'no_show': return TwamboColors.accent;
      default: return TwamboColors.secondary;
    }
  }
}

// ── Empty state (no active trip) ─────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : TwamboColors.surfaceAlt,
          border: const Border(left: BorderSide(color: TwamboColors.primary, width: 3)),
        ),
        child: const Icon(Icons.people_outline, size: 36, color: TwamboColors.textSecondary),
      ),
      const SizedBox(height: 16),
      Text('NO ACTIVE TRIP', style: GoogleFonts.spaceGrotesk(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: TwamboColors.textSecondary, letterSpacing: 2)),
      const SizedBox(height: 4),
      Text('Start a trip to see your riders here',
          style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
    ]));
  }
}
