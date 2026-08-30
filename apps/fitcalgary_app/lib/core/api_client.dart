import 'package:dio/dio.dart';

import 'auth_service.dart';
import 'cache_store.dart';

class ApiClient {
  ApiClient(this.auth)
    : dio = Dio(
        BaseOptions(
          baseUrl: const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:4000/api/v1',
          ),
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await auth.current();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer ${token.accessToken}';
          }
          options.headers['Accept'] = 'application/json';
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['retried'] != true) {
            final token = await auth.refresh();
            if (token != null) {
              final request = error.requestOptions
                ..extra['retried'] = true
                ..headers['Authorization'] = 'Bearer ${token.accessToken}';
              try {
                return handler.resolve(await dio.fetch(request));
              } catch (_) {}
            }
          }
          handler.next(error);
        },
      ),
    );
  }
  final AuthService auth;
  final Dio dio;
  final CacheStore cache = CacheStore();
  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    return (response.data?['data'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> cachedList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final cacheKey = '$path?${query ?? const {}}';
    try {
      final result = await list(path, query: query);
      await cache.write(cacheKey, result);
      return result;
    } on DioException {
      final cached = await cache.read(cacheKey, allowStale: true);
      if (cached != null) return cached;
      rethrow;
    }
  }
}
