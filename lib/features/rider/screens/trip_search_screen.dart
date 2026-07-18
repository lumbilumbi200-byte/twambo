import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/booking.dart';
import '../../../core/models/trip.dart';
import '../../../dev/all_places.dart';
import '../../../dev/city_regions.dart';
import '../../../dev/copperbelt/kitwe_places.dart' show haversineKm, estimatePrivateFare, estimateDynamicFare;
import '../../../dev/mock_trips.dart';
import '../../../dev/twambo_place.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../shared/app_providers.dart';
import '../../../core/storage.dart';
import '../../../shared/rider_nav_bar.dart';
import '../../../shared/theme.dart';

// (destination, date yyyy-MM-dd|null, minSeats, mode|null, tripType, origin)
typedef _SearchKey = (String, String?, int, String?, String, String);

// ── Marketing slide model from API ────────────────────────────────────────────

class _ApiSlide {
  final String label, tagline, iconKey, bgColor, textColor, accentColor;
  const _ApiSlide({
    required this.label, required this.tagline, required this.iconKey,
    required this.bgColor, required this.textColor, required this.accentColor,
  });
  factory _ApiSlide.fromJson(Map<String, dynamic> j) => _ApiSlide(
    label:       j['label']       as String? ?? '',
    tagline:     j['tagline']     as String? ?? '',
    iconKey:     j['icon_key']    as String? ?? 'car',
    bgColor:     j['bg_color']    as String? ?? '#FFC300',
    textColor:   j['text_color']  as String? ?? '#1A1A1A',
    accentColor: j['accent_color'] as String? ?? '#E6A800',
  );
}

final _apiSlidesProvider = FutureProvider<List<_ApiSlide>>((ref) async {
  try {
    final resp = await ApiClient.dio.get(Endpoints.marketingSlides);
    final list = (resp.data['slides'] as List)
        .map((e) => _ApiSlide.fromJson(e as Map<String, dynamic>))
        .toList();
    if (list.isNotEmpty) return list;
  } catch (_) {}
  // fallback — return empty so the widget uses hardcoded list
  return [];
});

// Fetches rider's current active/confirmed booking + its trip from real API
final _activeRideApiProvider = FutureProvider.autoDispose<_ActiveRideInfo?>((ref) async {
  if (kUseMockData) return null;
  try {
    final resp = await ApiClient.dio.get(Endpoints.myBookings);
    final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
    final bookings = raw.map<Booking>((j) => Booking.fromJson(j as Map<String, dynamic>)).toList();
    final active = bookings.firstWhere((b) => b.isConfirmed && b.tripId > 0,
        orElse: () => throw Exception('none'));
    final tripResp = await ApiClient.dio.get(Endpoints.tripDetail(active.tripId));
    final trip = Trip.fromJson(tripResp.data as Map<String, dynamic>);
    if (trip.isCompleted || trip.isCancelled) return null;
    // Fetch co-passengers if trip is active (EN ROUTE)
    List<Map<String, dynamic>> passengers = [];
    if (trip.isActive) {
      try {
        final pResp = await ApiClient.dio.get(Endpoints.tripPassengers(active.tripId));
        final pRaw = pResp.data is List ? pResp.data as List : (pResp.data['results'] as List? ?? []);
        passengers = pRaw.cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    return _ActiveRideInfo(booking: active, trip: trip, passengers: passengers);
  } catch (_) {
    return null;
  }
});

final tripSearchProvider = FutureProvider.autoDispose.family<List<Trip>, _SearchKey>((ref, key) async {
  final (destination, date, minSeats, mode, tripType, origin) = key;
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 400));
    var all = mockVisibleTrips;
    if (tripType.isNotEmpty) {
      all = all.where((t) => t.tripType == tripType).toList();
    }
    if (origin.isNotEmpty) {
      final o = origin.toLowerCase();
      all = all.where((t) => t.originName.toLowerCase().contains(o)).toList();
    }
    if (destination.isEmpty) {
      if (tripType == 'hike') all.sort((a, b) => a.departureTime.compareTo(b.departureTime));
      return all;
    }
    final q = destination.toLowerCase();
    final results = all.where((t) =>
        t.originName.toLowerCase().contains(q) ||
        t.destinationName.toLowerCase().contains(q)).toList();
    if (tripType == 'hike') results.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    return results;
  }
  final resp = await ApiClient.dio.get(Endpoints.tripSearch, queryParameters: {
    if (origin.isNotEmpty) 'origin': origin,
    if (destination.isNotEmpty) 'destination': destination,
    if (date != null) 'date': date,
    if (minSeats > 1) 'min_seats': minSeats,
    if (mode != null) 'mode': mode,
    if (tripType.isNotEmpty) 'trip_type': tripType,
    if (tripType == 'hike') 'ordering': 'departure_time',
  });
  final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
  return raw.map<Trip>((j) => Trip.fromJson(j as Map<String, dynamic>)).toList();
});

class TripSearchScreen extends ConsumerStatefulWidget {
  const TripSearchScreen({super.key});

  @override
  ConsumerState<TripSearchScreen> createState() => _TripSearchScreenState();
}

