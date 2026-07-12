import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../dev/all_places.dart';
import '../../../dev/twambo_place.dart';
import '../../../dev/mock_trips.dart';
import '../../../shared/place_picker.dart';
import '../../../shared/theme.dart';

class RecurringTrip {
  final int id;
  final String originName;
  final String destinationName;
  final String departureTimeStr;
  final List<String> days;
  final int totalSeats;
  final int minimumRiders;
  final String mode;
  final bool isActive;

  const RecurringTrip({
    required this.id,
    required this.originName,
    required this.destinationName,
    required this.departureTimeStr,
    required this.days,
    required this.totalSeats,
    required this.minimumRiders,
    required this.mode,
    required this.isActive,
  });

  factory RecurringTrip.fromJson(Map<String, dynamic> j) => RecurringTrip(
        id: j['id'] as int,
        originName: j['origin_name'] as String? ?? '',
        destinationName: j['destination_name'] as String? ?? '',
        departureTimeStr: j['departure_time'] as String? ?? '',
        days: List<String>.from(j['days_of_week'] ?? []),
        totalSeats: (j['total_seats'] as int?) ?? 1,
        minimumRiders: (j['minimum_riders'] as int?) ?? 1,
        mode: j['mode'] as String? ?? 'shared',
        isActive: j['is_active'] as bool? ?? true,
      );
}

final recurringTripsProvider = FutureProvider.autoDispose<List<RecurringTrip>>((ref) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 250));
    return mockRecurringTrips
        .map((j) => RecurringTrip.fromJson(j))
        .toList();
  }
  final resp = await ApiClient.dio.get(Endpoints.recurringTrips);
  final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
  return raw.map<RecurringTrip>((j) => RecurringTrip.fromJson(j as Map<String, dynamic>)).toList();
});

class RecurringTripsScreen extends ConsumerWidget {
  const RecurringTripsScreen({super.key});

  static const _dayLabels = {
    'monday': 'Mon', 'tuesday': 'Tue', 'wednesday': 'Wed',
    'thursday': 'Thu', 'friday': 'Fri', 'saturday': 'Sat', 'sunday': 'Sun',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E2E) : TwamboColors.line;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final tripsAsync = ref.watch(recurringTripsProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: Column(children: [
        // ── Header ────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            GestureDetector(
              onTap: () => context.canPop() ? context.pop() : context.go('/driver'),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: cardBg, border: Border.all(color: borderColor),
                ),
                child: Icon(Icons.arrow_back_ios_new, size: 16, color: textColor),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RECURRING TRIPS', style: GoogleFonts.spaceGrotesk(
                  fontSize: 20, fontWeight: FontWeight.w800, color: textColor,
                  letterSpacing: 0.5)),
              Text('Templates auto-generate daily trips', style: GoogleFonts.manrope(
                  fontSize: 11, color: TwamboColors.textSecondary)),
            ])),
            GestureDetector(
              onTap: () => _showCreateSheet(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: TwamboColors.primary,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add, size: 16, color: TwamboColors.textPrimary),
                  const SizedBox(width: 4),
                  Text('NEW', style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: TwamboColors.textPrimary, letterSpacing: 1)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Trip list ─────────────────────────────────────────────────────────
        Expanded(child: tripsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
          error: (e, _) => Center(child: Text('Error: $e', style: GoogleFonts.manrope(
              color: TwamboColors.error, fontSize: 13))),
          data: (trips) => trips.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: const Icon(Icons.repeat, size: 32, color: TwamboColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text('NO TEMPLATES YET', style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: TwamboColors.textSecondary, letterSpacing: 1.5)),
                  const SizedBox(height: 6),
                  Text('Create a template and trips auto-generate every day',
                      style: GoogleFonts.manrope(
                          fontSize: 12, color: TwamboColors.textSecondary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _showCreateSheet(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      color: TwamboColors.primary,
                      child: Text('CREATE FIRST TEMPLATE', style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: TwamboColors.textPrimary, letterSpacing: 1.5)),
                    ),
                  ),
                ]))
              : RefreshIndicator(
                  color: TwamboColors.primary,
                  onRefresh: () => ref.refresh(recurringTripsProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: trips.length,
                    itemBuilder: (_, i) => _RecurringCard(
                        trip: trips[i], ref: ref, dayLabels: _dayLabels),
                  ),
                ),
        )),
      ])),
    );
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateRecurringSheet(
        onCreated: () => ref.invalidate(recurringTripsProvider),
      ),
    );
  }
}

