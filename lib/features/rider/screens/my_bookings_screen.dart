import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/booking.dart';
import '../../../dev/mock_trips.dart' show kUseMockData, mockBookings, cancelMockBooking;
import '../../../shared/rating_dialog.dart';
import '../../../shared/rider_nav_bar.dart';
import '../../../shared/theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final myBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 300));
    return mockBookings;
  }
  final List<Booking> all = [];

  final bookingsResp = await ApiClient.dio.get(Endpoints.myBookings);
  final bookingsRaw = bookingsResp.data is List
      ? bookingsResp.data as List
      : (bookingsResp.data['results'] as List? ?? []);
  all.addAll(bookingsRaw.map<Booking>((j) => Booking.fromJson(j as Map<String, dynamic>)));

  try {
    final requestsResp = await ApiClient.dio.get(Endpoints.myRideRequests);
    final requestsRaw = requestsResp.data is List
        ? requestsResp.data as List
        : (requestsResp.data['results'] as List? ?? []);
    all.addAll(requestsRaw.map<Booking>((j) => Booking.fromJson(j as Map<String, dynamic>)));
  } catch (_) {}

  all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return all;
});

// ── Screen ────────────────────────────────────────────────────────────────────

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidate(myBookingsProvider));
    // Poll every 12s while screen is open — updates hike request status when driver accepts
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) { ref.invalidate(myBookingsProvider); }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(myBookingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const RiderNavBar(currentIndex: 1),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            color: cardBg,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  Container(width: 4, height: 24, color: TwamboColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text('MY TRIPS',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 18, fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : TwamboColors.textPrimary))),
                  GestureDetector(
                    onTap: () => ref.invalidate(myBookingsProvider),
                    child: const Icon(Icons.refresh_rounded, size: 20, color: TwamboColors.secondary),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // Tabs
              bookingsAsync.maybeWhen(
                data: (all) {
                  final active = all.where((b) => b.isActive).length;
                  final history = all.where((b) => !b.isActive).length;
                  return _TabBar(controller: _tabs, activeCount: active, historyCount: history, isDark: isDark);
                },
                orElse: () => _TabBar(controller: _tabs, activeCount: 0, historyCount: 0, isDark: isDark),
              ),
            ]),
          ),

          // ── Tab content ──────────────────────────────────────────────────
          Expanded(
            child: bookingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
              error: (e, _) => Center(child: Text('Error: $e',
                  style: GoogleFonts.manrope(color: TwamboColors.error))),
              data: (all) {
                final active = all.where((b) => b.isActive).toList();
                final history = all.where((b) => !b.isActive).toList();
                return TabBarView(
                  controller: _tabs,
                  children: [
                    _BookingList(bookings: active, emptyLabel: 'NO ACTIVE TRIPS',
                        emptyHint: 'Search a ride or send a hike request', isDark: isDark, ref: ref),
                    _BookingList(bookings: history, emptyLabel: 'NO TRIP HISTORY',
                        emptyHint: 'Completed and cancelled rides appear here', isDark: isDark, ref: ref),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  final int activeCount;
  final int historyCount;
  final bool isDark;
  const _TabBar({required this.controller, required this.activeCount,
      required this.historyCount, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      indicatorColor: TwamboColors.primary,
      indicatorWeight: 3,
      labelStyle: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
      unselectedLabelStyle: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1),
      labelColor: TwamboColors.primary,
      unselectedLabelColor: TwamboColors.textSecondary,
      tabs: [
        Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('ACTIVE'),
          if (activeCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              color: TwamboColors.primary,
              child: Text('$activeCount',
                  style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
                      color: TwamboColors.textPrimary)),
            ),
          ],
        ])),
        Tab(child: Text('HISTORY ($historyCount)')),
      ],
    );
  }
}

// ── Booking list ──────────────────────────────────────────────────────────────

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final String emptyLabel;
  final String emptyHint;
  final bool isDark;
  final WidgetRef ref;
  const _BookingList({required this.bookings, required this.emptyLabel,
      required this.emptyHint, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : TwamboColors.surfaceAlt,
            border: const Border(left: BorderSide(color: TwamboColors.primary, width: 3)),
          ),
          child: const Icon(Icons.bookmark_border, size: 32, color: TwamboColors.textSecondary),
        ),
        const SizedBox(height: 14),
        Text(emptyLabel, style: GoogleFonts.spaceGrotesk(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: TwamboColors.textSecondary, letterSpacing: 2)),
        const SizedBox(height: 4),
        Text(emptyHint, style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: bookings.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _BookingCard(booking: bookings[i], ref: ref, isDark: isDark),
      ),
    );
  }
}