class _TripSearchScreenState extends ConsumerState<TripSearchScreen>
    with WidgetsBindingObserver {
  TwamboPlace? _fromPlace;
  TwamboPlace? _toPlace;
  CityRegion? _detectedCity;  // rider's current city (GPS-detected)
  CityRegion? _fromCity; // long-distance origin city
  CityRegion? _toCity;   // long-distance destination city

  // City-channel WebSocket — receives seat release broadcasts from drivers
  WebSocketChannel? _cityWs;
  StreamSubscription? _cityWsSub;
  Map<String, dynamic>? _pendingSeatRelease;

  List<TwamboPlace> get _cityPlaces =>
      placesForCity(_detectedCity?.id ?? 'kitwe');
  bool _isGrid = true;
  String _tripType = 'city'; // 'city' | 'hike'
  Timer? _activeRideTimer;

  // Filters
  DateTime? _filterDate;
  int _filterMinSeats = 1;
  String? _filterMode; // null = all

  int get _activeFilterCount =>
      (_filterDate != null ? 1 : 0) +
      (_filterMinSeats > 1 ? 1 : 0) +
      (_filterMode != null ? 1 : 0);

  _SearchKey get _searchKey {
    final dateStr = _filterDate != null
        ? '${_filterDate!.year}-${_filterDate!.month.toString().padLeft(2,'0')}-${_filterDate!.day.toString().padLeft(2,'0')}'
        : null;
    if (_tripType == 'hike') {
      return (
        _toCity?.name ?? '',
        dateStr,
        _filterMinSeats,
        _filterMode,
        'hike',
        // Don't filter by origin for hike trips — a rider in Chingola should see
        // ALL trips headed toward their destination, including Ndola→Solwezi passing through.
        '',
      );
    }
    return (
      _toPlace?.name ?? '',
      dateStr,
      _filterMinSeats,
      _filterMode,
      'city',
      '',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detectUserCity();
    // Poll mock booking state so active ride card updates live
    _activeRideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (kUseMockData) {
        setState(() {});
      } else {
        ref.invalidate(_activeRideApiProvider);
      }
    });
  }

  Future<void> _detectUserCity() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final city = detectCity(pos.latitude, pos.longitude) ??
          nearestCity(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _detectedCity = city);
        if (!kUseMockData) _connectCityWs(city.id);
      }
    } catch (_) {
      // GPS unavailable — fall back to Kitwe
    }
  }

  Future<void> _connectCityWs(String cityId) async {
    await _cityWsSub?.cancel();
    _cityWs?.sink.close();
    try {
      final token = await AppStorage.getAccessToken() ?? '';
      final uri = Uri.parse('${Endpoints.wsBase}${Endpoints.cityWs(cityId)}?token=$token');
      _cityWs = WebSocketChannel.connect(uri);
      _cityWsSub = _cityWs!.stream.listen(
        (raw) {
          if (!mounted) return;
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            if (data['type'] == 'seat_release') {
              setState(() => _pendingSeatRelease = data);
            }
          } catch (_) {}
        },
        onError: (_) {
          // Reconnect after brief delay on error (e.g. network switch)
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _connectCityWs(cityId);
          });
        },
        onDone: () {
          // Stream closed by server — reconnect
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _connectCityWs(cityId);
          });
        },
        cancelOnError: true,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeRideTimer?.cancel();
    _cityWsSub?.cancel();
    _cityWs?.sink.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _detectUserCity();
  }

  // Returns the rider's current active confirmed booking + linked trip
  _ActiveRideInfo? get _activeRide {
    if (!kUseMockData) return null;
    try {
      final booking = mockBookings.firstWhere((b) => b.isConfirmed && b.tripId > 0);
      final trip = mockTripById(booking.tripId);
      if (trip == null) return null;
      return _ActiveRideInfo(
        booking: booking,
        trip: trip,
        passengers: List<Map<String, dynamic>>.from(mockPassengers[booking.tripId] ?? []),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_Filters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        current: _Filters(_filterDate, _filterMinSeats, _filterMode),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _filterDate = result.date;
        _filterMinSeats = result.minSeats;
        _filterMode = result.mode;
      });
    }
  }

  void _selectFrom(TwamboPlace p) => setState(() => _fromPlace = p);
  void _selectTo(TwamboPlace p)   => setState(() => _toPlace = p);

  void _swap() {
    if (_fromPlace == null && _toPlace == null) { return; }
    setState(() { final t = _fromPlace; _fromPlace = _toPlace; _toPlace = t; });
  }

  Future<void> _openFromPicker() async {
    final result = await showModalBottomSheet<TwamboPlace>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _PlacePickerSheet(
        title: 'SELECT PICK-UP', initial: _fromPlace?.name ?? '',
        places: _cityPlaces, cityName: _detectedCity?.name ?? 'Kitwe',
      ),
    );
    if (result != null && mounted) { _selectFrom(result); }
  }

  Future<void> _openToPicker() async {
    final result = await showModalBottomSheet<TwamboPlace>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _PlacePickerSheet(
        title: 'SELECT DROP-OFF', initial: _toPlace?.name ?? '',
        places: _cityPlaces, cityName: _detectedCity?.name ?? 'Kitwe',
      ),
    );
    if (result != null && mounted) { _selectTo(result); }
  }

  Future<void> _openMapPicker(bool isFrom) async {
    final result = await showModalBottomSheet<TwamboPlace>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _MapPickerSheet(
        title: isFrom ? 'SELECT PICK-UP' : 'SELECT DROP-OFF',
        places: _cityPlaces,
      ),
    );
    if (result != null) {
      if (isFrom) { _selectFrom(result); }
      else { _selectTo(result); }
    }
  }

  Future<CityRegion?> _openCityPicker(BuildContext context, String title) {
    return showModalBottomSheet<CityRegion>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _CityPickerSheet(title: title),
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission perm = permission;
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
      // Use last known position first (instant); fall back to a fresh fix at
      // medium accuracy (cell/WiFi, ~2s) only when we have nothing cached.
      final cached = await Geolocator.getLastKnownPosition();
      final pos = (cached != null &&
              DateTime.now().difference(cached.timestamp).inMinutes <= 5)
          ? cached
          : await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.medium),
            ).timeout(const Duration(seconds: 15),
              onTimeout: () =>
                  throw Exception('Location timed out — try again'));
      // Reverse geocode via Nominatim for an accurate name
      String name;
      try {
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
        final resp = await dio.get(
          'https://nominatim.openstreetmap.org/reverse',
          queryParameters: {'lat': pos.latitude, 'lon': pos.longitude, 'format': 'json', 'zoom': 18},
          options: Options(headers: {'User-Agent': 'TwamboApp/1.0'}),
        );
        final data = resp.data as Map<String, dynamic>;
        final specific = data['name'] as String?;
        if (specific != null && specific.isNotEmpty) {
          name = specific;
        } else {
          final addr = (data['address'] as Map?)?.cast<String, dynamic>();
          final road = addr?['road'] as String?;
          final suburb = addr?['suburb'] as String?;
          name = (road != null && suburb != null) ? '$road, $suburb'
               : road ?? suburb ?? 'My Location';
        }
      } catch (_) {
        name = 'My Location';
      }
      if (mounted) {
        _selectFrom(TwamboPlace(name, pos.latitude, pos.longitude,
            cityId: _detectedCity?.id ?? 'kitwe',
            cityName: _detectedCity?.name ?? 'Kitwe'));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    }
  }

  List<Trip> _filterTrips(List<Trip> all) {
    // Exclude trips the rider has already booked
    final bookedIds = kUseMockData
        ? mockBookings.where((b) => b.isActive && b.tripId > 0).map((b) => b.tripId).toSet()
        : <int>{};
    final unbooked = bookedIds.isEmpty ? all : all.where((t) => !bookedIds.contains(t.id)).toList();

    // Hike mode: city-level filtering already handled by the API query (or mock provider)
    if (_tripType == 'hike') return unbooked;

    if (_fromPlace == null && _toPlace == null) { return unbooked; }
    return unbooked.where((t) {
      final toOk = _toPlace == null ||
          haversineKm(_toPlace!.lat, _toPlace!.lng, t.destinationLat, t.destinationLng) < 3.0;
      // Active rides are already moving — only filter by destination, not origin
      if (t.isActive) return toOk;
      final fromOk = _fromPlace == null ||
          haversineKm(_fromPlace!.lat, _fromPlace!.lng, t.originLat, t.originLng) < 3.0;
      return fromOk && toOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripSearchProvider(_searchKey));
    final user = ref.watch(authProvider).user;
    final firstName = user?.fullName.split(' ').first ?? 'Rider';
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final isHikeMode = _tripType == 'hike';
    final bothSelected = isHikeMode
        ? (_fromCity != null && _toCity != null)
        : (_fromPlace != null && _toPlace != null);
    final activeRide = kUseMockData
        ? _activeRide
        : ref.watch(_activeRideApiProvider).whenData((d) => d).value;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: const RiderNavBar(currentIndex: 0),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
        final bodyH = constraints.maxHeight;
        return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero zone ─────────────────────────────────────────────────
          SizedBox(
            height: bodyH * 0.20,
            child: _HeroZone(
              firstName: firstName, tripsAsync: tripsAsync,
              isDark: isDark, onSunTap: () => ref.read(themeModeProvider.notifier).toggle(),
            ),
          ),

          // ── Trip type selector ────────────────────────────────────────
          _TripTypeSelector(
            selected: _tripType,
            isDark: isDark,
            onSelect: (t) => setState(() {
              _tripType = t;
              _fromPlace = null;
              _toPlace = null;
              _fromCity = null;
              _toCity = null;
            }),
          ),

          // ── Route picker (city trips = place picker, hike = city picker) ─
          if (isHikeMode)
            _CityRouteCard(
              fromCity: _fromCity, toCity: _toCity,
              isDark: isDark,
              onFromTap: () async {
                final city = await _openCityPicker(context, 'FROM CITY');
                if (city != null && mounted) setState(() { _fromCity = city; });
              },
              onToTap: () async {
                final city = await _openCityPicker(context, 'TO CITY');
                if (city != null && mounted) setState(() { _toCity = city; });
              },
              onClearFrom: () => setState(() => _fromCity = null),
              onClearTo:   () => setState(() => _toCity = null),
              onSwap: () => setState(() { final t = _fromCity; _fromCity = _toCity; _toCity = t; }),
            )
          else
            _RouteSearchCard(
              fromPlace: _fromPlace, toPlace: _toPlace,
              onFromTap: _openFromPicker, onToTap: _openToPicker,
              onClearFrom: () => setState(() => _fromPlace = null),
              onClearTo:   () => setState(() => _toPlace = null),
              onMapFrom: () => _openMapPicker(true),
              onMapTo:   () => _openMapPicker(false),
              onSwap: _swap,
              onUseMyLocation: _useCurrentLocation,
            ),

          // ── Active ride card (between search and available rides) ─────
          if (activeRide != null) ...[
            const SizedBox(height: 10),
            _ActiveRideCard(
              info: activeRide,
              isDark: isDark,
              onCancel: () {
                final id = activeRide.booking.id;
                Future<void> doCancel() async {
                  if (kUseMockData) {
                    cancelMockBooking(id);
                  } else {
                    try {
                      await ApiClient.dio.post(Endpoints.cancelBooking(id));
                    } catch (_) {}
                  }
                  ref.invalidate(tripSearchProvider(_searchKey));
                }
                doCancel();
              },
              onManage: () {
                final trip = activeRide.trip;
                final booking = activeRide.booking;
                if (trip.isHike) {
                  // Hike trips: show full trip detail (map, driver, segment fare)
                  context.go('/trip/${trip.id}'
                      '?pickup=${Uri.encodeComponent(booking.pickupName)}'
                      '&pickupLat=${booking.pickupLat}&pickupLng=${booking.pickupLng}'
                      '&dropoffName=${Uri.encodeComponent(booking.dropoffName)}'
                      '&dropoffLat=${booking.dropoffLat}&dropoffLng=${booking.dropoffLng}');
                } else {
                  context.go('/bookings');
                }
              },
            ),
          ],

          // ── Section header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(children: [
              Expanded(child: Text(
                isHikeMode && bothSelected
                    ? '${_fromCity!.name} → ${_toCity!.name}'
                    : bothSelected
                        ? '${_fromPlace!.name.split(',').first} → ${_toPlace!.name.split(',').first}'
                        : (isHikeMode ? 'Long Distance Rides' : 'City Rides'),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : TwamboColors.textPrimary,
                  letterSpacing: 0.3,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              )),
              GestureDetector(
                onTap: _openFilters,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(color: _activeFilterCount > 0 ? TwamboColors.primary : TwamboColors.line),
                      color: _activeFilterCount > 0 ? TwamboColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                    ),
                    child: Icon(Icons.tune_rounded, size: 16,
                        color: _activeFilterCount > 0 ? TwamboColors.primary : TwamboColors.textSecondary),
                  ),
                  if (_activeFilterCount > 0)
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        width: 14, height: 14,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.primary),
                        child: Center(child: Text('$_activeFilterCount',
                            style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w800,
                                color: TwamboColors.textPrimary))),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 6),
              _ViewToggle(isGrid: _isGrid, onToggle: (v) => setState(() => _isGrid = v)),
            ]),
          ),

          // ── Trips ─────────────────────────────────────────────────────
          Expanded(
            child: tripsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
              error: (e, _) => Center(child: Text('Error: $e',
                  style: const TextStyle(color: TwamboColors.error))),
              data: (allTrips) {
                final trips = _filterTrips(allTrips);
                return CustomScrollView(slivers: [
                  if (isHikeMode && _pendingSeatRelease != null)
                    SliverToBoxAdapter(
                      child: _SeatReleaseBanner(
                        data: _pendingSeatRelease!,
                        isDark: isDark,
                        onDismiss: () => setState(() => _pendingSeatRelease = null),
                        onRequest: (tripId, pickup) async {
                          final messenger = ScaffoldMessenger.of(context);
                          final dest = _pendingSeatRelease?['destination'] as String? ?? '';
                          setState(() => _pendingSeatRelease = null);
                          try {
                            await ApiClient.dio.post(
                              Endpoints.joinTripRequest(tripId),
                              data: {'pickup_name': pickup, 'dropoff_name': dest},
                            );
                            if (mounted) {
                              messenger.showSnackBar(const SnackBar(
                                content: Text('Request sent! Waiting for driver to accept.'),
                                backgroundColor: TwamboColors.success,
                              ));
                            }
                          } catch (_) {
                            if (mounted) {
                              messenger.showSnackBar(const SnackBar(
                                content: Text('Could not send request. Try again.'),
                                backgroundColor: TwamboColors.error,
                              ));
                            }
                          }
                        },
                        fromCityName: _fromCity?.name ?? _detectedCity?.name ?? '',
                      ),
                    ),
                  if (!isHikeMode && bothSelected)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _RequestRideCard(
                          from: _fromPlace!, to: _toPlace!,
                          onTap: () => context.go(
                            '/request-ride'
                            '?fromName=${Uri.encodeComponent(_fromPlace!.name)}'
                            '&fromLat=${_fromPlace!.lat}&fromLng=${_fromPlace!.lng}'
                            '&toName=${Uri.encodeComponent(_toPlace!.name)}'
                            '&toLat=${_toPlace!.lat}&toLng=${_toPlace!.lng}',
                          ),
                        ),
                      ),
                    ),
                  if (trips.isEmpty)
                    SliverFillRemaining(child: _EmptyTrips(tripType: _tripType))
                  else if (_isGrid)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 12,
                          mainAxisSpacing: 12, childAspectRatio: 0.76,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _TripGridCard(trip: trips[i], boardingCity: _fromCity ?? _detectedCity),
                          childCount: trips.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TripListCard(trip: trips[i], boardingCity: _fromCity ?? _detectedCity),
                          ),
                          childCount: trips.length,
                        ),
                      ),
                    ),
                ]);
              },
            ),
          ),
        ],
        );
      }),
      ),
    );
  }
}

