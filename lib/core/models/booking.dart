class Booking {
  final int id;
  final int tripId;
  final int driverId;
  final String tripOrigin;
  final String tripDestination;
  final DateTime tripDeparture;
  final String driverName;
  final String driverPhone;
  final String pickupName;
  final double pickupLat;
  final double pickupLng;
  final String dropoffName;
  final double dropoffLat;
  final double dropoffLng;
  final int seatsBooked;
  final double fareAtBooking;
  final double? fareFinal;
  final double amountDue;
  final double detourFee;
  final String status;
  final String paymentMethod;
  final String tripType; // 'city' | 'hike'
  final DateTime createdAt;

  const Booking({
    required this.id,
    required this.tripId,
    required this.driverId,
    required this.tripOrigin,
    required this.tripDestination,
    required this.tripDeparture,
    required this.driverName,
    this.driverPhone = '',
    required this.pickupName,
    this.pickupLat = 0,
    this.pickupLng = 0,
    required this.dropoffName,
    this.dropoffLat = 0,
    this.dropoffLng = 0,
    required this.seatsBooked,
    required this.fareAtBooking,
    this.fareFinal,
    required this.amountDue,
    required this.detourFee,
    required this.status,
    required this.paymentMethod,
    this.tripType = 'city',
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isNoShow => status == 'no_show';
  bool get isActive => isPending || isConfirmed;
  bool get isHike   => tripType == 'hike';

  Booking copyWith({String? status, String? driverName, String? driverPhone, int? tripId, int? driverId}) => Booking(
    id: id, tripId: tripId ?? this.tripId, driverId: driverId ?? this.driverId,
    tripOrigin: tripOrigin, tripDestination: tripDestination,
    tripDeparture: tripDeparture, driverName: driverName ?? this.driverName,
    driverPhone: driverPhone ?? this.driverPhone,
    pickupName: pickupName, pickupLat: pickupLat, pickupLng: pickupLng,
    dropoffName: dropoffName, dropoffLat: dropoffLat, dropoffLng: dropoffLng,
    seatsBooked: seatsBooked, fareAtBooking: fareAtBooking,
    fareFinal: fareFinal, amountDue: amountDue, detourFee: detourFee,
    status: status ?? this.status,
    paymentMethod: paymentMethod, tripType: tripType, createdAt: createdAt,
  );

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'],
        tripId: j['trip_id'],
        driverId: j['driver_id'] ?? 0,
        tripOrigin: j['trip_origin'] ?? '',
        tripDestination: j['trip_destination'] ?? '',
        tripDeparture: DateTime.parse(j['trip_departure'] ?? j['created_at']),
        driverName: j['driver_name'] ?? '',
        driverPhone: j['driver_phone'] ?? '',
        pickupName: j['pickup_name'],
        pickupLat: double.tryParse(j['pickup_lat']?.toString() ?? '') ?? 0,
        pickupLng: double.tryParse(j['pickup_lng']?.toString() ?? '') ?? 0,
        dropoffName: j['dropoff_name'],
        dropoffLat: double.tryParse(j['dropoff_lat']?.toString() ?? '') ?? 0,
        dropoffLng: double.tryParse(j['dropoff_lng']?.toString() ?? '') ?? 0,
        seatsBooked: j['seats_booked'],
        fareAtBooking: double.parse(j['fare_at_booking'].toString()),
        fareFinal: j['fare_final'] != null
            ? double.parse(j['fare_final'].toString())
            : null,
        amountDue: double.parse(j['amount_due'].toString()),
        detourFee: double.parse(j['detour_fee'].toString()),
        status: j['status'],
        paymentMethod: j['payment_method'],
        tripType: j['trip_type'] ?? 'city',
        createdAt: DateTime.parse(j['created_at']),
      );
}
