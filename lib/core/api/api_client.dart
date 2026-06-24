import 'package:dio/dio.dart';
import '../storage.dart';
import 'endpoints.dart';

class ApiClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: Endpoints.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {'Content-Type': 'application/json'},
  ));

  static bool _interceptorAdded = false;

  static Dio get dio {
    if (!_interceptorAdded) {
      _dio.interceptors.add(_AuthInterceptor());
      _interceptorAdded = true;
    }
    return _dio;
  }
}

class _AuthInterceptor extends Interceptor {
  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await AppStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    handler.next(options); // always called — never hangs
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      final refreshed = await _tryRefresh();
      _isRefreshing = false;

      if (refreshed) {
        final token = await AppStorage.getAccessToken();
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $token';
        try {
          final response = await ApiClient.dio.fetch(opts);
          handler.resolve(response);
          return;
        } catch (_) {}
      }
      await AppStorage.clear();
    }
    handler.next(err);
  }

  Future<bool> _tryRefresh() async {
    try {
      final refresh = await AppStorage.getRefreshToken();
      if (refresh == null) return false;
      final resp = await Dio().post(
        '${Endpoints.baseUrl}${Endpoints.tokenRefresh}',
        data: {'refresh': refresh},
      );
      final access = resp.data['access'] as String;
      final newRefresh = resp.data['refresh'] as String?;
      await AppStorage.saveTokens(access, newRefresh ?? refresh);
      return true;
    } catch (_) {
      return false;
    }
  }
}