// ── Active ride data class ────────────────────────────────────────────────────

class _ActiveRideInfo {
  final Booking booking;
  final Trip trip;
  final List<Map<String, dynamic>> passengers;
  const _ActiveRideInfo({required this.booking, required this.trip, required this.passengers});
}

// ── Active ride card ──────────────────────────────────────────────────────────

class _ActiveRideCard extends StatefulWidget {
  final _ActiveRideInfo info;
  final bool isDark;
  final VoidCallback onCancel;
  final VoidCallback onManage;
  const _ActiveRideCard({required this.info, required this.isDark,
      required this.onCancel, required this.onManage});
  @override
  State<_ActiveRideCard> createState() => _ActiveRideCardState();
}

class _ActiveRideCardState extends State<_ActiveRideCard> {
  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel ride?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to cancel this booking?',
            style: GoogleFonts.manrope(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, cancel', style: TextStyle(color: TwamboColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final trip = info.trip;
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final seatsLeft = trip.availableSeats;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(left: BorderSide(color: TwamboColors.success, width: 4)),
        boxShadow: isDark ? null : [BoxShadow(
          color: TwamboColors.success.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          color: TwamboColors.success,
          child: Row(children: [
            const Icon(Icons.directions_car_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text('YOUR ACTIVE RIDE', style: GoogleFonts.spaceGrotesk(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 1.5)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.white.withValues(alpha: 0.2),
              child: Text(trip.mode.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                  fontSize: 7, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 1)),
            ),
          ]),
        ),

        // Compact route row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Row(children: [
            const Icon(Icons.circle, size: 8, color: TwamboColors.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(trip.originName.split(',').first,
                style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_forward, size: 12, color: TwamboColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(child: Text(trip.destinationName.split(',').first,
                style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),

        // Details
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Driver + seats
            Row(children: [
              const Icon(Icons.person_outline, size: 13, color: TwamboColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text('${trip.driverName} · ${trip.vehicleMakeModel}',
                  style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Icon(Icons.event_seat_rounded, size: 12,
                  color: seatsLeft > 0 ? TwamboColors.success : TwamboColors.error),
              const SizedBox(width: 4),
              Text('$seatsLeft seat${seatsLeft == 1 ? '' : 's'} empty',
                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700,
                      color: seatsLeft > 0 ? TwamboColors.success : TwamboColors.error)),
            ]),

            const SizedBox(height: 8),

            // Action buttons
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: widget.onManage,
                child: Container(
                  height: 38,
                  color: TwamboColors.success,
                  child: Center(child: Text('MANAGE', style: GoogleFonts.spaceGrotesk(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 1))),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () => _confirmCancel(context),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    border: Border.all(color: TwamboColors.error, width: 1.5),
                  ),
                  child: Center(child: Text('CANCEL', style: GoogleFonts.spaceGrotesk(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: TwamboColors.error, letterSpacing: 1))),
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Hero zone ─────────────────────────────────────────────────────────────────

class _HeroZone extends StatelessWidget {
  final String firstName;
  final AsyncValue<List<Trip>> tripsAsync;
  final bool isDark;
  final VoidCallback onSunTap;

  const _HeroZone({
    required this.firstName, required this.tripsAsync,
    required this.isDark, required this.onSunTap,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final count = tripsAsync.maybeWhen(data: (t) => t.length, orElse: () => null);

    return Stack(
      children: [
        // Gradient
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0D1B2A), const Color(0xFF1A2F4A), const Color(0xFF0A0F1A)]
                    : [const Color(0xFF1565C0), const Color(0xFF1E88E5), const Color(0xFF87CEEB)],
              ),
            ),
          ),
        ),

        // Tech grid
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),

        // Sun / moon toggle
        Positioned(
          top: 46, right: 14,
          child: GestureDetector(
            onTap: onSunTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFFFD700),
                boxShadow: [BoxShadow(
                  color: (isDark ? const Color(0xFF90CAF9) : const Color(0xFFFFD700)).withValues(alpha: 0.5),
                  blurRadius: 12, spreadRadius: isDark ? 1 : 3,
                )],
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                size: 17,
                color: isDark ? const Color(0xFF90CAF9) : const Color(0xFFFF8F00),
              ),
            ),
          ),
        ),

        // Content row
        Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT: fixed info
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TWMB',
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.4), letterSpacing: 4)),
                      const SizedBox(height: 4),
                      Text('$_greeting,',
                          style: GoogleFonts.manrope(fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
                      Text(firstName,
                          style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w800,
                              color: Colors.white, height: 1.1),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      if (count != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          color: TwamboColors.primary,
                          child: Text('$count rides now',
                              style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
                                  color: TwamboColors.textPrimary, letterSpacing: 0.8)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // RIGHT: marketing slider
                const Expanded(child: _MarketingSlider()),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Marketing slider ──────────────────────────────────────────────────────────

const _fallbackSlides = [
  _ApiSlide(label:'HIRE A CAR',    tagline:'Need it\nall yourself?',       iconKey:'car',     bgColor:'#FFC300', textColor:'#1A1A1A', accentColor:'#E6A800'),
  _ApiSlide(label:'BOOK A SEAT',   tagline:'Split the fare,\nnot the vibe', iconKey:'seat',    bgColor:'#1565C0', textColor:'#FFFFFF', accentColor:'#0D47A1'),
  _ApiSlide(label:'LIFE MADE EASY',tagline:'Tap. Ride.\nDone.',             iconKey:'phone',   bgColor:'#FFF8DC', textColor:'#1A1A1A', accentColor:'#FFE082'),
  _ApiSlide(label:'YOUR DRIVER',   tagline:"Know who's\nbehind the wheel",  iconKey:'driver',  bgColor:'#1A1A1A', textColor:'#FFFFFF', accentColor:'#2E2E2E'),
  _ApiSlide(label:'ABOUT TWMB',    tagline:"Zambia's seat\nmarketplace",    iconKey:'city',    bgColor:'#FFC300', textColor:'#1A1A1A', accentColor:'#E6A800'),
  _ApiSlide(label:'SAFE RIDES',    tagline:'Verified\ndrivers only',        iconKey:'shield',  bgColor:'#1565C0', textColor:'#FFFFFF', accentColor:'#0D47A1'),
  _ApiSlide(label:'SAVE MONEY',    tagline:'Shared seats,\nshared cost',    iconKey:'savings', bgColor:'#FF8C00', textColor:'#FFFFFF', accentColor:'#E65100'),
];

class _MarketingSlider extends ConsumerStatefulWidget {
  const _MarketingSlider();
  @override
  ConsumerState<_MarketingSlider> createState() => _MarketingSliderState();
}

class _MarketingSliderState extends ConsumerState<_MarketingSlider> {
  final _ctrl = PageController();
  int _page = 0;
  Timer? _timer;

  List<_ApiSlide> _buildApiSlides(List<_ApiSlide> api) {
    if (api.isNotEmpty) return api;
    return _fallbackSlides;
  }

  void _startTimer(int count) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (!mounted) return;
      _ctrl.animateToPage((_page + 1) % count,
          duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() { _timer?.cancel(); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final apiAsync = ref.watch(_apiSlidesProvider);
    final apiList = apiAsync.asData?.value ?? [];
    final items = _buildApiSlides(apiList);
    if (_timer == null) _startTimer(items.length);

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _ctrl,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _ApiSlideCard(slide: items[i]),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: i == _page ? 14 : 5, height: 4,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: i == _page ? TwamboColors.primary : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

Color _hexColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(0xFF000000 | int.parse(h.padLeft(6, '0'), radix: 16));
}

IconData _iconForKey(String key) {
  switch (key) {
    case 'seat':    return Icons.airline_seat_recline_normal_rounded;
    case 'phone':   return Icons.phone_iphone_rounded;
    case 'driver':  return Icons.person_rounded;
    case 'city':    return Icons.location_city_rounded;
    case 'shield':  return Icons.verified_user_rounded;
    case 'savings': return Icons.savings_rounded;
    case 'star':    return Icons.star_rounded;
    case 'route':   return Icons.route_rounded;
    case 'group':   return Icons.group_rounded;
    default:        return Icons.directions_car_filled_rounded;
  }
}

class _ApiSlideCard extends StatelessWidget {
  final _ApiSlide slide;
  const _ApiSlideCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    final bg     = _hexColor(slide.bgColor);
    final text   = _hexColor(slide.textColor);
    final accent = _hexColor(slide.accentColor);
    final icon   = _iconForKey(slide.iconKey);
    return Container(
      margin: const EdgeInsets.only(right: 6),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: bg),
      child: Stack(children: [
        Positioned(top: -18, right: -18, child: Container(width: 70, height: 70,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.55)))),
        Positioned(bottom: -22, left: -10, child: Container(width: 50, height: 50,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.3)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(slide.label, style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w800,
                  color: text.withValues(alpha: 0.65), letterSpacing: 1.5)),
            ]),
            Flexible(child: Text(slide.tagline.replaceAll(r'\n', '\n'),
                style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800,
                    color: text, height: 1.2),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ]),
    );
  }
}

// ── Route search card ─────────────────────────────────────────────────────────

