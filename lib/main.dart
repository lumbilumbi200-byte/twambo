import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';
import 'core/api/api_client.dart';
import 'core/api/endpoints.dart';
import 'core/services/version_check_service.dart';
import 'features/auth/auth_provider.dart';
import 'shared/widgets/update_gate.dart';

// ── Local notifications setup ─────────────────────────────────────────────────

const _androidChannel = AndroidNotificationChannel(
  'twambo_high',
  'Twambo Alerts',
  description: 'Ride updates, bookings and driver alerts',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

Future<void> _initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _localNotifications.initialize(const InitializationSettings(android: android));
  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);
}

void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;
  _localNotifications.show(
    notification.hashCode,
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

// Background handler — must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// ── FCM token registration ────────────────────────────────────────────────────

Future<void> registerFcmToken() async {
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await messaging.getToken();
    if (token != null) {
      await ApiClient.dio.post(Endpoints.fcmToken, data: {'fcm_token': token});
    }
    messaging.onTokenRefresh.listen((newToken) async {
      try {
        await ApiClient.dio.post(Endpoints.fcmToken, data: {'fcm_token': newToken});
      } catch (_) {}
    });
  } catch (_) {}
}

// ── Entry point ───────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _initLocalNotifications();

  // Show notification when app is in the foreground
  FirebaseMessaging.onMessage.listen(_showLocalNotification);

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // Prevent FCM from auto-displaying heads-up notifications on Android
  // (we show them ourselves via flutter_local_notifications so we control the channel)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: false,
    badge: false,
    sound: false,
  );

  runApp(const ProviderScope(child: AppBootstrap()));
}

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  bool _ready = false;
  VersionResult? _versionResult;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      ref.read(authProvider.notifier).loadCurrentUser(),
      VersionCheckService.check(),
    ]);
    _versionResult = results[1] as VersionResult?;

    final isLoggedIn = ref.read(authProvider).isLoggedIn;
    if (isLoggedIn) registerFcmToken();

    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (_versionResult?.isForceUpdate == true) {
      return ForceUpdateScreen(result: _versionResult!);
    }
    return TwamboApp(
      softUpdate: _versionResult?.isSoftUpdate == true ? _versionResult : null,
    );
  }
}
