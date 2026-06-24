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
  @override
  AuthState build() => const AuthState();

  Future<void> loadCurrentUser() async {
    final token = await AppStorage.getAccessToken();
    if (token == null) return;
    try {
      final resp = await ApiClient.dio.get(Endpoints.me);
      state = AuthState(user: User.fromJson(resp.data));
    } catch (_) {
      await AppStorage.clear();
    }
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
      await AppStorage.saveTokens(data['access'] as String, data['refresh'] as String);
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      await AppStorage.saveUserInfo(user.id, user.role);
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
      await AppStorage.saveTokens(data['access'] as String, data['refresh'] as String);
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      await AppStorage.saveUserInfo(user.id, user.role);
      state = AuthState(user: user);
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

  void setUser(User user) {
    state = AuthState(user: user);
  }

  void updateProfile({String? fullName, String? phoneNumber}) {
    final u = state.user;
    if (u == null) { return; }
    state = state.copyWith(
      user: User(
        id: u.id,
        phoneNumber: phoneNumber ?? u.phoneNumber,
        fullName: fullName ?? u.fullName,
        role: u.role,
        profilePhoto: u.profilePhoto,
        strikeCount: u.strikeCount,
        isBanned: u.isBanned,
      ),
    );
  }

  Future<void> logout() async {
    await AppStorage.clear();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