// ── Trip card ─────────────────────────────────────────────────────────────────

class _RecurringCard extends StatelessWidget {
  final RecurringTrip trip;
  final WidgetRef ref;
  final Map<String, String> dayLabels;

  const _RecurringCard({required this.trip, required this.ref, required this.dayLabels});

  Future<void> _toggle(BuildContext context) async {
    try {
      if (kUseMockData) {
        toggleMockRecurringTrip(trip.id);
        ref.invalidate(recurringTripsProvider);
        return;
      }
      await ApiClient.dio.post(Endpoints.recurringTripDetail(trip.id));
      ref.invalidate(recurringTripsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update template')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text('Delete template?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
        content: Text('Future trip instances will no longer be auto-created.',
            style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: TwamboColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (kUseMockData) {
        removeMockRecurringTrip(trip.id);
        ref.invalidate(recurringTripsProvider);
        return;
      }
      await ApiClient.dio.delete(Endpoints.recurringTripDetail(trip.id));
      ref.invalidate(recurringTripsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = trip.isActive ? TwamboColors.primary : (isDark ? const Color(0xFF2E2E2E) : TwamboColors.line);
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
          top: BorderSide(color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.line),
          right: BorderSide(color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.line),
          bottom: BorderSide(color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.line),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trip.originName, style: GoogleFonts.spaceGrotesk(
                fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
            Row(children: [
              const SizedBox(width: 4),
              Icon(Icons.arrow_downward, size: 10, color: TwamboColors.textSecondary),
              const SizedBox(width: 4),
              Text(trip.destinationName, style: GoogleFonts.manrope(
                  fontSize: 12, color: TwamboColors.textSecondary)),
            ]),
          ])),
          // Active switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: trip.isActive
                ? TwamboColors.success.withValues(alpha: 0.12)
                : (isDark ? const Color(0xFF2E2E2E) : TwamboColors.surfaceAlt),
            child: GestureDetector(
              onTap: () => _toggle(context),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: trip.isActive ? TwamboColors.success : TwamboColors.textSecondary,
                      shape: BoxShape.circle,
                    )),
                const SizedBox(width: 6),
                Text(trip.isActive ? 'ACTIVE' : 'PAUSED',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: trip.isActive ? TwamboColors.success : TwamboColors.textSecondary,
                        letterSpacing: 1)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // Days chips
        Wrap(spacing: 5, runSpacing: 4, children: trip.days.map((d) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          color: trip.isActive
              ? TwamboColors.primary.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt),
          child: Text(dayLabels[d] ?? d, style: GoogleFonts.spaceGrotesk(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: trip.isActive ? TwamboColors.primary : TwamboColors.textSecondary,
              letterSpacing: 0.8)),
        )).toList()),
        const SizedBox(height: 10),

