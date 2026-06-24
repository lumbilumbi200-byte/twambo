import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/api/api_client.dart';
import 'core/api/endpoints.dart';
import 'features/auth/auth_provider.dart';

// Set to true once android/app/google-services.json is added from Firebase console
const _kFirebaseEnabled = false;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (_kFirebaseEnabled) await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_kFirebaseEnabled) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  runApp(const ProviderScope(child: AppBootstrap()));
}

Future<void> registerFcmToken() async {
  if (!_kFirebaseEnabled) return;
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
  } catch (_) {
    // Never crash the app over a push token failure
  }
}

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ref.read(authProvider.notifier).loadCurrentUser();
    final isLoggedIn = ref.read(authProvider).isLoggedIn;
    if (isLoggedIn) {
      // Register push token in background — don't block startup
      registerFcmToken();
    }
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return const TwamboApp();
  }
}