class _RouteSearchCard extends StatelessWidget {
  final TwamboPlace? fromPlace, toPlace;
  final VoidCallback onFromTap, onToTap;
  final VoidCallback onClearFrom, onClearTo;
  final VoidCallback onMapFrom, onMapTo, onSwap;
  final VoidCallback onUseMyLocation;

  const _RouteSearchCard({
    required this.fromPlace, required this.toPlace,
    required this.onFromTap, required this.onToTap,
    required this.onClearFrom, required this.onClearTo,
    required this.onMapFrom, required this.onMapTo,
    required this.onSwap, required this.onUseMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final divColor = isDark ? const Color(0xFF2A2A2A) : TwamboColors.line;
    final mapBg = isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt;

    Widget fieldRow({
      required bool isFrom,
      required TwamboPlace? place,
      required VoidCallback onTap,
      required VoidCallback onClear,
      required VoidCallback onMap,
      VoidCallback? onGps,
    }) {
      final label = isFrom ? 'FROM' : 'TO';
      final hint  = isFrom ? 'Pick-up area…' : 'Drop-off area…';
      final dotColor = isFrom ? TwamboColors.primary : TwamboColors.error;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(children: [
            const SizedBox(width: 12),
            isFrom
                ? Container(width: 10, height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor))
                : Icon(Icons.location_on_rounded, size: 14, color: dotColor),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.spaceGrotesk(
                fontSize: 8, fontWeight: FontWeight.w800,
                color: dotColor, letterSpacing: 1.5)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              place?.name ?? hint,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: place != null ? textColor : TwamboColors.textSecondary,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            )),
            if (place != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClear,
                child: const SizedBox(width: 42, height: 48,
                    child: Icon(Icons.close_rounded, size: 14, color: TwamboColors.textSecondary)),
              )
            else
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (isFrom && onGps != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onGps,
                    child: Container(width: 42, height: 48, color: mapBg,
                        child: const Icon(Icons.my_location_rounded, size: 18, color: TwamboColors.primary)),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onMap,
                  child: Container(width: 42, height: 48, color: mapBg,
                      child: const Icon(Icons.map_outlined, size: 18, color: TwamboColors.secondary)),
                ),
              ]),
          ]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
        boxShadow: isDark ? null : [BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        fieldRow(isFrom: true,  place: fromPlace, onTap: onFromTap, onClear: onClearFrom, onMap: onMapFrom, onGps: onUseMyLocation),
        Stack(alignment: Alignment.center, children: [
          Container(height: 1, color: divColor),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSwap,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: divColor)),
              child: const Icon(Icons.swap_vert_rounded, size: 14, color: TwamboColors.textSecondary),
            ),
          ),
        ]),
        fieldRow(isFrom: false, place: toPlace,   onTap: onToTap,   onClear: onClearTo,   onMap: onMapTo),
      ]),
    );
  }
}

// ── Place picker sheet (modal) ────────────────────────────────────────────────

class _PlacePickerSheet extends StatefulWidget {
  final String title;
  final String initial;
  final List<TwamboPlace> places;
  final String cityName;
  const _PlacePickerSheet({
    required this.title,
    this.initial = '',
    this.places = const [],
    this.cityName = 'Kitwe',
  });
  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  final _ctrl = TextEditingController();
  @override
  void initState() { super.initState(); _ctrl.text = widget.initial; }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final results = searchCityPlaces(_ctrl.text, widget.places);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
      ),
      child: Column(children: [
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 12, 0),
          child: Row(children: [
            Expanded(child: Text(widget.title, style: GoogleFonts.spaceGrotesk(
                fontSize: 13, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 1))),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: const Padding(padding: EdgeInsets.all(8),
                  child: Icon(Icons.close_rounded, size: 20, color: TwamboColors.textSecondary)),
            ),
          ]),
        ),
        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              border: const Border(left: BorderSide(color: TwamboColors.secondary, width: 3)),
            ),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
              decoration: InputDecoration(
                hintText: 'Type a place or area…',
                hintStyle: GoogleFonts.spaceGrotesk(fontSize: 13, color: TwamboColors.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: TwamboColors.textSecondary),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => setState(() => _ctrl.clear()),
                        child: const Icon(Icons.close_rounded, size: 16, color: TwamboColors.textSecondary))
                    : null,
                border: InputBorder.none, enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true, fillColor: Colors.transparent, isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
              ),
            ),
          ),
        ),
        // Section label
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Text(
            _ctrl.text.isEmpty ? 'POPULAR IN ${widget.cityName.toUpperCase()}' : 'RESULTS',
            style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w800,
                color: TwamboColors.textSecondary, letterSpacing: 2),
          ),
        ),
        // Results list — proper ListView in a modal with no gesture conflicts
        Expanded(
          child: results.isEmpty
              ? Center(child: Text('No results for "${_ctrl.text}"',
                  style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (_, i) {
                    final place = results[i];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context, place),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          border: const Border(left: BorderSide(color: TwamboColors.primary, width: 3)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Row(children: [
                          const Icon(Icons.location_on_rounded, size: 16, color: TwamboColors.secondary),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(place.name, style: GoogleFonts.spaceGrotesk(
                                fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                            if (place.tag != null)
                              Text(place.tag!, style: GoogleFonts.manrope(
                                  fontSize: 10, color: TwamboColors.textSecondary)),
                          ])),
                          const Icon(Icons.north_east_rounded, size: 13, color: TwamboColors.textSecondary),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ── Seat release banner (hike tab) ───────────────────────────────────────────

class _SeatReleaseBanner extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final VoidCallback onDismiss;
  final Future<void> Function(int tripId, String pickupCity) onRequest;
  final String fromCityName;
  const _SeatReleaseBanner({
    required this.data, required this.isDark, required this.onDismiss,
    required this.onRequest, required this.fromCityName,
  });

  static const _orange = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final tripId = data['trip_id'] as int? ?? 0;
    final origin = data['origin'] as String? ?? '';
    final destination = data['destination'] as String? ?? '';
    final cityName = data['city_name'] as String? ?? '';
    final seats = data['seats'] as int? ?? 1;
    final fare = data['fare'] as String? ?? '';
    final pickupCity = fromCityName.isEmpty ? cityName : fromCityName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: _orange,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(children: [
          const Icon(Icons.airline_seat_recline_normal_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SEAT OPENING IN $cityName'.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 0.8,
                  )),
              const SizedBox(height: 2),
              Text('$origin → $destination · $seats seat · K$fare',
                  style: GoogleFonts.manrope(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => onRequest(tripId, pickupCity),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('REQUEST SEAT FROM $pickupCity'.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: _orange, letterSpacing: 0.6,
                      )),
                ),
              ),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }
}

// ── Request ride card ─────────────────────────────────────────────────────────

class _RequestRideCard extends StatelessWidget {
  final TwamboPlace from, to;
  final VoidCallback onTap;
  const _RequestRideCard({required this.from, required this.to, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final privateFare = estimatePrivateFare(from.lat, from.lng, to.lat, to.lng);
    final dynamicFare = estimateDynamicFare(from.lat, from.lng, to.lat, to.lng);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1565C0),
          border: Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(children: [
          const Icon(Icons.directions_car_filled_rounded, size: 22, color: TwamboColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('REQUEST A RIDE', style: GoogleFonts.spaceGrotesk(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 1.5)),
            const SizedBox(height: 2),
            Text('${from.name} → ${to.name}',
                style: GoogleFonts.manrope(fontSize: 11, color: Colors.white70),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
              'Dynamic ~K${dynamicFare.toStringAsFixed(0)}/seat  ·  Private ~K${privateFare.toStringAsFixed(0)}',
              style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w700,
                  color: TwamboColors.primary, letterSpacing: 0.5),
            ),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: TwamboColors.primary,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('GO', style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, fontWeight: FontWeight.w800, color: TwamboColors.textPrimary)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: TwamboColors.textPrimary),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── View toggle ───────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool isGrid;
  final ValueChanged<bool> onToggle;
  const _ViewToggle({required this.isGrid, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: TwamboColors.line), color: TwamboColors.surfaceAlt),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Btn(icon: Icons.grid_view_rounded, active: isGrid, onTap: () => onToggle(true)),
        Container(width: 1, height: 28, color: TwamboColors.line),
        _Btn(icon: Icons.view_list_rounded, active: !isGrid, onTap: () => onToggle(false)),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon; final bool active; final VoidCallback onTap;
  const _Btn({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(7),
      color: active ? TwamboColors.primary : Colors.transparent,
      child: Icon(icon, size: 17, color: active ? TwamboColors.textPrimary : TwamboColors.textSecondary),
    ),
  );
}

// ── Live badge (pulsing green dot for en-route rides) ─────────────────────────

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 900), vsync: this)
        ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TwamboColors.success.withValues(alpha: _pulse.value),
          ),
        ),
      ),
      const SizedBox(width: 5),
      Flexible(child: Text('EN ROUTE · JOIN NOW', style: GoogleFonts.spaceGrotesk(
          fontSize: 9, fontWeight: FontWeight.w800,
          color: TwamboColors.success, letterSpacing: 1.0),
        overflow: TextOverflow.ellipsis)),
    ]);
  }
}

// ── Grid card ─────────────────────────────────────────────────────────────────

class _TripGridCard extends StatefulWidget {
  final Trip trip;
  final CityRegion? boardingCity;
  const _TripGridCard({required this.trip, this.boardingCity});
  @override
  State<_TripGridCard> createState() => _TripGridCardState();
}

