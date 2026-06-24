class Endpoints {
  // 10.0.2.2 = Android emulator → host localhost. Change to localhost for Windows desktop dev.
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';

  // Auth
  static const String register = '/auth/register/';
  static const String login = '/auth/login/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String me = '/auth/me/';
  static const String fcmToken = '/auth/fcm-token/';
  static const String driverProfile = '/auth/driver/profile/';
  static const String driverDocuments = '/auth/driver/documents/';
  static const String driverOnline = '/auth/driver/online/';
  static const String driverVehicle = '/auth/driver/vehicle/';
  static const String riderProfile = '/auth/rider/profile/';
  static const String savedPlaces = '/auth/rider/saved-places/';

  // Trips
  static const String tripSearch = '/trips/search/';
  static const String driverTripCreate = '/trips/driver/create/';
  static const String driverTrips = '/trips/driver/';
  static String driverTripDetail(int id) => '/trips/driver/$id/';
  static String tripStart(int id) => '/trips/driver/$id/start/';
  static String tripComplete(int id) => '/trips/driver/$id/complete/';
  static String tripCancel(int id) => '/trips/driver/$id/cancel/';
  static String tripDetail(int id) => '/trips/$id/';
  static const String recurringTrips = '/trips/driver/recurring/';
  static String recurringTripDetail(int id) => '/trips/driver/recurring/$id/';
  static const String createRideRequest = '/trips/ride-requests/';
  static const String myRideRequests = '/trips/ride-requests/';
  static String cancelRideRequest(int id) => '/trips/ride-requests/$id/cancel/';

  // Bookings
  static const String createBooking = '/bookings/';
  static const String myBookings = '/bookings/my/';
  static String bookingDetail(int id) => '/bookings/my/$id/';
  static String cancelBooking(int id) => '/bookings/my/$id/cancel/';
  static String tripBookings(int tripId) => '/bookings/trip/$tripId/';
  static const String driverBroadcastRequests = '/trips/driver/broadcast-requests/';
  static String tripRideRequests(int tripId) => '/trips/driver/$tripId/requests/';
  static String closeBookingWindow(int tripId) => '/trips/driver/$tripId/close-window/';
  static String acceptRideRequest(int tripId, int requestId) => '/trips/driver/$tripId/requests/$requestId/accept/';
  static String rejectRideRequest(int tripId, int requestId) => '/trips/driver/$tripId/requests/$requestId/reject/';
  static String markNoShow(int bookingId) => '/bookings/$bookingId/no-show/';
  static String submitRating(int bookingId) => '/bookings/$bookingId/rate/';
  static String myRatingForBooking(int bookingId) => '/bookings/$bookingId/my-rating/';

  // Pricing
  static const String fareCalculate = '/pricing/calculate/';

  // Driver finance
  static const String driverFinancePrefs = '/auth/driver/finance-prefs/';

  // Payments
  static const String wallet = '/payments/wallet/';
  static const String walletTopup = '/payments/wallet/topup/';
  static const String walletTransactions = '/payments/wallet/transactions/';
  static const String commissions = '/payments/commissions/';
  static const String operationalLogs = '/payments/operational-logs/';
  static String deleteOperationalLog(int id) => '/payments/operational-logs/$id/';
  static const String budgetSuggestion = '/payments/budget-suggestion/';
  static const String dismissBudget = '/payments/budget-suggestion/dismiss/';

  // Notifications
  static const String notifications = '/notifications/';
  static const String markAllRead = '/notifications/read-all/';
  static String markRead(int id) => '/notifications/$id/read/';

  // Marketing
  static const String marketingSlides = '/slides/';
}
