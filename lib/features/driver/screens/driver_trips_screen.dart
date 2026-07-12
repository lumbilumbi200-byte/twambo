import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/trip.dart';
import '../../../shared/driver_nav_bar.dart';
import '../../../shared/theme.dart';
import 'driver_home_screen.dart' show driverTripsProvider;

class DriverTripsScreen extends ConsumerStatefulWidget {
  const DriverTripsScreen({super.key});
  @override
  ConsumerState<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends ConsumerState<DriverTripsScreen> {
  @override
  void initState() {
    super.initState();
    // Always fetch fresh data when this tab is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: unused_result
      ref.refresh(driverTripsProvider.future);
    });
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              color: cardBg,
              border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MY TRIPS', style: GoogleFonts.spaceGrotesk(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: TwamboColors.textSecondary, letterSpacing: 2)),
              Text('All your trips', style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
            ]),
          ),

          // ── Trip list ─────────────────────────────────────────────────
          Expanded(child: tripsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (trips) {
              if (trips.isEmpty) {
                return RefreshIndicator(
                  color: TwamboColors.primary,
                  onRefresh: () => ref.refresh(driverTripsProvider.future),
                  child: ListView(
                    children: [
                      SizedBox(
                        height: 300,
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.directions_car_outlined, size: 48, color: TwamboColors.textSecondary),
                          const SizedBox(height: 16),
                          Text('NO TRIPS YET', style: GoogleFonts.spaceGrotesk(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: TwamboColors.textSecondary, letterSpacing: 2)),
                          const SizedBox(height: 4),
                          Text('Create a trip to get started',
                              style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
                        ])),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: TwamboColors.primary,
                onRefresh: () => ref.refresh(driverTripsProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: trips.length,
                  itemBuilder: (_, i) => _TripRow(trip: trips[i], isDark: isDark),
                ),
              );
            },
          )),
        ]),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final Trip trip;
  final bool isDark;
  const _TripRow({required this.trip, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final statusColor = _statusColor(trip.status);

    return GestureDetector(
      onTap: () => context.push('/driver/trip/${trip.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(left: BorderSide(color: statusColor, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          // Status dot column
          Container(
            width: 36, height: 36,
            color: statusColor.withValues(alpha: 0.12),
            child: Icon(_statusIcon(trip.status), size: 18, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: statusColor.withValues(alpha: 0.12),
                child: Text(trip.status.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                    fontSize: 8, fontWeight: FontWeight.w800,
                    color: statusColor, letterSpacing: 1.2)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: TwamboColors.textSecondary.withValues(alpha: 0.08),
                child: Text(trip.mode.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                    fontSize: 8, fontWeight: FontWeight.w700,
                    color: TwamboColors.textSecondary, letterSpacing: 1)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: trip.isHike
                    ? const Color(0xFFE65100).withValues(alpha: 0.10)
                    : TwamboColors.primary.withValues(alpha: 0.08),
                child: Text(trip.isHike ? 'LONG DIST' : 'CITY',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 8, fontWeight: FontWeight.w800,
                        color: trip.isHike ? const Color(0xFFE65100) : TwamboColors.primary,
                        letterSpacing: 1)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(trip.originName, style: GoogleFonts.manrope(
                fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.arrow_downward_rounded, size: 10, color: TwamboColors.textSecondary),
              const SizedBox(width: 3),
              Expanded(child: Text(trip.destinationName, style: GoogleFonts.manrope(
                  fontSize: 12, color: TwamboColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Text(
              _fmtTime(trip.departureTime),
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: TwamboColors.textSecondary),
            ),
          ])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${trip.seatsTaken}/${trip.totalSeats}', style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w800, color: TwamboColors.primary)),
            Text('riders', style: GoogleFonts.manrope(
                fontSize: 10, color: TwamboColors.textSecondary)),
            const SizedBox(height: 6),
            const Icon(Icons.chevron_right_rounded, size: 18, color: TwamboColors.textSecondary),
          ]),
        ]),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return TwamboColors.success;
      case 'completed': return TwamboColors.secondary;
      case 'cancelled': return TwamboColors.error;
      default: return TwamboColors.primary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'active': return Icons.directions_car_rounded;
      case 'completed': return Icons.check_circle_outline_rounded;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.schedule_rounded;
    }
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    return '$d  $h:$m';
  }
}