class _TripGridCardState extends State<_TripGridCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _carPos;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat();
    _carPos = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.05, 0.85, curve: Curves.easeInOut)));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final ok = trip.availableSeats > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final divColor = isDark ? const Color(0xFF2E2E2E) : TwamboColors.line;

    final bookingClosed = !trip.bookingWindowOpen;

    return InkWell(
      onTap: bookingClosed ? null : () => _showBoardingSheet(context, trip, widget.boardingCity),
      child: Opacity(
        opacity: bookingClosed ? 0.55 : 1.0,
        child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(left: BorderSide(
              color: bookingClosed ? divColor : (trip.isActive ? TwamboColors.success : (ok ? TwamboColors.primary : divColor)),
              width: 3)),
          boxShadow: isDark ? null : [BoxShadow(color: TwamboColors.primary.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          trip.isActive
              ? const _LiveBadge()
              : Row(children: [
                  Text('${trip.mode.toUpperCase()} · ${_fmt(trip.departureTime)}',
                      style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w700,
                          color: bookingClosed ? TwamboColors.textSecondary : TwamboColors.primary, letterSpacing: 1.2)),
                  const SizedBox(width: 5),
                  if (bookingClosed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      color: TwamboColors.textSecondary.withValues(alpha: 0.12),
                      child: Text('CLOSED', style: GoogleFonts.spaceGrotesk(
                          fontSize: 7, fontWeight: FontWeight.w800,
                          color: TwamboColors.textSecondary, letterSpacing: 0.8)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      color: trip.isHike
                          ? const Color(0xFFE65100).withValues(alpha: 0.12)
                          : TwamboColors.primary.withValues(alpha: 0.10),
                      child: Text(trip.isHike ? 'LONG' : 'CITY',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 7, fontWeight: FontWeight.w800,
                              color: trip.isHike ? const Color(0xFFE65100) : TwamboColors.primary,
                              letterSpacing: 0.8)),
                    ),
                ]),
          const SizedBox(height: 4),
          Text(
            'K${(trip.isDynamic && !trip.isHike ? estimateDynamicFare(trip.originLat, trip.originLng, trip.destinationLat, trip.destinationLng) : trip.currentSharedFare).toStringAsFixed(0)}',
            style: GoogleFonts.spaceGrotesk(fontSize: 26, fontWeight: FontWeight.w800,
                color: textColor, height: 1.0)),

          // Animated route column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                // Animated route line with car
                SizedBox(
                  width: 18,
                  child: AnimatedBuilder(
                    animation: _carPos,
                    builder: (_, __) => CustomPaint(
                      painter: _RoutePainter(progress: _carPos.value, isDark: isDark),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Place names
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_short(trip.originName),
                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700,
                              color: textColor),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(_short(trip.destinationName),
                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700,
                              color: TwamboColors.secondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),
            ),
          ),

          Container(height: 1, color: divColor),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.event_seat_rounded, size: 11,
                color: ok ? TwamboColors.success : TwamboColors.error),
            const SizedBox(width: 3),
            Text('${trip.availableSeats}', style: GoogleFonts.spaceGrotesk(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: ok ? TwamboColors.success : TwamboColors.error)),
            const Spacer(),
            if (ok && !bookingClosed)
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: trip.isActive ? TwamboColors.success : TwamboColors.primary,
                  child: Text(trip.isActive ? 'JOIN' : 'BOOK', style: GoogleFonts.spaceGrotesk(
                      fontSize: 8, fontWeight: FontWeight.w800,
                      letterSpacing: 1, color: TwamboColors.textPrimary))),
          ]),
        ]),
      ),
      ),
    );
  }

  String _short(String n) => n.split(',').first;
  String _fmt(DateTime dt) => '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}

// ── List card ─────────────────────────────────────────────────────────────────

class _TripListCard extends StatelessWidget {
  final Trip trip;
  final CityRegion? boardingCity;
  const _TripListCard({required this.trip, this.boardingCity});

  @override
  Widget build(BuildContext context) {
    final ok = trip.availableSeats > 0;
    final bookingClosed = !trip.bookingWindowOpen;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final divColor = isDark ? const Color(0xFF2E2E2E) : TwamboColors.line;

    return Opacity(
      opacity: bookingClosed ? 0.55 : 1.0,
      child: InkWell(
      onTap: bookingClosed ? null : () => _showBoardingSheet(context, trip, boardingCity),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(left: BorderSide(
              color: bookingClosed ? divColor : (trip.isActive ? TwamboColors.success : (ok ? TwamboColors.primary : divColor)),
              width: 3)),
          boxShadow: isDark ? null : [BoxShadow(color: TwamboColors.primary.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          // Route direction column
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.circle, size: 8, color: TwamboColors.primary),
            Container(width: 1.5, height: 18, color: divColor),
            const Icon(Icons.directions_car_filled_rounded, size: 14, color: TwamboColors.primary),
            Container(width: 1.5, height: 18, color: divColor),
            Icon(Icons.location_on, size: 14, color: TwamboColors.secondary),
          ]),
          const SizedBox(width: 10),
          // Text
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            trip.isActive
                ? const _LiveBadge()
                : Row(children: [
                    Flexible(child: Text('${trip.mode.toUpperCase()} · ${_fmt(trip.departureTime)}',
                        style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w700,
                            color: TwamboColors.primary, letterSpacing: 1.2),
                        overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      color: trip.isHike
                          ? const Color(0xFFE65100).withValues(alpha: 0.12)
                          : TwamboColors.primary.withValues(alpha: 0.10),
                      child: Text(trip.isHike ? 'LONG DIST' : 'CITY',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 7, fontWeight: FontWeight.w800,
                              color: trip.isHike ? const Color(0xFFE65100) : TwamboColors.primary,
                              letterSpacing: 0.8)),
                    ),
                  ]),
            const SizedBox(height: 3),
            Text(_short(trip.originName),
                style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700,
                    color: textColor),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(_short(trip.destinationName),
                style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700,
                    color: TwamboColors.secondary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.person_outline, size: 12, color: TwamboColors.textSecondary),
              const SizedBox(width: 3),
              Text(trip.driverName, style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
              const SizedBox(width: 8),
              Icon(Icons.event_seat_rounded, size: 12, color: ok ? TwamboColors.success : TwamboColors.error),
              const SizedBox(width: 3),
              Text('${trip.availableSeats} left', style: GoogleFonts.manrope(fontSize: 11,
                  color: ok ? TwamboColors.success : TwamboColors.error)),
            ]),
          ])),
          const SizedBox(width: 12),
          // Price + book
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              'K${(trip.isDynamic && !trip.isHike ? estimateDynamicFare(trip.originLat, trip.originLng, trip.destinationLat, trip.destinationLng) : trip.currentSharedFare).toStringAsFixed(0)}',
              style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w800,
                  color: textColor)),
            const SizedBox(height: 4),
            if (bookingClosed)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: TwamboColors.textSecondary.withValues(alpha: 0.12),
                  child: Text('CLOSED', style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      letterSpacing: 1.5, color: TwamboColors.textSecondary)))
            else if (ok)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: trip.isActive ? TwamboColors.success : TwamboColors.primary,
                  child: Text(trip.isActive ? 'JOIN' : 'BOOK', style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      letterSpacing: 1.5, color: TwamboColors.textPrimary))),
          ]),
        ]),
      ),
      ),
    );
  }

  String _short(String n) => n.split(',').first;
  String _fmt(DateTime dt) => '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}

// ── City route card (long distance) ──────────────────────────────────────────

class _CityRouteCard extends StatelessWidget {
  final CityRegion? fromCity;
  final CityRegion? toCity;
  final bool isDark;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback onClearFrom;
  final VoidCallback onClearTo;
  final VoidCallback onSwap;

  const _CityRouteCard({
    required this.fromCity, required this.toCity,
    required this.isDark, required this.onFromTap, required this.onToTap,
    required this.onClearFrom, required this.onClearTo, required this.onSwap,
  });

  static const _hikeOrange = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final divColor = isDark ? const Color(0xFF2A2A2A) : TwamboColors.line;

    Widget row({
      required bool isFrom,
      required CityRegion? city,
      required VoidCallback onTap,
      required VoidCallback onClear,
    }) {
      final label = isFrom ? 'FROM' : 'TO';
      final hint  = isFrom ? 'Departure city…' : 'Destination city…';

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(children: [
            const SizedBox(width: 12),
            Icon(isFrom ? Icons.my_location_rounded : Icons.location_on_rounded,
                size: 16, color: _hikeOrange),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.spaceGrotesk(
                fontSize: 8, fontWeight: FontWeight.w800,
                color: _hikeOrange, letterSpacing: 1.5)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(
                city?.name ?? hint,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: city != null ? textColor : TwamboColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              if (city != null)
                Text(city.province, style: GoogleFonts.manrope(
                    fontSize: 10, color: TwamboColors.textSecondary)),
            ])),
            if (city != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClear,
                child: const SizedBox(width: 44, height: 52,
                    child: Icon(Icons.close_rounded, size: 14, color: TwamboColors.textSecondary)),
              ),
          ]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(left: BorderSide(color: _hikeOrange, width: 4)),
        boxShadow: isDark ? null : [BoxShadow(
            color: _hikeOrange.withValues(alpha: 0.08),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        row(isFrom: true,  city: fromCity, onTap: onFromTap, onClear: onClearFrom),
        Stack(alignment: Alignment.center, children: [
          Container(height: 1, color: divColor),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSwap,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle,
                  border: Border.all(color: divColor)),
              child: const Icon(Icons.swap_vert_rounded, size: 14, color: TwamboColors.textSecondary),
            ),
          ),
        ]),
        row(isFrom: false, city: toCity,   onTap: onToTap,   onClear: onClearTo),
      ]),
    );
  }
}

// ── City picker sheet (long distance — by province) ───────────────────────────

class _CityPickerSheet extends StatelessWidget {
  final String title;
  const _CityPickerSheet({required this.title});