// ── Booking card ──────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final WidgetRef ref;
  final bool isDark;
  const _BookingCard({required this.booking, required this.ref, required this.isDark});

  String _fmtDeparture(DateTime dt) {
    final local = dt.toLocal();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${days[local.weekday - 1]} ${local.day} ${months[local.month - 1]} · $h:$m';
  }

  String? _countdown(DateTime departure) {
    final diff = departure.toLocal().difference(DateTime.now());
    if (diff.isNegative) return null;
    if (diff.inDays >= 2) return 'Departing in ${diff.inDays} days';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h >= 1) return m > 0 ? 'Departing in ${h}h ${m}m' : 'Departing in ${h}h';
    return 'Departing in ${diff.inMinutes}m';
  }

  Color get _borderColor {
    switch (booking.status) {
      case 'confirmed': return TwamboColors.success;
      case 'pending':   return TwamboColors.primary;
      case 'cancelled': return TwamboColors.error;
      case 'completed': return TwamboColors.textSecondary;
      case 'no_show':   return TwamboColors.error;
      default:          return TwamboColors.secondary;
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
        content: Text('Cancel this booking or request?',
            style: GoogleFonts.manrope(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, cancel',
                style: TextStyle(color: TwamboColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) { return; }
    if (kUseMockData) {
      cancelMockBooking(booking.id);
    } else if (booking.tripId < 0) {
      await ApiClient.dio.post(Endpoints.cancelRideRequest(booking.id));
    } else {
      await ApiClient.dio.post(Endpoints.cancelBooking(booking.id));
    }
    ref.invalidate(myBookingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final isPending = booking.status == 'pending';
    final isAccepted = booking.status == 'confirmed' && booking.tripId > 0;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(left: BorderSide(color: _borderColor, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Route + trip type badge + status badge
        Row(children: [
          Expanded(child: Text(
            '${booking.tripOrigin} → ${booking.tripDestination}',
            style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800, color: textColor),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          )),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: booking.isHike
                ? const Color(0xFFE65100).withValues(alpha: 0.10)
                : TwamboColors.primary.withValues(alpha: 0.08),
            child: Text(booking.isHike ? 'LONG DIST' : 'CITY',
                style: GoogleFonts.spaceGrotesk(fontSize: 7, fontWeight: FontWeight.w800,
                    color: booking.isHike ? const Color(0xFFE65100) : TwamboColors.primary,
                    letterSpacing: 0.8)),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: _borderColor.withValues(alpha: 0.12),
            child: Text(booking.status.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w800,
                    color: _borderColor, letterSpacing: 1.5)),
          ),
        ]),
        const SizedBox(height: 4),

        // Departure time + countdown (hike only)
        Row(children: [
          const Icon(Icons.access_time_rounded, size: 12, color: TwamboColors.textSecondary),
          const SizedBox(width: 4),
          Text(_fmtDeparture(booking.tripDeparture),
              style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
          if (booking.isHike && _countdown(booking.tripDeparture) != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.timer_outlined, size: 11, color: Color(0xFFE65100)),
            const SizedBox(width: 3),
            Text(_countdown(booking.tripDeparture)!,
                style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFFE65100),
                    fontWeight: FontWeight.w600)),
          ],
        ]),
        const SizedBox(height: 6),

        // Driver name + contact button
        if (booking.driverName.isNotEmpty) Row(children: [
          const Icon(Icons.person_outline, size: 12, color: TwamboColors.textSecondary),
          const SizedBox(width: 4),
          Expanded(child: Text(booking.driverName,
              style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary))),
          if (booking.isConfirmed && booking.driverPhone.isNotEmpty)
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => _DriverContactSheet(booking: booking),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                color: TwamboColors.primary.withValues(alpha: 0.1),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.phone_outlined, size: 11, color: TwamboColors.primary),
                  const SizedBox(width: 4),
                  Text('CONTACT', style: GoogleFonts.spaceGrotesk(
                      fontSize: 8, fontWeight: FontWeight.w800,
                      color: TwamboColors.primary, letterSpacing: 1)),
                ]),
              ),
            ),
        ]),

        // Pickup
        if (booking.pickupName.isNotEmpty) Row(children: [
          const Icon(Icons.pin_drop_outlined, size: 12, color: TwamboColors.secondary),
          const SizedBox(width: 4),
          Expanded(child: Text('Board at: ${booking.pickupName}',
              style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        // For hike trips, show the driver's departure meeting point prominently
        if (booking.isHike && booking.tripOrigin.isNotEmpty) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: const Color(0xFFE65100).withValues(alpha: 0.07),
            child: Row(children: [
              const Icon(Icons.departure_board_rounded, size: 12, color: Color(0xFFE65100)),
              const SizedBox(width: 6),
              Expanded(child: Text('Departs from: ${booking.tripOrigin}',
                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600,
                      color: const Color(0xFFE65100)),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ],

        // Pending hike request — broadcasting indicator
        if (isPending && booking.tripId < 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            color: TwamboColors.primary.withValues(alpha: 0.08),
            child: Row(children: [
              const SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: TwamboColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: Text('Broadcasting to nearby drivers…',
                  style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.primary,
                      fontWeight: FontWeight.w600))),
            ]),
          ),
        ],

        // Accepted hike — confirmation banner
        if (isAccepted && booking.driverName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            color: TwamboColors.success.withValues(alpha: 0.08),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 16, color: TwamboColors.success),
              const SizedBox(width: 8),
              Expanded(child: Text('${booking.driverName} accepted your request!',
                  style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.success,
                      fontWeight: FontWeight.w600))),
            ]),
          ),
        ],

        const SizedBox(height: 10),
        Container(height: 1, color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.line),
        const SizedBox(height: 10),

        // Fare + action buttons
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('K${booking.amountDue.toStringAsFixed(0)} cash',
                style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w800,
                    color: TwamboColors.primary)),
            if (booking.detourFee > 0)
              Text('incl. K${booking.detourFee.toStringAsFixed(0)} detour fee',
                  style: GoogleFonts.manrope(fontSize: 10, color: const Color(0xFFE65100))),
          ]),
          Row(children: [
            if (booking.isConfirmed && booking.tripId > 0)
              GestureDetector(
                onTap: () => context.go(
                  '/tracking/${booking.tripId}/${booking.driverId}'
                  '?driverName=${Uri.encodeComponent(booking.driverName)}'
                  '&originName=${Uri.encodeComponent(booking.pickupName)}'
                  '&pickupLat=${booking.pickupLat}&pickupLng=${booking.pickupLng}',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: TwamboColors.secondary,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.my_location, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('TRACK', style: GoogleFonts.spaceGrotesk(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 1)),
                  ]),
                ),
              ),
          if (booking.isCompleted && booking.tripId > 0)
              GestureDetector(
                onTap: () async {
                  // Check if already rated
                  try {
                    final resp = await ApiClient.dio.get(Endpoints.myRatingForBooking(booking.id));
                    final alreadyRated = resp.data['rated'] as bool? ?? false;
                    if (alreadyRated && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('You already rated this trip'),
                        behavior: SnackBarBehavior.floating,
                      ));
                      return;
                    }
                  } catch (_) {}
                  if (!context.mounted) { return; }
                  await showRatingDialog(context,
                    bookingId: booking.id,
                    ratedUserName: booking.driverName,
                    ratingAsDriver: false,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: TwamboColors.primary,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_outline_rounded, size: 12, color: TwamboColors.textPrimary),
                    const SizedBox(width: 4),
                    Text('RATE', style: GoogleFonts.spaceGrotesk(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: TwamboColors.textPrimary, letterSpacing: 1)),
                  ]),
                ),
              ),
            if (booking.isActive) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _cancel(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: TwamboColors.error, width: 1.5),
                  ),
                  child: Text('CANCEL', style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: TwamboColors.error, letterSpacing: 1)),
                ),
              ),
            ],
          ]),
        ]),
      ]),
    );
  }
}

