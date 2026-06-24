// In-memory token store — works on all platforms with zero dependencies.
// Tokens are lost on app restart (fine for dev; swap for SharedPreferences in prod).
class AppStorage {
  static String? _access;
  static String? _refresh;
  static String? _userId;
  static String? _role;

  static Future<void> saveTokens(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
  }

  static Future<String?> getAccessToken() async => _access;
  static Future<String?> getRefreshToken() async => _refresh;

  static Future<void> saveUserInfo(int id, String role) async {
    _userId = id.toString();
    _role = role;
  }

  static Future<String?> getRole() async => _role;
  static Future<String?> getUserId() async => _userId;

  static Future<void> clear() async {
    _access = null;
    _refresh = null;
    _userId = null;
    _role = null;
  }
}