        // Stats row
        Row(children: [
          Icon(Icons.access_time, size: 13, color: TwamboColors.textSecondary),
          const SizedBox(width: 4),
          Text(trip.departureTimeStr, style: GoogleFonts.manrope(
              fontSize: 11, color: TwamboColors.textSecondary)),
          const SizedBox(width: 14),
          Icon(Icons.event_seat, size: 13, color: TwamboColors.textSecondary),
          const SizedBox(width: 4),
          Text('${trip.totalSeats} seats · min ${trip.minimumRiders}',
              style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
          const Spacer(),
          GestureDetector(
            onTap: () => _delete(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.delete_outline, size: 18, color: TwamboColors.error),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Create sheet ──────────────────────────────────────────────────────────────

class _CreateRecurringSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateRecurringSheet({required this.onCreated});

  @override
  State<_CreateRecurringSheet> createState() => _CreateRecurringSheetState();
}

class _CreateRecurringSheetState extends State<_CreateRecurringSheet> {
  TwamboPlace? _origin;
  TwamboPlace? _destination;
  TimeOfDay? _time;
  int _seats = 4;
  int _minRiders = 1;
  String _mode = 'shared';
  String _tripType = 'city';

  final _allDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final _dayLabels = {
    'monday': 'Mon', 'tuesday': 'Tue', 'wednesday': 'Wed',
    'thursday': 'Thu', 'friday': 'Fri', 'saturday': 'Sat', 'sunday': 'Sun',
  };
  final Set<String> _selectedDays = {};
  bool _loading = false;
  String? _error;

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) setState(() => _time = t);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_origin == null || _destination == null) {
      setState(() => _error = 'Choose origin and destination');
      return;
    }
    if (_time == null) {
      setState(() => _error = 'Select a departure time');
      return;
    }
    if (_selectedDays.isEmpty) {
      setState(() => _error = 'Select at least one day');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      if (kUseMockData) {
        await Future.delayed(const Duration(milliseconds: 500));
        addMockRecurringTrip({
          'origin_name': _origin!.name,
          'destination_name': _destination!.name,
          'departure_time': _fmtTime(_time!),
          'days_of_week': _selectedDays.toList(),
          'total_seats': _seats,
          'minimum_riders': _minRiders,
          'mode': _mode,
          'is_active': true,
        });
        widget.onCreated();
        if (mounted) Navigator.pop(context);
        return;
      }
      await ApiClient.dio.post(Endpoints.recurringTrips, data: {
        'origin_name': _origin!.name,
        'origin_lat': double.parse(_origin!.lat.toStringAsFixed(6)),
        'origin_lng': double.parse(_origin!.lng.toStringAsFixed(6)),
        'destination_name': _destination!.name,
        'destination_lat': double.parse(_destination!.lat.toStringAsFixed(6)),
        'destination_lng': double.parse(_destination!.lng.toStringAsFixed(6)),
        'departure_time': '${_fmtTime(_time!)}:00',
        'days_of_week': _selectedDays.toList(),
        'total_seats': _seats,
        'minimum_riders': _minRiders,
        'mode': _mode,
        'trip_type': _tripType,
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      String msg = 'Failed to create template';
      try { msg = (e as dynamic).response?.data?.toString() ?? msg; } catch (_) {}
      setState(() { _loading = false; _error = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E2E) : TwamboColors.line;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.92,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
      ),
      child: Column(children: [
        // Handle + header
        const SizedBox(height: 8),
        Container(width: 36, height: 4, color: TwamboColors.line),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('NEW TEMPLATE', style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: textColor, letterSpacing: 0.5)),
              Text('Auto-generates trips on selected days', style: GoogleFonts.manrope(
                  fontSize: 11, color: TwamboColors.textSecondary)),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt,
                  border: Border.all(color: borderColor),
                ),
                child: Icon(Icons.close, size: 16, color: textColor),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Divider(color: borderColor, height: 1),

        // Form body
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Route
            Text('ROUTE', style: GoogleFonts.spaceGrotesk(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: TwamboColors.primary, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            PlacePicker(
              label: 'ORIGIN',
              placeholder: 'Starting point',
              icon: Icons.trip_origin,
              selected: _origin,
              places: _tripType == 'hike' ? allTwamboPlaces() : kitweTwamboPlaces(),
              cityLabel: _tripType == 'hike' ? 'all cities' : 'Kitwe',
              onSelected: (p) => setState(() => _origin = p),
            ),
            const SizedBox(height: 10),
            PlacePicker(
              label: 'DESTINATION',
              placeholder: 'End point',
              icon: Icons.flag_outlined,
              selected: _destination,
              places: _tripType == 'hike' ? allTwamboPlaces() : kitweTwamboPlaces(),
              cityLabel: _tripType == 'hike' ? 'all cities' : 'Kitwe',
              onSelected: (p) => setState(() => _destination = p),
            ),
            const SizedBox(height: 18),

            // Departure time
            Text('DEPARTURE TIME', style: GoogleFonts.spaceGrotesk(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: TwamboColors.secondary, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt,
                  border: Border.all(
                    color: _time != null ? TwamboColors.secondary : borderColor,
                    width: _time != null ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.access_time, size: 18,
                      color: _time != null ? TwamboColors.secondary : TwamboColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _time == null ? 'Tap to choose departure time' : _fmtTime(_time!),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: _time != null ? FontWeight.w600 : FontWeight.w400,
                      color: _time != null ? textColor : TwamboColors.textSecondary,
                    ),
                  )),
                  Icon(Icons.chevron_right, size: 18, color: TwamboColors.textSecondary),
                ]),
              ),
            ),
            const SizedBox(height: 18),

            // Days
            Text('REPEAT ON', style: GoogleFonts.spaceGrotesk(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: TwamboColors.accent, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _allDays.map((d) {
              final sel = _selectedDays.contains(d);
              return GestureDetector(
                onTap: () => setState(() => sel ? _selectedDays.remove(d) : _selectedDays.add(d)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? TwamboColors.primary : (isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt),
                    border: Border.all(
                      color: sel ? TwamboColors.primary : borderColor,
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Text(_dayLabels[d]!, style: GoogleFonts.spaceGrotesk(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: sel ? TwamboColors.textPrimary : TwamboColors.textSecondary,
                      letterSpacing: 0.5)),
                ),
              );
            }).toList()),
            const SizedBox(height: 18),

            // Capacity
            Text('CAPACITY', style: GoogleFonts.spaceGrotesk(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: TwamboColors.success, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _SheetCounterField(
                label: 'TOTAL SEATS', value: _seats, min: 1, max: 14,
                onChanged: (v) => setState(() => _seats = v),
              )),
              const SizedBox(width: 12),
              Expanded(child: _SheetCounterField(
                label: 'MIN. RIDERS', value: _minRiders, min: 1, max: _seats,
                onChanged: (v) => setState(() => _minRiders = v),
              )),
            ]),
            const SizedBox(height: 18),

            // Trip type
            Text('TRIP TYPE', style: GoogleFonts.spaceGrotesk(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: TwamboColors.primary, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _SheetModeChip(
                label: 'City', icon: Icons.location_city_outlined,
                active: _tripType == 'city',
                activeColor: TwamboColors.primary,
                onTap: () => setState(() { _tripType = 'city'; _origin = null; _destination = null; }),
              )),
              const SizedBox(width: 8),
              Expanded(child: _SheetModeChip(
                label: 'Long Distance', icon: Icons.route_outlined,
                active: _tripType == 'hike',
                activeColor: const Color(0xFFE65100),
                onTap: () => setState(() { _tripType = 'hike'; _origin = null; _destination = null; }),
              )),
            ]),
            const SizedBox(height: 18),

            // Pricing mode
            Text('PRICING MODE', style: GoogleFonts.spaceGrotesk(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: TwamboColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _SheetModeChip(label: 'Shared', icon: Icons.people_outline, active: _mode == 'shared', onTap: () => setState(() => _mode = 'shared'))),
              const SizedBox(width: 8),
              Expanded(child: _SheetModeChip(label: 'Private', icon: Icons.person_outline, active: _mode == 'private', onTap: () => setState(() => _mode = 'private'))),
            ]),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: TwamboColors.error, width: 3)),
                  color: Color(0x0FD32F2F),
                ),
                child: Text(_error!, style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.error)),
              ),
            ],

            const SizedBox(height: 24),
            GestureDetector(
              onTap: _loading ? null : _submit,
              child: Container(
                height: 52,
                color: TwamboColors.primary,
                alignment: Alignment.center,
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text('CREATE TEMPLATE', style: GoogleFonts.spaceGrotesk(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: TwamboColors.textPrimary, letterSpacing: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        )),
      ]),
    );
  }
}