  static const _hikeOrange = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final byProvince = intercityCitiesByProvince;
    final comingSoon = comingSoonCitiesByProvince;

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: BoxDecoration(
        color: bg,
        border: const Border(left: BorderSide(color: _hikeOrange, width: 4)),
      ),
      child: Column(children: [
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 12, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: _hikeOrange,
              child: Text('LONG DISTANCE', style: GoogleFonts.spaceGrotesk(
                  fontSize: 8, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 1.5)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: GoogleFonts.spaceGrotesk(
                fontSize: 13, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 1))),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: const Padding(padding: EdgeInsets.all(8),
                  child: Icon(Icons.close_rounded, size: 20, color: TwamboColors.textSecondary)),
            ),
          ]),
        ),
        // Province-grouped list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              ...byProvince.entries.map((e) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(e.key.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                      fontSize: 8, fontWeight: FontWeight.w800,
                      color: TwamboColors.textSecondary, letterSpacing: 2)),
                ),
                ...e.value.map((city) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context, city),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      border: const Border(left: BorderSide(color: _hikeOrange, width: 3)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Container(width: 32, height: 32,
                          color: cardBg,
                          child: const Icon(Icons.route_rounded, size: 16, color: _hikeOrange)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(city.name, style: GoogleFonts.spaceGrotesk(
                            fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                        Text(city.province, style: GoogleFonts.manrope(
                            fontSize: 10, color: TwamboColors.textSecondary)),
                      ])),
                      const Icon(Icons.north_east_rounded, size: 14, color: TwamboColors.textSecondary),
                    ]),
                  ),
                )),
              ]);
            }),
              // ── Coming soon provinces ───────────────────────────────────────
              if (comingSoon.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...comingSoon.entries.map((e) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Text(e.key.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                            fontSize: 8, fontWeight: FontWeight.w800,
                            color: TwamboColors.textSecondary.withValues(alpha: 0.4), letterSpacing: 2)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          color: TwamboColors.textSecondary.withValues(alpha: 0.12),
                          child: Text('COMING SOON', style: GoogleFonts.spaceGrotesk(
                              fontSize: 7, fontWeight: FontWeight.w700,
                              color: TwamboColors.textSecondary, letterSpacing: 1.5)),
                        ),
                      ]),
                    ),
                    ...e.value.map((city) => Opacity(
                      opacity: 0.35,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          border: Border(left: BorderSide(color: TwamboColors.textSecondary.withValues(alpha: 0.3), width: 3)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Container(width: 32, height: 32,
                              color: cardBg,
                              child: const Icon(Icons.route_rounded, size: 16, color: TwamboColors.textSecondary)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(city.name, style: GoogleFonts.spaceGrotesk(
                                fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                            Text('Routes launching soon', style: GoogleFonts.manrope(
                                fontSize: 10, color: TwamboColors.textSecondary)),
                          ])),
                          const Icon(Icons.lock_clock_outlined, size: 14, color: TwamboColors.textSecondary),
                        ]),
                      ),
                    )),
                  ],
                )),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Trip type selector ────────────────────────────────────────────────────────

class _TripTypeSelector extends StatelessWidget {
  final String selected;
  final bool isDark;
  final ValueChanged<String> onSelect;
  const _TripTypeSelector({required this.selected, required this.isDark, required this.onSelect});

  static const _hikeOrange = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final inactiveBg = isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt;
    final inactiveText = TwamboColors.textSecondary;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(children: [
        Expanded(child: _TypeTab(
          label: 'CITY TRIPS',
          icon: Icons.location_city_rounded,
          active: selected == 'city',
          activeColor: TwamboColors.primary,
          activeBg: TwamboColors.primary,
          inactiveBg: inactiveBg,
          inactiveText: inactiveText,
          onTap: () => onSelect('city'),
        )),
        const SizedBox(width: 8),
        Expanded(child: _TypeTab(
          label: 'LONG DISTANCE',
          icon: Icons.route_rounded,
          active: selected == 'hike',
          activeColor: _hikeOrange,
          activeBg: _hikeOrange,
          inactiveBg: inactiveBg,
          inactiveText: inactiveText,
          onTap: () => onSelect('hike'),
        )),
      ]),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final Color activeBg;
  final Color inactiveBg;
  final Color inactiveText;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label, required this.icon, required this.active,
    required this.activeColor, required this.activeBg,
    required this.inactiveBg, required this.inactiveText, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 42,
        decoration: BoxDecoration(
          color: active ? activeBg : inactiveBg,
          border: active
              ? Border.all(color: activeColor, width: 0)
              : Border.all(color: Colors.transparent, width: 0),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: active ? Colors.white : inactiveText),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: active ? Colors.white : inactiveText,
              letterSpacing: 1.2)),
        ]),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyTrips extends StatelessWidget {
  final String tripType;
  const _EmptyTrips({this.tripType = 'city'});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxBg = isDark ? const Color(0xFF1E1E1E) : TwamboColors.surfaceAlt;
    final isHike = tripType == 'hike';
    final accent = isHike ? const Color(0xFFE65100) : TwamboColors.primary;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 48, height: 48,
          decoration: BoxDecoration(color: boxBg,
              border: Border(left: BorderSide(color: accent, width: 3))),
          child: Icon(isHike ? Icons.route_rounded : Icons.directions_car_outlined,
              size: 24, color: TwamboColors.textSecondary)),
      const SizedBox(height: 10),
      Text(isHike ? 'NO LONG DISTANCE TRIPS' : 'NO CITY RIDES',
          style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700,
          color: TwamboColors.textSecondary, letterSpacing: 2)),
      const SizedBox(height: 3),
      Text(isHike
          ? 'No intercity trips available right now'
          : 'Check back soon or try a different route',
          style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
    ]));
  }
}

// ── Grid painter ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.06)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += size.width / 8) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), p); }
    for (double y = 0; y < size.height; y += size.height / 5) { canvas.drawLine(Offset(0, y), Offset(size.width, y), p); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Route painter (animated car on grid card) ─────────────────────────────────

class _RoutePainter extends CustomPainter {
  final double progress;
  final bool isDark;
  const _RoutePainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const topY = 6.0;
    final botY = size.height - 6.0;

    // Route line
    final linePaint = Paint()
      ..color = isDark ? const Color(0xFF3E3E3E) : TwamboColors.line
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, topY + 8), Offset(cx, botY - 8), linePaint);

    // Origin dot
    canvas.drawCircle(Offset(cx, topY), 5,
        Paint()..color = TwamboColors.primary..style = PaintingStyle.fill);

    // Destination dot
    canvas.drawCircle(Offset(cx, botY), 5,
        Paint()..color = TwamboColors.secondary..style = PaintingStyle.fill);

    // Animated car (small rounded rect)
    final carY = topY + 8 + (botY - topY - 16) * progress;
    final carRect = Rect.fromCenter(center: Offset(cx, carY), width: 11, height: 7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(carRect, const Radius.circular(2)),
      Paint()..color = TwamboColors.primary..style = PaintingStyle.fill,
    );
    // Windshield line on car
    canvas.drawLine(
      Offset(cx - 2, carY - 1), Offset(cx + 2, carY - 1),
      Paint()..color = const Color(0xFF1A1A1A).withValues(alpha: 0.5)..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.progress != progress;
}

// ── Map picker sheet ──────────────────────────────────────────────────────────

class _MapPickerSheet extends StatefulWidget {
  final String title;
  final List<TwamboPlace> places;
  const _MapPickerSheet({required this.title, this.places = const []});
  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  final _mapCtrl = MapController();
  LatLng _center = const LatLng(-12.8024, 28.2132);
  bool _confirming = false;

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  // Fast fallback while panning — uses the city place list
  String _nearestName(double lat, double lng) {
    TwamboPlace? nearest;
    double minDist = double.infinity;
    for (final p in widget.places) {
      final d = haversineKm(lat, lng, p.lat, p.lng);
      if (d < minDist) { minDist = d; nearest = p; }
    }
    if (nearest == null) return 'Pinned location';
    if (minDist < 0.5) return nearest.name;
    if (minDist < 2.0) return '${nearest.name} area';
    return 'Pinned location';
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    LatLng pos;
    try {
      pos = _mapCtrl.camera.center;
    } catch (_) {
      pos = _center;
    }
    final name = _nearestName(pos.latitude, pos.longitude);
    if (mounted) {
      Navigator.pop(context, TwamboPlace(name, pos.latitude, pos.longitude));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.surfaceAlt,
                  border: const Border(left: BorderSide(color: TwamboColors.primary, width: 3)),
                ),
                child: Icon(Icons.arrow_back, size: 16,
                    color: isDark ? Colors.white : TwamboColors.textPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Text(widget.title, style: GoogleFonts.spaceGrotesk(
                fontSize: 12, fontWeight: FontWeight.w800,
                color: textColor, letterSpacing: 1.2)),
            const Spacer(),
            Text('Pan to pin location',
                style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
          ]),
        ),

        // ── Map ─────────────────────────────────────────────────────────
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: const LatLng(-12.8024, 28.2132),
                initialZoom: 14.5,
                onMapEvent: (event) {
                  // fires on every move/zoom; no API version ambiguity
                  setState(() => _center = event.camera.center);
                },
              ),
              children: [
                if (kShowMapTiles)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.twambo.app',
                  )
                else
                  const ColoredBox(color: Color(0xFFD8DADB), child: SizedBox.expand()),
              ],
            ),

            // Fixed center pin (tip points to exact map center)
            Center(
              child: Transform.translate(
                offset: const Offset(0, -24), // icon size 48/2 so tip = center
                child: Icon(Icons.location_on_rounded, size: 48,
                    color: TwamboColors.error,
                    shadows: const [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))]),
              ),
            ),

            // Crosshair dot at exact center
            Center(
              child: Container(width: 4, height: 4,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
            ),

          ]),
        ),

        // ── Confirm button ───────────────────────────────────────────────
        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: GestureDetector(
            onTap: _confirming ? null : _confirm,
            child: Container(
              height: 52, width: double.infinity,
              color: _confirming ? TwamboColors.line : TwamboColors.primary,
              child: Center(child: _confirming
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: TwamboColors.textPrimary))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('SELECT THIS LOCATION', style: GoogleFonts.spaceGrotesk(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: TwamboColors.textPrimary, letterSpacing: 1.5)),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_rounded, size: 16, color: TwamboColors.textPrimary),
                    ])),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Boarding sheet ────────────────────────────────────────────────────────────

class _BoardingData {
  final TwamboPlace pickup;
  final TwamboPlace? dropoff;
  const _BoardingData(this.pickup, [this.dropoff]);
}

