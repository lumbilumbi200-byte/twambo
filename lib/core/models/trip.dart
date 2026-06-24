class Trip {
  final int id;
  final int driverId;
  final String driverName;
  final String vehicleType;
  final String vehicleMakeModel;
  final String originName;
  final double originLat;
  final double originLng;
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final DateTime departureTime;
  final String status;
  final String mode;
  final int totalSeats;
  final int availableSeats;
  final int seatsTaken;
  final double currentSharedFare;
  final double privateFare;
  final bool bookingWindowOpen;
  final DateTime? bookingWindowClosesAt;
  final int minimumRiders;

  const Trip({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.vehicleType,
    required this.vehicleMakeModel,
    required this.originName,
    required this.originLat,
    required this.originLng,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.departureTime,
    required this.status,
    required this.mode,
    required this.totalSeats,
    required this.availableSeats,
    required this.seatsTaken,
    required this.currentSharedFare,
    required this.privateFare,
    required this.bookingWindowOpen,
    this.bookingWindowClosesAt,
    required this.minimumRiders,
  });

  bool get isShared => mode == 'shared';
  bool get isPrivate => mode == 'private';
  bool get isScheduled => status == 'scheduled';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  Trip copyWith({String? status, int? availableSeats, int? seatsTaken, bool? bookingWindowOpen}) => Trip(
    id: id, driverId: driverId, driverName: driverName, vehicleType: vehicleType,
    vehicleMakeModel: vehicleMakeModel, originName: originName, originLat: originLat,
    originLng: originLng, destinationName: destinationName, destinationLat: destinationLat,
    destinationLng: destinationLng, departureTime: departureTime,
    status: status ?? this.status, mode: mode,
    totalSeats: totalSeats, availableSeats: availableSeats ?? this.availableSeats,
    seatsTaken: seatsTaken ?? this.seatsTaken, currentSharedFare: currentSharedFare,
    privateFare: privateFare, bookingWindowOpen: bookingWindowOpen ?? this.bookingWindowOpen,
    bookingWindowClosesAt: bookingWindowClosesAt, minimumRiders: minimumRiders,
  );

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'],
        driverId: j['driver_id'] ?? 0,
        driverName: j['driver_name'] ?? '',
        vehicleType: j['vehicle_type'] ?? '',
        vehicleMakeModel: j['vehicle_make_model'] ?? '',
        originName: j['origin_name'],
        originLat: double.parse(j['origin_lat'].toString()),
        originLng: double.parse(j['origin_lng'].toString()),
        destinationName: j['destination_name'],
        destinationLat: double.parse(j['destination_lat'].toString()),
        destinationLng: double.parse(j['destination_lng'].toString()),
        departureTime: DateTime.parse(j['departure_time']),
        status: j['status'],
        mode: j['mode'],
        totalSeats: j['total_seats'],
        availableSeats: j['available_seats'],
        seatsTaken: j['seats_taken'] ?? 0,
        currentSharedFare: double.parse(j['current_shared_fare'].toString()),
        privateFare: double.parse(j['private_fare'].toString()),
        bookingWindowOpen: j['booking_window_open'] ?? true,
        bookingWindowClosesAt: j['booking_window_closes_at'] != null
            ? DateTime.parse(j['booking_window_closes_at']).toLocal()
            : null,
        minimumRiders: j['minimum_riders'] ?? 1,
      );
}
