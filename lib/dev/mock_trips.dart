import 'dart:async';
import '../core/models/booking.dart';
import '../core/models/trip.dart';
import 'kitwe_places.dart';

// Flip to false when backend is running
const kUseMockData = false;

// Flip to false if you have no internet (prevents tile network errors)
const kShowMapTiles = true;

// ── Rider-side: trip search results ──────────────────────────────────────────

// Trips visible to riders = other-driver trips + all driver's own posted trips
// (combined dynamically in mockVisibleTrips so live testing works)
final mockTrips = <Trip>[];

Trip? mockTripById(int id) {
  try {
    return mockVisibleTrips.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
}

// ── Rider: my bookings ────────────────────────────────────────────────────────

final mockBookings = <Booking>[];

int _nextBookingId = 4000;
int _nextRideRequestId = 9000;

void addMockRequest({
  required String fromName,
  required String toName,
  required String mode,
  required double fare,
}) {
  final bookingId = _nextBookingId++;
  mockBookings.insert(
    0,
    Booking(
      id: bookingId,
      tripId: -1,
      driverId: 0,
      tripOrigin: fromName,
      tripDestination: toName,
      tripDeparture: DateTime.now().add(const Duration(minutes: 5)),
      driverName: mode == 'dynamic' ? 'Finding driver…' : 'Searching driver…',
      pickupName: fromName,
      dropoffName: toName,
      seatsBooked: 1,
      fareAtBooking: fare,
      amountDue: fare,
      detourFee: 0,
      status: 'pending',
      paymentMethod: 'cash',
      createdAt: DateTime.now(),
    ),
  );

  // Push into the driver broadcast inbox (Requests screen)
  final pickup = kitwePlaces.firstWhere(
    (p) => fromName.toLowerCase().contains(p.name.toLowerCase().split(',').first),
    orElse: () => KitwePlace('', -12.8024, 28.2132),
  );
  final requestId = _nextRideRequestId++;
  mockBroadcastRequests.insert(0, {
    'id': requestId,
    'booking_id': bookingId, // link back to rider's booking
    'rider_initials': 'ME',
    'origin_name': fromName,
    'origin_lat': '${pickup.lat}',
    'origin_lng': '${pickup.lng}',
    'destination_name': toName,
    'fare_estimate': fare.toStringAsFixed(0),
    'mode': mode,
    'created_mins_ago': 0,
  });

  // 7-minute timeout — if no driver accepts, auto-cancel
  Timer(const Duration(minutes: 7), () {
    final stillPending = mockBroadcastRequests.any((r) => r['id'] == requestId);
    if (stillPending) {
      mockBroadcastRequests.removeWhere((r) => r['id'] == requestId);
      final bIdx = mockBookings.indexWhere((b) => b.id == bookingId);
      if (bIdx != -1) {
        mockBookings[bIdx] = mockBookings[bIdx].copyWith(status: 'cancelled');
      }
    }
  });
}

void cancelMockBooking(int id) {
  final idx = mockBookings.indexWhere((b) => b.id == id);
  if (idx != -1) {
    mockBookings[idx] = mockBookings[idx].copyWith(status: 'cancelled');
  }
}

// ── Driver: own posted trips (starts empty — driver creates trips live) ───────

final mockDriverTrips = <Trip>[];

Trip? mockDriverTripById(int id) {
  try {
    return mockDriverTrips.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
}

// All trips a rider can see = own-driver trips (active/scheduled) + mockTrips
List<Trip> get mockVisibleTrips => [
      ...mockDriverTrips.where((t) => t.isActive || t.isScheduled),
      ...mockTrips,
    ];

int _nextDriverTripId = 300;

void _updateMockDriverTrip(int id, Trip Function(Trip) updater) {
  final idx = mockDriverTrips.indexWhere((t) => t.id == id);
  if (idx != -1) mockDriverTrips[idx] = updater(mockDriverTrips[idx]);
}

void startMockTrip(int id) =>
    _updateMockDriverTrip(id, (t) => t.copyWith(status: 'active'));

void completeMockTrip(int id) =>
    _updateMockDriverTrip(id, (t) => t.copyWith(status: 'completed', bookingWindowOpen: false));

void cancelMockTrip(int id) =>
    _updateMockDriverTrip(id, (t) => t.copyWith(status: 'cancelled', bookingWindowOpen: false));

void addMockDriverTrip({
  required String originName, required double originLat, required double originLng,
  required String destinationName, required double destinationLat, required double destinationLng,
  required DateTime departureTime, required int totalSeats, required int minimumRiders,
  required String mode, required double fare,
  required int driverId, required String driverName,
}) {
  final id = _nextDriverTripId++;
  // Trips departing more than 2 min in the future start as scheduled
  final isImmediate = departureTime.difference(DateTime.now()).inMinutes < 2;
  final initialStatus = isImmediate ? 'active' : 'scheduled';

  mockDriverTrips.insert(0, Trip(
    id: id, driverId: driverId, driverName: driverName,
    vehicleType: 'sedan',
    vehicleMakeModel: '${mockVehicle['make']} ${mockVehicle['model']} · ABZ 1234',
    originName: originName, originLat: originLat, originLng: originLng,
    destinationName: destinationName, destinationLat: destinationLat, destinationLng: destinationLng,
    departureTime: departureTime, status: initialStatus, mode: mode,
    totalSeats: totalSeats, availableSeats: totalSeats, seatsTaken: 0,
    currentSharedFare: fare, privateFare: fare * 3,
    bookingWindowOpen: true, minimumRiders: minimumRiders,
  ));
  mockTripRideRequests[id] = [];
  mockPassengers[id] = [];
  mockTripBookings[id] = [];

  // Auto-promote to active at departure time (for mock testing)
  if (!isImmediate) {
    final delay = departureTime.difference(DateTime.now());
    if (delay.isNegative) return;
    Timer(delay, () => _updateMockDriverTrip(id, (t) => t.copyWith(status: 'active')));
  }
}

// ── Driver: riders booked on each trip ───────────────────────────────────────

final mockTripBookings = <int, List<Map<String, dynamic>>>{};

// ── Driver: pending ride requests per trip ────────────────────────────────────

final mockTripRideRequests = <int, List<Map<String, dynamic>>>{};

// ── Driver: passengers list per trip ─────────────────────────────────────────

final mockPassengers = <int, List<Map<String, dynamic>>>{};

// ── Driver: earnings mock data ────────────────────────────────────────────────

final mockWallet = <String, dynamic>{
  'balance': '450.00',
  'minimum_float': '50.00',
  'can_accept_rides': true,
};

final mockWalletTxs = <Map<String, dynamic>>[
  {
    'id': 9001, 'tx_type': 'credit', 'amount': '450.00',
    'description': 'Initial test wallet balance',
    'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
  },
];

final mockOpLogs = <Map<String, dynamic>>[];

const mockVehicle = <String, dynamic>{
  'make': 'Toyota',
  'model': 'Corolla',
  'fuel_type': 'petrol',
  'fuel_consumption_l_per_100km': '9.5',
  'last_service_date': '2026-04-15',
  'service_interval_km': 5000,
  'service_interval_months': 3,
  'estimated_service_cost_zmw': '800',
  'admin_notes': '',
};

final mockDriverProfile = <String, dynamic>{
  'fuel_price_per_litre': '35.0',
  'vehicle_notes': '',
  'is_online': false,
};

const mockBudget = <String, dynamic>{
  'has_enough_data': true,
  'earnings': 470.0,
  'estimated_fuel_cost': 120.0,
  'service_fund': 47.0,
  'logged_costs': 430.0,
  'net': 303.0,
  'total_km': 130.0,
  'advice': [
    'Your fuel spend looks healthy for your trip volume.',
    'Set aside K47 (10%) towards your next service due in ~3 weeks.',
  ],
  'is_dismissed': false,
};

// ── Broadcast ride requests (driver's requests inbox) ────────────────────────

final mockBroadcastRequests = <Map<String, dynamic>>[];

void acceptMockBroadcastRequest(int id, {required int driverId, required String driverName}) {
  final idx = mockBroadcastRequests.indexWhere((r) => r['id'] == id);
  if (idx == -1) return;
  final r = mockBroadcastRequests[idx];
  final fare = double.tryParse(r['fare_estimate'].toString()) ?? 20.0;
  final originLat = double.tryParse(r['origin_lat'].toString()) ?? -12.8024;
  final originLng = double.tryParse(r['origin_lng'].toString()) ?? 28.2132;
  // Find nearest Kitwe destination coords
  final destPlace = kitwePlaces.firstWhere(
    (p) => (r['destination_name'] as String).toLowerCase().contains(p.name.toLowerCase().split(',').first.toLowerCase()),
    orElse: () => KitwePlace('', -12.8024, 28.2132),
  );
  // Create a new active trip for this broadcast request
  final tripId = _nextDriverTripId++;
  mockDriverTrips.insert(0, Trip(
    id: tripId, driverId: driverId, driverName: driverName,
    vehicleType: 'sedan',
    vehicleMakeModel: '${mockVehicle['make']} ${mockVehicle['model']} · ABZ 1234',
    originName: r['origin_name'] as String,
    originLat: originLat, originLng: originLng,
    destinationName: r['destination_name'] as String,
    destinationLat: destPlace.lat.isNaN ? -12.8024 : destPlace.lat,
    destinationLng: destPlace.lng.isNaN ? 28.2132 : destPlace.lng,
    departureTime: DateTime.now(),
    status: 'active', mode: r['mode'] as String? ?? 'dynamic',
    totalSeats: 4, availableSeats: 3, seatsTaken: 1,
    currentSharedFare: fare, privateFare: fare * 2,
    bookingWindowOpen: true, minimumRiders: 1,
  ));
  // Pre-seed the rider as a passenger in all driver-side maps
  final riderEntry = {
    'id': 5000 + id,
    'rider_name': '${r['rider_initials']} Rider',
    'rider_phone': '+260 97 000 0000',
    'pickup_name': r['origin_name'],
    'pickup_lat': r['origin_lat'],
    'pickup_lng': r['origin_lng'],
    'dropoff_name': r['destination_name'],
    'seats_booked': 1,
    'amount_due': r['fare_estimate'],
    'status': 'confirmed',
  };
  mockPassengers[tripId] = [riderEntry];
  mockTripBookings[tripId] = [riderEntry];
  mockTripRideRequests[tripId] = [];

  // Update rider's booking: mark confirmed and link to the new trip
  final bookingId = r['booking_id'] as int?;
  if (bookingId != null) {
    final bIdx = mockBookings.indexWhere((b) => b.id == bookingId);
    if (bIdx != -1) {
      mockBookings[bIdx] = mockBookings[bIdx].copyWith(
        status: 'confirmed',
        tripId: tripId,
        driverId: driverId,
        driverName: driverName,
        driverPhone: '+260 97 100 0001',
      );
    }
  }

  mockBroadcastRequests.removeAt(idx);
}

void declineMockBroadcastRequest(int id) =>
    mockBroadcastRequests.removeWhere((r) => r['id'] == id);

void acceptMockRideRequest(int tripId, int requestId) {
  final list = mockTripRideRequests[tripId];
  if (list == null) return;
  final idx = list.indexWhere((r) => r['id'] == requestId);
  if (idx == -1) return;
  final r = list[idx];
  (mockPassengers[tripId] ??= []).insert(0, {
    'id': 5000 + requestId,
    'rider_name': '${r['rider_initials']} Rider',
    'rider_phone': '+260 97 000 0000',
    'pickup_name': r['origin_name'],
    'dropoff_name': r['destination_name'],
    'seats_booked': 1,
    'amount_due': r['fare_estimate'],
    'status': 'confirmed',
  });
  list.removeAt(idx);
}

void rejectMockRideRequest(int tripId, int requestId) =>
    mockTripRideRequests[tripId]?.removeWhere((r) => r['id'] == requestId);

// ── Recurring trips mock (driver-side) ───────────────────────────────────────

int _nextRecurringId = 701;

final mockRecurringTrips = <Map<String, dynamic>>[];

void addMockRecurringTrip(Map<String, dynamic> data) {
  mockRecurringTrips.insert(0, {
    'id': _nextRecurringId++,
    ...data,
  });
}

void removeMockRecurringTrip(int id) =>
    mockRecurringTrips.removeWhere((t) => t['id'] == id);

void toggleMockRecurringTrip(int id) {
  final idx = mockRecurringTrips.indexWhere((t) => t['id'] == id);
  if (idx != -1) {
    final cur = mockRecurringTrips[idx]['is_active'] as bool;
    mockRecurringTrips[idx] = {...mockRecurringTrips[idx], 'is_active': !cur};
  }
}

// ── Booking helpers for mock mode ─────────────────────────────────────────────

void addMockBookingConfirmed({
  required Trip trip,
  required int seatCount,
  required String? pickupName,
  String? riderName,
}) {
  final fareTotal = trip.currentSharedFare * seatCount;
  final bookingId = _nextBookingId++;
  final pickup = pickupName ?? trip.originName;

  mockBookings.insert(0, Booking(
    id: bookingId,
    tripId: trip.id,
    driverId: trip.driverId,
    tripOrigin: trip.originName,
    tripDestination: trip.destinationName,
    tripDeparture: trip.departureTime,
    driverName: trip.driverName,
    driverPhone: '+260 97 100 0001',
    pickupName: pickup,
    dropoffName: trip.destinationName,
    seatsBooked: seatCount,
    fareAtBooking: trip.currentSharedFare.toDouble(),
    amountDue: fareTotal.toDouble(),
    detourFee: 0,
    status: 'confirmed',
    paymentMethod: 'cash',
    createdAt: DateTime.now(),
  ));

  // Always write rider into the driver's bookings and passengers maps
  final passengerEntry = {
    'id': bookingId,
    'rider_name': riderName ?? 'Rider',
    'rider_phone': '+260 97 000 0000',
    'pickup_name': pickup,
    'pickup_lat': '${trip.originLat}',
    'pickup_lng': '${trip.originLng}',
    'dropoff_name': trip.destinationName,
    'seats_booked': seatCount,
    'amount_due': fareTotal.toStringAsFixed(0),
    'status': 'confirmed',
  };
  (mockTripBookings[trip.id] ??= []).insert(0, passengerEntry);
  (mockPassengers[trip.id] ??= []).insert(0, passengerEntry);

  // For active trips also push an in-route ride request
  if (trip.isActive) {
    final originPlace = kitwePlaces.firstWhere(
      (p) => pickup.toLowerCase().contains(p.name.toLowerCase().split(',').first),
      orElse: () => KitwePlace('', trip.originLat, trip.originLng),
    );
    (mockTripRideRequests[trip.id] ??= []).insert(0, {
      'id': _nextRideRequestId++,
      'rider_initials': (riderName ?? 'R').substring(0, 1).toUpperCase(),
      'origin_name': pickup,
      'origin_lat': '${originPlace.lat != 0 ? originPlace.lat : trip.originLat}',
      'origin_lng': '${originPlace.lng != 0 ? originPlace.lng : trip.originLng}',
      'destination_name': trip.destinationName,
      'fare_estimate': fareTotal.toStringAsFixed(0),
      'mode': 'dynamic',
      'created_mins_ago': 0,
    });
  }

  // Update available seats on the driver's trip
  _updateMockDriverTrip(trip.id, (t) => t.copyWith(
    availableSeats: (t.availableSeats - seatCount).clamp(0, t.totalSeats),
    seatsTaken: t.seatsTaken + seatCount,
  ));
}