Future<void> _showBoardingSheet(BuildContext context, Trip trip, [CityRegion? boardingCity]) async {
  final surcharge = ProviderScope.containerOf(context)
      .read(authProvider).user?.fareSurchargePct ?? 0;
  // Hike trips use the full intercity place list (all cities + highway waypoints).
  // City trips scope to the trip's origin city only.
  final cityPlaces = trip.isHike
      ? intercityTwamboPlaces()
      : placesForCity(detectCity(trip.originLat, trip.originLng)?.id ?? 'kitwe');
  // For hike pass-through trips: default pickup to the rider's city, not the trip origin.
  TwamboPlace? defaultPickup;
  if (trip.isHike && boardingCity != null) {
    defaultPickup = TwamboPlace(
      boardingCity.name,
      boardingCity.centerLat,
      boardingCity.centerLng,
      cityId: boardingCity.id,
      cityName: boardingCity.name,
    );
  }
  final data = await showModalBottomSheet<_BoardingData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BoardingSheet(trip: trip, surcharge: surcharge, cityPlaces: cityPlaces, defaultPickup: defaultPickup),
  );
  if (data != null && context.mounted) {
    var url = '/trip/${trip.id}'
        '?pickup=${Uri.encodeComponent(data.pickup.name)}'
        '&pickupLat=${data.pickup.lat}&pickupLng=${data.pickup.lng}';
    if (data.dropoff != null) {
      url += '&dropoffName=${Uri.encodeComponent(data.dropoff!.name)}'
             '&dropoffLat=${data.dropoff!.lat}&dropoffLng=${data.dropoff!.lng}';
    }
    context.go(url);
  }
}

// ── Boarding sheet route map (fetches OSRM road route) ───────────────────────

class _BoardingRouteMap extends StatefulWidget {
  final Trip trip;
  const _BoardingRouteMap({required this.trip});
  @override
  State<_BoardingRouteMap> createState() => _BoardingRouteMapState();
}

class _BoardingRouteMapState extends State<_BoardingRouteMap> {
  List<LatLng>? _pts;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final t = widget.trip;
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
      final resp = await dio.get(
        'https://router.project-osrm.org/route/v1/driving/${t.originLng},${t.originLat};${t.destinationLng},${t.destinationLat}',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      if (resp.data['code'] == 'Ok') {
        final coords = (resp.data['routes'][0]['geometry']['coordinates'] as List)
            .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
        if (mounted) setState(() => _pts = coords);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: [LatLng(t.originLat, t.originLng), LatLng(t.destinationLat, t.destinationLng)],
          padding: const EdgeInsets.fromLTRB(40, 50, 40, 50),
        ),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
      ),
      children: [
        if (kShowMapTiles)
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.twambo.app')
        else
          const ColoredBox(color: Color(0xFFD8DADB), child: SizedBox.expand()),
        if (_pts != null)
          PolylineLayer(polylines: [Polyline(
            points: _pts!, color: TwamboColors.success,
            strokeWidth: 4, borderColor: Colors.white, borderStrokeWidth: 1.5,
          )]),
        MarkerLayer(markers: [
          Marker(
            point: LatLng(t.originLat, t.originLng), width: 28, height: 28,
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: TwamboColors.primary),
              child: const Icon(Icons.circle, size: 8, color: Colors.black),
            ),
          ),
          Marker(
            point: LatLng(t.destinationLat, t.destinationLng), width: 32, height: 32,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: TwamboColors.error,
                boxShadow: [BoxShadow(color: TwamboColors.error.withValues(alpha: 0.4), blurRadius: 6)],
              ),
              child: const Icon(Icons.location_on, size: 16, color: Colors.white),
            ),
          ),
        ]),
        // Place name chips
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(children: [
              _MapLabel(Icons.trip_origin, t.originName.split(',').first, TwamboColors.primary),
              const Spacer(),
              _MapLabel(Icons.flag_outlined, t.destinationName.split(',').first, TwamboColors.error),
            ]),
          ),
        ),
      ],
    );
  }
}

class _MapLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MapLabel(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    color: Colors.white.withValues(alpha: 0.9),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 10, fontWeight: FontWeight.w700, color: TwamboColors.textPrimary)),
    ]),
  );
}

class _BoardingSheet extends StatefulWidget {
  final Trip trip;
  final int surcharge;
  final List<TwamboPlace> cityPlaces;
  final TwamboPlace? defaultPickup;
  const _BoardingSheet({required this.trip, this.surcharge = 0, this.cityPlaces = const [], this.defaultPickup});
  @override
  State<_BoardingSheet> createState() => _BoardingSheetState();
}

class _BoardingSheetState extends State<_BoardingSheet> {
  TwamboPlace? _pickup;
  TwamboPlace? _dropoff;

  bool get _isJoining => widget.trip.isActive;

  double get _detourFee {
    final p = _pickup;
    if (p == null) return 0;
    final trip = widget.trip;
    final detourKm = haversineKm(p.lat, p.lng, trip.originLat, trip.originLng);
    if (detourKm < 0.3) return 0;
    const rate = 2.0;
    final cap = trip.isHike ? 50.0 : 15.0;
    return (detourKm * rate).clamp(0, cap);
  }

  double get _segmentFare {
    final trip = widget.trip;
    if (trip.isHike) {
      // Proportional fare: rider pays route_fare × (segment km / full route km).
      // Segment = pickup → dropoff (or trip destination if no dropoff selected).
      final p = _pickup;
      if (p == null) return trip.currentSharedFare;
      final fullDist = haversineKm(
          trip.originLat, trip.originLng, trip.destinationLat, trip.destinationLng);
      if (fullDist < 1) return trip.currentSharedFare;
      final dropLat = _dropoff?.lat ?? trip.destinationLat;
      final dropLng = _dropoff?.lng ?? trip.destinationLng;
      final segmentDist = haversineKm(p.lat, p.lng, dropLat, dropLng);
      final ratio = (segmentDist / fullDist).clamp(0.0, 1.0);
      // Roadside (highway waypoint) boarding gets 12% off vs a formal bus station.
      final discount = (p.cityId == 'highway') ? 0.88 : 1.0;
      final raw = trip.currentSharedFare * ratio * discount;
      return ((raw / 5).ceil() * 5).toDouble();
    }
    // Dynamic city trip: per-rider distance-based fare.
    return estimateDynamicFare(
      trip.originLat, trip.originLng,
      _dropoff?.lat ?? trip.destinationLat,
      _dropoff?.lng ?? trip.destinationLng,
    );
  }

  @override
  void initState() {
    super.initState();
    // Hike pass-through: use the rider's boarding city as default, not the trip origin
    _pickup = widget.defaultPickup ??
        TwamboPlace(widget.trip.originName, widget.trip.originLat, widget.trip.originLng);
    // Hike trips: default drop-off to trip destination
    if (widget.trip.isHike) {
      _dropoff = TwamboPlace(
          widget.trip.destinationName, widget.trip.destinationLat, widget.trip.destinationLng);
    }
  }

  @override
  void dispose() { super.dispose(); }

