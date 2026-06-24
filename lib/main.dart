import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/auth/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase.initializeApp() goes here once google-services.json is added.
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: AppBootstrap()));
}

// Called after a successful login/session-restore to register the device push token.
// No-op until firebase_messaging is added to pubspec.yaml.
Future<void> registerFcmToken() async {
  try {
    // Uncomment once firebase_messaging is in pubspec.yaml:
    // final messaging = FirebaseMessaging.instance;
    // await messaging.requestPermission();
    // final token = await messaging.getToken();
    // if (token != null) {
    //   await ApiClient.dio.post(Endpoints.fcmToken, data: {'token': token});
    // }
    // messaging.onTokenRefresh.listen((newToken) async {
    //   try { await ApiClient.dio.post(Endpoints.fcmToken, data: {'token': newToken}); }
    //   catch (_) {}
    // });
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
