import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

/// Builds a Dio without auth interceptors for `/auth/refresh` calls.
///
/// Shares the same `baseUrl`, 15s timeouts, JSON `Content-Type`, and
/// error-only logging as [ApiClient] so refresh calls stay consistent
/// whether issued from the 401 interceptor or [AuthStore.refresh].
Dio buildUnauthenticatedDio({String? baseUrl}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? '${Config.apiBaseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const <String, dynamic>{'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(
    LogInterceptor(
      request: false,
      requestHeader: false,
      requestBody: false,
      responseHeader: false,
      responseBody: false,
      error: true,
    ),
  );
  return dio;
}

/// Shared Dio client for `Config.apiBaseUrl + /api/v1`.
///
/// Interceptors:
/// - auth: reads `accessToken` from [FlutterSecureStorage] and adds
///   `Authorization: Bearer <token>`.
/// - refresh-on-401: on a single 401, POSTs `/auth/refresh` with the stored
///   `refreshToken` once, persists the rotated tokens, and retries the
///   original request.
/// - logging: minimal (errors only) to avoid leaking tokens/bodies.
class ApiClient {
  final Dio dio;
  final FlutterSecureStorage storage;

  ApiClient({Dio? dio, FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage(),
        dio = dio ?? Dio() {
    this.dio.options = BaseOptions(
      baseUrl: '${Config.apiBaseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const <String, dynamic>{'Content-Type': 'application/json'},
    );
    this.dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await this.storage.read(key: 'accessToken');
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {
            // Storage unavailable (e.g. widget test): proceed unauthenticated.
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          final status = err.response?.statusCode;
          final alreadyRetried = err.requestOptions.extra['_retried'] == true;
          final path = err.requestOptions.path;
          final isAuthEndpoint =
              path.contains('/auth/refresh') ||
              path.contains('/auth/login') ||
              path.contains('/auth/register');

          if (status != 401 || alreadyRetried || isAuthEndpoint) {
            handler.next(err);
            return;
          }

          try {
            final refreshToken =
                await storage.read(key: 'refreshToken');
            if (refreshToken == null || refreshToken.isEmpty) {
              handler.next(err);
              return;
            }

            // Separate Dio without interceptors to avoid refresh loops.
            final refreshDio = buildUnauthenticatedDio();
            final resp = await refreshDio.post<Map<String, dynamic>>(
              '/auth/refresh',
              data: <String, dynamic>{'refreshToken': refreshToken},
            );
            final data = resp.data;
            final newAccess = data?['accessToken'] as String?;
            final newRefresh = data?['refreshToken'] as String?;
            if (newAccess == null || newAccess.isEmpty) {
              handler.next(err);
              return;
            }
            await storage.write(key: 'accessToken', value: newAccess);
            if (newRefresh != null && newRefresh.isNotEmpty) {
              await storage.write(key: 'refreshToken', value: newRefresh);
            }

            err.requestOptions.headers['Authorization'] =
                'Bearer $newAccess';
            err.requestOptions.extra['_retried'] = true;
            final retryResp = await dio.fetch<dynamic>(err.requestOptions);
            handler.resolve(retryResp);
          } on DioException catch (_) {
            handler.next(err);
          } catch (_) {
            handler.next(err);
          }
        },
      ),
    );
    this.dio.interceptors.add(
      LogInterceptor(
        request: false,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
      ),
    );
  }
}

/// Global accessor; features `ref.watch(apiClientProvider)` then use `.dio`.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
