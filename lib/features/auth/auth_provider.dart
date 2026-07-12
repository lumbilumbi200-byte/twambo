import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/models/user.dart';
import '../../core/storage.dart';
import '../../main.dart' show registerFcmToken;

class AuthState {
  final User? user;
  final String? error;

  const AuthState({this.user, this.error});

  bool get isLoggedIn => user != null;

  AuthState copyWith({User? user, String? error, bool clearError = false}) => AuthState(
        user: user ?? this.user,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthNotifier extends Notifier<AuthState> {
  // Held in memory until OTP verification completes
  String? _pendingAccess;
  String? _pendingRefresh;
  User?   _pendingUser;

  @override
  AuthState build() => const AuthState();

  Future<void> loadCurrentUser() async {
    final token = await AppStorage.getAccessToken();
    if (token == null) return;

    // Restore instantly from the cached profile — no network needed.
    // This means the app opens immediately and the user is never logged out
    // because of a slow/sleeping backend (Render cold start, no signal, etc.)
    final cached = await AppStorage.getCachedUser();
    if (cached != null) {
      state = AuthState(user: User.fromJson(cached));
    }

    // Refresh profile in the background so data stays current.
    // Only log out on a real 401 — network errors must never clear tokens.
    _backgroundRefresh();
  }

  void _backgroundRefresh() {
    Future.microtask(() async {
      try {
        final resp = await ApiClient.dio.get(Endpoints.me);
        final json = resp.data as Map<String, dynamic>;
        await AppStorage.cacheUser(json);
        if (state.isLoggedIn) state = AuthState(user: User.fromJson(json));
      } on DioException catch (e) {
        // 401 means both access AND refresh tokens are invalid — force logout
        if (e.response?.statusCode == 401) {
          await AppStorage.clear();
          state = const AuthState();
        }
        // Any other error (timeout, no internet, 5xx): stay logged in with cached data
      } catch (_) {}
    });
  }

  // Returns error string or null on success
  Future<String?> login(String phone, String password) async {
    state = state.copyWith(clearError: true);
    try {
      final resp = await ApiClient.dio.post(Endpoints.login, data: {
        'phone_number': phone,
        'password': password,
      });
      final data = resp.data as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;
      await AppStorage.saveTokens(data['access'] as String, data['refresh'] as String);
      final user = User.fromJson(userJson);
      await AppStorage.saveUserInfo(user.id, user.role);
      await AppStorage.cacheUser(userJson);
      state = AuthState(user: user);
      registerFcmToken(); // fire-and-forget
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        return (data['detail'] ?? data['non_field_errors']?.first ?? data.values.first?.first ?? 'Invalid credentials').toString();
      }
      return 'DIO ${e.type.name}: ${e.error ?? e.message}';
    } catch (e) {
      return 'ERROR: $e';
    }
  }

  Future<String?> register({
    required String phone,
    required String fullName,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(clearError: true);
    try {
      final resp = await ApiClient.dio.post(Endpoints.register, data: {
        'phone_number': phone,
        'full_name': fullName,
        'password': password,
        'role': role,
      });
      final data = resp.data as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;
      await AppStorage.saveTokens(data['access'] as String, data['refresh'] as String);
      final user = User.fromJson(userJson);
      await AppStorage.saveUserInfo(user.id, user.role);
      await AppStorage.cacheUser(userJson);
      state = AuthState(user: user);
      registerFcmToken();
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        return (data['detail'] ?? data.values.first?.first ?? 'Registration failed').toString();
      }
      return 'DIO ${e.type.name}: ${e.error ?? e.message}';
    } catch (e) {
      return 'ERROR: $e';
    }
  }

  Future<void> completeRegistration() async {
    if (_pendingAccess == null || _pendingUser == null) return;
    await AppStorage.saveTokens(_pendingAccess!, _pendingRefresh!);
    await AppStorage.saveUserInfo(_pendingUser!.id, _pendingUser!.role);
    // Cache what we have — background refresh will fill in full profile
    await AppStorage.cacheUser({
      'id': _pendingUser!.id, 'phone_number': _pendingUser!.phoneNumber,
      'full_name': _pendingUser!.fullName, 'role': _pendingUser!.role,
      'strike_count': 0, 'is_banned': false, 'fare_surcharge_pct': 0,
    });
    state = AuthState(user: _pendingUser!);
    _pendingAccess  = null;
    _pendingRefresh = null;
    _pendingUser    = null;
    registerFcmToken();
  }

  void setUser(User user) {
    state = AuthState(user: user);
  }

  Future<String?> updateProfile({String? fullName, String? phoneNumber}) async {
    if (state.user == null) return null;
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;
      final resp = await ApiClient.dio.patch(Endpoints.me, data: body);
      state = state.copyWith(user: User.fromJson(resp.data as Map<String, dynamic>));
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        return (data['detail'] ?? data.values.first?.first ?? 'Update failed').toString();
      }
      return 'Update failed';
    } catch (_) {
      return 'Update failed';
    }
  }

  Future<void> logout() async {
    await AppStorage.clear();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
