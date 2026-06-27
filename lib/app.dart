import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/rider/screens/trip_search_screen.dart';
import 'features/rider/screens/trip_detail_screen.dart';
import 'features/rider/screens/my_bookings_screen.dart';
import 'features/driver/screens/driver_home_screen.dart';
import 'features/driver/screens/create_trip_screen.dart';
import 'features/driver/screens/trip_manage_screen.dart';
import 'features/driver/screens/wallet_screen.dart';
import 'features/driver/screens/recurring_trips_screen.dart';
import 'features/driver/screens/driver_trips_screen.dart';
import 'features/driver/screens/driver_earnings_screen.dart';
import 'features/driver/screens/driver_profile_screen.dart';
import 'features/driver/screens/driver_requests_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/rider/screens/profile_screen.dart';
import 'dev/kitwe_places.dart';
import 'features/rider/screens/request_ride_screen.dart';
import 'features/realtime/driver_gps_screen.dart';
import 'features/realtime/rider_tracking_screen.dart';
import 'features/driver/screens/driver_pending_screen.dart';
import 'shared/app_providers.dart';
import 'shared/theme.dart';

// ── Auth-aware redirect notifier ──────────────────────────────────────────────

const _publicRoutes = {'/login', '/register'};
const _driverRoutes = {
  '/driver', '/driver/create', '/driver/wallet',
  '/driver/recurring', '/driver/riders', '/driver/earnings', '/driver/profile',
};

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    // Re-evaluate redirect whenever auth state changes
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);
    final loc = state.matchedLocation;
    final isPublic = _publicRoutes.contains(loc);

    if (!auth.isLoggedIn) {
      return isPublic ? null : '/login';
    }

    final user = auth.user!;

    // Logged-in → bounce away from auth screens
    if (isPublic) {
      if (user.isDriver) {
        return user.isApprovedDriver ? '/driver' : '/driver-pending';
      }
      return '/search';
    }

    // Unapproved driver trying to reach anything except /driver-pending
    if (user.isDriver && !user.isApprovedDriver && loc != '/driver-pending') {
      return '/driver-pending';
    }

    // Approved driver on the pending screen → send home
    if (user.isDriver && user.isApprovedDriver && loc == '/driver-pending') {
      return '/driver';
    }

    // Rider trying to reach driver-only routes
    if (!user.isDriver && _driverRoutes.any((r) => loc.startsWith(r))) {
      return '/search';
    }

    // Driver trying to reach rider search
    if (user.isDriver && loc == '/search') {
      return '/driver';
    }

    return null;
  }
}

// ── Router provider ───────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // Rider
      GoRoute(path: '/search',   builder: (_, __) => const TripSearchScreen()),
      GoRoute(
        path: '/trip/:id',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return TripDetailScreen(
            tripId: int.parse(state.pathParameters['id']!),
            pickupName: q['pickup'],
            pickupLat: double.tryParse(q['pickupLat'] ?? ''),
            pickupLng: double.tryParse(q['pickupLng'] ?? ''),
            dropoffName: q['dropoffName'],
            dropoffLat: double.tryParse(q['dropoffLat'] ?? ''),
            dropoffLng: double.tryParse(q['dropoffLng'] ?? ''),
          );
        },
      ),
      GoRoute(path: '/bookings', builder: (_, __) => const MyBookingsScreen()),
      GoRoute(path: '/profile',  builder: (_, __) => const ProfileScreen()),
      GoRoute(
        path: '/request-ride',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          final from = KitwePlace(q['fromName']!, double.parse(q['fromLat']!), double.parse(q['fromLng']!));
          final to   = KitwePlace(q['toName']!,   double.parse(q['toLat']!),   double.parse(q['toLng']!));
          return RequestRideScreen(from: from, to: to);
        },
      ),

      // Driver
      GoRoute(path: '/driver-pending',  builder: (_, __) => const DriverPendingScreen()),
      GoRoute(path: '/driver',          builder: (_, __) => const DriverHomeScreen()),
      GoRoute(path: '/driver/create',   builder: (_, __) => const CreateTripScreen()),
      GoRoute(
        path: '/driver/trip/:id',
        builder: (_, state) => TripManageScreen(tripId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/driver/requests',  builder: (_, __) => const DriverRequestsScreen()),
      GoRoute(path: '/driver/wallet',    builder: (_, __) => const WalletScreen()),
      GoRoute(path: '/driver/recurring', builder: (_, __) => const RecurringTripsScreen()),
      GoRoute(path: '/driver/trips',     builder: (_, __) => const DriverTripsScreen()),
      GoRoute(path: '/driver/riders',    builder: (_, __) => const DriverTripsScreen()),
      GoRoute(path: '/driver/earnings',  builder: (_, __) => const DriverEarningsScreen()),
      GoRoute(path: '/driver/profile',   builder: (_, __) => const DriverProfileScreen()),

      // Shared
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),

      // Realtime
      GoRoute(
        path: '/driver/gps/:tripId/:driverId',
        builder: (_, state) => DriverGpsScreen(
          tripId:   int.parse(state.pathParameters['tripId']!),
          driverId: int.parse(state.pathParameters['driverId']!),
        ),
      ),
      GoRoute(
        path: '/tracking/:tripId/:driverId',
        builder: (_, state) => RiderTrackingScreen(
          tripId:     int.parse(state.pathParameters['tripId']!),
          driverId:   int.parse(state.pathParameters['driverId']!),
          driverName: state.uri.queryParameters['driverName'] ?? 'Driver',
          originName: state.uri.queryParameters['originName'] ?? '',
          pickupLat:  double.tryParse(state.uri.queryParameters['pickupLat'] ?? '') ?? 0,
          pickupLng:  double.tryParse(state.uri.queryParameters['pickupLng'] ?? '') ?? 0,
        ),
      ),
    ],
  );
});

// ── App root ──────────────────────────────────────────────────────────────────

class TwamboApp extends ConsumerWidget {
  const TwamboApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'TWMB',
      theme: twamboTheme(),
      darkTheme: twamboDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