// ── Driver contact sheet (rider side) ─────────────────────────────────────────

class _DriverContactSheet extends StatelessWidget {
  final Booking booking;
  const _DriverContactSheet({required this.booking});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final clean = booking.driverPhone.replaceAll(RegExp(r'\s+'), '');
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
              booking.driverName.isNotEmpty ? booking.driverName[0].toUpperCase() : 'D',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 20, fontWeight: FontWeight.w800, color: TwamboColors.primary),
            )),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(booking.driverName, style: GoogleFonts.spaceGrotesk(
                fontSize: 15, fontWeight: FontWeight.w700, color: TwamboColors.textPrimary)),
            Text('Your Driver', style: GoogleFonts.manrope(
                fontSize: 12, color: TwamboColors.textSecondary)),
          ])),
        ]),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: const Color(0xFFF5F5F5),
          child: Row(children: [
            const Icon(Icons.phone_outlined, size: 16, color: TwamboColors.textSecondary),
            const SizedBox(width: 10),
            Text(booking.driverPhone, style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w600, color: TwamboColors.textPrimary)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ContactBtn(
            icon: Icons.call,
            label: 'Call',
            color: TwamboColors.success,
            onTap: () => _launch('tel:$clean'),
          )),
          const SizedBox(width: 10),
          Expanded(child: _ContactBtn(
            icon: Icons.message_outlined,
            label: 'SMS',
            color: TwamboColors.primary,
            onTap: () => _launch('sms:$clean'),
          )),
          const SizedBox(width: 10),
          Expanded(child: _ContactBtn(
            icon: Icons.chat_bubble_outline,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () => _launch('https://wa.me/${clean.replaceAll('+', '')}'),
          )),
        ]),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _ContactBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContactBtn({required this.icon, required this.label, required this.color, required this.onTap});

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