  Future<void> _pickPickup() async {
    final result = await showModalBottomSheet<TwamboPlace>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _PlacePickerSheet(
        title: 'WHERE DO YOU WANT TO BOARD?',
        places: widget.cityPlaces,
        cityName: widget.trip.isHike
            ? 'ALL CITIES'
            : detectCity(widget.trip.originLat, widget.trip.originLng)?.name ?? 'Kitwe',
      ),
    );
    if (result != null && mounted) setState(() => _pickup = result);
  }

  Future<void> _pickPickupOnMap() async {
    final result = await showModalBottomSheet<TwamboPlace>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _MapPickerSheet(title: 'PIN YOUR BOARDING POINT', places: widget.cityPlaces),
    );
    if (result != null && mounted) setState(() => _pickup = result);
  }

  Future<void> _pickDropoff() async {
    final result = await showModalBottomSheet<TwamboPlace>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _PlacePickerSheet(
        title: 'WHERE ARE YOU GOING?',
        places: widget.cityPlaces,
        cityName: detectCity(widget.trip.originLat, widget.trip.originLng)?.name ?? 'Kitwe',
      ),
    );
    if (result != null && mounted) setState(() => _dropoff = result);
  }

  Future<void> _pickDropoffOnMap() async {
    final result = await showModalBottomSheet<TwamboPlace>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _MapPickerSheet(title: 'PIN YOUR DROP-OFF', places: widget.cityPlaces),
    );
    if (result != null && mounted) setState(() => _dropoff = result);
  }

  Future<void> _pickDropoffHike() async {
    final result = await showModalBottomSheet<TwamboPlace>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _PlacePickerSheet(
        title: 'WHERE ARE YOU GETTING OFF?',
        places: widget.cityPlaces,
        cityName: 'ALL CITIES',
      ),
    );
    if (result != null && mounted) setState(() => _dropoff = result);
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final ok = trip.availableSeats > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final divColor = isDark ? const Color(0xFF2E2E2E) : TwamboColors.line;
    final fillColor = isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt;
    final accentColor = _isJoining ? TwamboColors.success : TwamboColors.primary;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.92,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Route map ──────────────────────────────────────────────────
          SizedBox(
            height: screenH * 0.38,
            child: Stack(children: [
              _BoardingRouteMap(trip: trip),
              // Close button
              Positioned(
                top: 12, right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    color: Colors.white,
                    child: const Icon(Icons.close, size: 18, color: TwamboColors.textPrimary),
                  ),
                ),
              ),
              // Live badge overlay
              if (_isJoining)
                Positioned(
                  top: 12, left: 12,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      color: TwamboColors.success,
                      child: Text('LIVE', style: GoogleFonts.spaceGrotesk(
                          fontSize: 8, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 1.5)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      color: Colors.white,
                      child: Text('JOIN THIS RIDE', style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: TwamboColors.textPrimary, letterSpacing: 1)),
                    ),
                  ]),
                ),
            ]),
          ),

          // ── Details panel ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 14, 16,
                  MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Trip meta row
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: accentColor,
                    child: Text(trip.mode.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                        fontSize: 8, fontWeight: FontWeight.w800,
                        color: _isJoining ? Colors.white : TwamboColors.textPrimary,
                        letterSpacing: 1.5)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _isJoining
                        ? '${trip.driverName} · ~2 min away'
                        : 'K${trip.currentSharedFare.toStringAsFixed(0)}/seat · ${_fmt(trip.departureTime)}',
                    style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
                  Icon(Icons.event_seat_rounded, size: 12,
                      color: ok ? TwamboColors.success : TwamboColors.error),
                  const SizedBox(width: 4),
                  Text('${trip.availableSeats} left',
                      style: GoogleFonts.manrope(fontSize: 11,
                          color: ok ? TwamboColors.success : TwamboColors.error,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.person_outline, size: 12, color: TwamboColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(child: Text('${trip.driverName} · ${trip.vehicleMakeModel}',
                      style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),

                const SizedBox(height: 12),
                Container(height: 1, color: divColor),
                const SizedBox(height: 12),

                // Strike surcharge warning
                if (widget.surcharge > 0) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A1A00) : const Color(0xFFFFF3E0),
                      border: const Border(left: BorderSide(color: TwamboColors.secondary, width: 3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: TwamboColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Your fare includes a ${widget.surcharge}% conduct surcharge due to previous strikes.',
                        style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.secondary,
                            fontWeight: FontWeight.w600, height: 1.4),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],

                // Boarding point
                Text('WHERE DO YOU WANT TO BOARD?',
                    style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
                        color: TwamboColors.textSecondary, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _pickPickup,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: fillColor,
                          border: Border(
                            left: const BorderSide(color: TwamboColors.secondary, width: 3),
                            top: BorderSide(color: divColor),
                            bottom: BorderSide(color: divColor),
                            right: BorderSide(color: divColor),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(children: [
                          Icon(Icons.pin_drop_outlined, size: 16,
                              color: _pickup != null ? TwamboColors.secondary : TwamboColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            _pickup?.name ?? 'Pick your boarding point…',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: _pickup != null ? textColor : TwamboColors.textSecondary,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          )),
                        ]),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickPickupOnMap,
                    child: Container(
                      width: 48, height: 48,
                      color: TwamboColors.secondary.withValues(alpha: 0.15),
                      child: const Icon(Icons.map_outlined, size: 20, color: TwamboColors.secondary),
                    ),
                  ),
                ]),

                // ── Hike trip: drop-off city picker + fare ────────────────
                if (trip.isHike) ...[
                  const SizedBox(height: 12),
                  Text('WHERE ARE YOU GETTING OFF?',
                      style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
                          color: TwamboColors.textSecondary, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _pickDropoffHike,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: fillColor,
                        border: Border(
                          left: const BorderSide(color: TwamboColors.success, width: 3),
                          top: BorderSide(color: divColor),
                          bottom: BorderSide(color: divColor),
                          right: BorderSide(color: divColor),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        Icon(Icons.flag_outlined, size: 16,
                            color: _dropoff != null ? TwamboColors.success : TwamboColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          _dropoff?.name ?? trip.destinationName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        )),
                        const Icon(Icons.expand_more, size: 18, color: TwamboColors.textSecondary),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F2012) : const Color(0xFFE8F5E9),
                      border: const Border(left: BorderSide(color: TwamboColors.success, width: 3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.payments_outlined, size: 14, color: TwamboColors.success),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'YOUR SEGMENT FARE',
                        style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w700,
                            color: TwamboColors.success, letterSpacing: 0.8),
                      )),
                      Text('K${_segmentFare.toStringAsFixed(0)}',
                          style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w800,
                              color: TwamboColors.success)),
                    ]),
                  ),
                ],

                // ── City trip: dropoff picker + segment fare ───────────────
                if (!trip.isHike) ...[
                  const SizedBox(height: 12),
                  Text('WHERE ARE YOU GOING?',
                      style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
                          color: TwamboColors.textSecondary, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _pickDropoff,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: fillColor,
                            border: Border(
                              left: const BorderSide(color: TwamboColors.success, width: 3),
                              top: BorderSide(color: divColor),
                              bottom: BorderSide(color: divColor),
                              right: BorderSide(color: divColor),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(children: [
                            Icon(Icons.location_on_rounded, size: 16,
                                color: _dropoff != null ? TwamboColors.success : TwamboColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              _dropoff?.name ?? 'Pick your drop-off…',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: _dropoff != null ? textColor : TwamboColors.textSecondary,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            )),
                          ]),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickDropoffOnMap,
                      child: Container(
                        width: 48, height: 48,
                        color: TwamboColors.success.withValues(alpha: 0.15),
                        child: const Icon(Icons.map_outlined, size: 20, color: TwamboColors.success),
                      ),
                    ),
                  ]),
                  if (_dropoff != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F2012) : const Color(0xFFE8F5E9),
                        border: const Border(left: BorderSide(color: TwamboColors.success, width: 3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.payments_outlined, size: 14, color: TwamboColors.success),
                        const SizedBox(width: 8),
                        Text('YOUR FARE FOR THIS SEGMENT',
                            style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w700,
                                color: TwamboColors.success, letterSpacing: 0.8)),
                        const Spacer(),
                        Text('K${_segmentFare.toStringAsFixed(0)}',
                            style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w800,
                                color: TwamboColors.success)),
                      ]),
                    ),
                  ],
                ],

                  // Detour fee info — shown when pickup differs from trip origin
                  if (_detourFee > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A1800) : const Color(0xFFFFF3E0),
                        border: const Border(left: BorderSide(color: Color(0xFFE65100), width: 3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.home_outlined, size: 14, color: Color(0xFFE65100)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Home pickup detour${trip.isHike ? ' (long dist cap K50)' : ' (city cap K15)'}',
                          style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w700,
                              color: const Color(0xFFE65100), letterSpacing: 0.8),
                        )),
                        Text('+ K${_detourFee.toStringAsFixed(0)}',
                            style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w800,
                                color: const Color(0xFFE65100))),
                      ]),
                    ),
                  ],

                const SizedBox(height: 16),

                // CTA
                if (ok)
                  GestureDetector(
                    onTap: () {
                      final pickup = _pickup ?? TwamboPlace(trip.originName, trip.originLat, trip.originLng);
                      Navigator.pop(context, _BoardingData(pickup, _dropoff));
                    },
                    child: Container(
                      height: 52, width: double.infinity,
                      color: accentColor,
                      child: Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            _isJoining
                                ? (_dropoff != null
                                    ? 'JOIN RIDE · K${_segmentFare.toStringAsFixed(0)}'
                                    : 'JOIN RIDE')
                                : 'VIEW MAP & SEATS',
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w800,
                                color: _isJoining ? Colors.white : TwamboColors.textPrimary,
                                letterSpacing: 1.5),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 16,
                              color: _isJoining ? Colors.white : TwamboColors.textPrimary),
                        ]),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 48, width: double.infinity,
                    decoration: const BoxDecoration(
                      color: TwamboColors.surfaceAlt,
                      border: Border(left: BorderSide(color: TwamboColors.error, width: 4)),
                    ),
                    child: Center(
                      child: Text('FULLY BOOKED',
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800,
                              color: TwamboColors.error, letterSpacing: 2)),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Filter sheet ──────────────────────────────────────────────────────────────

class _Filters {
  final DateTime? date;
  final int minSeats;
  final String? mode;
  const _Filters(this.date, this.minSeats, this.mode);
}

class _FilterSheet extends StatefulWidget {
  final _Filters current;
  const _FilterSheet({required this.current});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DateTime? _date;
  late int _minSeats;
  late String? _mode;

  @override
  void initState() {
    super.initState();
    _date     = widget.current.date;
    _minSeats = widget.current.minSeats;
    _mode     = widget.current.mode;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
            ),
            padding: const EdgeInsets.only(left: 10),
            child: Text('FILTER RIDES',
                style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() { _date = null; _minSeats = 1; _mode = null; }),
            child: Text('Clear all',
                style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary,
                    decoration: TextDecoration.underline)),
          ),
        ]),
        const SizedBox(height: 20),

        // Date
        Text('DATE', style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
            color: TwamboColors.textSecondary, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: _date != null ? TwamboColors.primary : TwamboColors.line),
              color: _date != null ? TwamboColors.primary.withValues(alpha: 0.08) : Colors.transparent,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded, size: 14,
                  color: _date != null ? TwamboColors.primary : TwamboColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _date != null
                    ? '${_date!.day}/${_date!.month}/${_date!.year}'
                    : 'Any day',
                style: GoogleFonts.manrope(fontSize: 13,
                    color: _date != null ? textColor : TwamboColors.textSecondary),
              )),
              if (_date != null)
                GestureDetector(
                  onTap: () => setState(() => _date = null),
                  child: const Icon(Icons.close_rounded, size: 14, color: TwamboColors.textSecondary),
                ),
            ]),
          ),
        ),

        const SizedBox(height: 16),

        // Minimum seats
        Row(children: [
          Expanded(child: Text('MINIMUM SEATS', style: GoogleFonts.spaceGrotesk(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: TwamboColors.textSecondary, letterSpacing: 1.4))),
          Text('$_minSeats seat${_minSeats > 1 ? 's' : ''}',
              style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700,
                  color: TwamboColors.primary)),
        ]),
        Slider(
          value: _minSeats.toDouble(),
          min: 1, max: 6, divisions: 5,
          activeColor: TwamboColors.primary,
          inactiveColor: TwamboColors.line,
          onChanged: (v) => setState(() => _minSeats = v.round()),
        ),

        const SizedBox(height: 8),

        // Mode
        Text('RIDE MODE', style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
            color: TwamboColors.textSecondary, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        Row(children: [
          for (final (label, value) in [('All', null), ('Shared', 'shared'), ('Private', 'private'), ('Hike', 'hike')])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _mode = value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  color: _mode == value ? TwamboColors.primary : Colors.transparent,
                  decoration: _mode == value ? null : BoxDecoration(
                    border: Border.all(color: TwamboColors.line),
                  ),
                  child: Text(label, style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: _mode == value ? TwamboColors.textPrimary : TwamboColors.textSecondary)),
                ),
              ),
            ),
        ]),

        const SizedBox(height: 24),

        GestureDetector(
          onTap: () => Navigator.pop(context, _Filters(_date, _minSeats, _mode)),
          child: Container(
            height: 48, width: double.infinity,
            color: TwamboColors.primary,
            alignment: Alignment.center,
            child: Text('APPLY FILTERS',
                style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800,
                    color: TwamboColors.textPrimary, letterSpacing: 1)),
          ),
        ),
      ]),
    );
  }
}