class _SheetCounterField extends StatelessWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _SheetCounterField({required this.label, required this.value,
      required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: TwamboColors.textSecondary, letterSpacing: 1.5)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt,
          border: Border.all(color: isDark ? const Color(0xFF3E3E3E) : TwamboColors.line),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: value > min ? () => onChanged(value - 1) : null,
            child: Container(width: 38, height: 42, alignment: Alignment.center,
                child: Icon(Icons.remove, size: 16,
                    color: value > min ? TwamboColors.textSecondary : TwamboColors.line)),
          ),
          Expanded(child: Text('$value', textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : TwamboColors.textPrimary))),
          GestureDetector(
            onTap: value < max ? () => onChanged(value + 1) : null,
            child: Container(width: 38, height: 42, alignment: Alignment.center,
                child: Icon(Icons.add, size: 16,
                    color: value < max ? TwamboColors.primary : TwamboColors.line)),
          ),
        ]),
      ),
    ]);
  }
}

class _SheetModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _SheetModeChip({
    required this.label, required this.icon,
    required this.active, required this.onTap,
    this.activeColor = TwamboColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor : (isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt),
          border: Border.all(color: active ? activeColor : (isDark ? const Color(0xFF3E3E3E) : TwamboColors.line)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: active ? Colors.white : TwamboColors.textSecondary),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w700,
              color: active ? Colors.white : TwamboColors.textSecondary,
              letterSpacing: 0.5)),
        ]),
      ),
    );
  }
}
