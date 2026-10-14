import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// Immutable auth state held by [AuthStore].
class AuthState {
  final String? accessToken;
  final String? refreshToken;
  final String? role;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.accessToken,
    this.refreshToken,
    this.role,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;
  bool get isAdmin => role == 'admin';

  AuthState copyWith({
    String? accessToken,
    String? refreshToken,
    String? role,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearTokens = false,
  }) {
    return AuthState(
      accessToken: clearTokens ? null : (accessToken ?? this.accessToken),
      refreshToken: clearTokens ? null : (refreshToken ?? this.refreshToken),
      role: clearTokens ? null : (role ?? this.role),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Riverpod [StateNotifier] for session tokens + role.
///
/// Endpoints (base `${Config.apiBaseUrl}/api/v1`, see [ApiClient]):
/// - POST `/auth/register` {email, password, fullName?, phone?}
/// - POST `/auth/login` {email, password}
/// - POST `/auth/refresh` {refreshToken} (rotation)
/// - POST `/auth/logout` {refreshToken?}
/// - GET `/auth/me` -> {id, email, role}
///
/// Tokens persist in [FlutterSecureStorage] under `accessToken` /
/// `refreshToken` so [ApiClient]'s auth interceptor can attach them.
class AuthStore extends StateNotifier<AuthState> {
  final ApiClient api;

  AuthStore(this.api) : super(const AuthState());

  Future<void> loadFromStorage() async {
    try {
      final access = await api.storage.read(key: 'accessToken');
      final refresh = await api.storage.read(key: 'refreshToken');
      if (access == null || access.isEmpty) return;
      state = state.copyWith(
        accessToken: access,
        refreshToken: refresh,
        clearError: true,
      );
      await me();
    } catch (_) {
      // Missing platform plugin in tests: stay logged out.
    }
  }

  Future<void> _saveTokens({
    required String accessToken,
    String? refreshToken,
    String? role,
  }) async {
    state = state.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken ?? state.refreshToken,
      role: role ?? state.role,
      clearError: true,
    );
    try {
      await api.storage.write(key: 'accessToken', value: accessToken);
      final rt = refreshToken ?? state.refreshToken;
      if (rt != null && rt.isNotEmpty) {
        await api.storage.write(key: 'refreshToken', value: rt);
      }
    } catch (_) {
      // Ignore persistence failures; in-memory session still valid.
    }
  }

  Map<String, dynamic>? _dataOf(Response<dynamic> resp) {
    final data = resp.data;
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  String? _errorOf(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] is String) {
        return data['error'] as String;
      }
      return e.message ?? 'request failed';
    }
    return e.toString();
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await api.dio.post<dynamic>(
        '/auth/login',
        data: <String, dynamic>{'email': email, 'password': password},
      );
      final data = _dataOf(resp);
      final access = data?['accessToken'] as String?;
      final refresh = data?['refreshToken'] as String?;
      final user = data?['user'] as Map<String, dynamic>?;
      if (access == null || access.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'invalid response');
        return false;
      }
      await _saveTokens(
        accessToken: access,
        refreshToken: refresh,
        role: user?['role'] as String?,
      );
      // Role from /auth/me is authoritative; ignore failures here.
      try {
        await me();
      } catch (_) {}
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _errorOf(e));
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final body = <String, dynamic>{'email': email, 'password': password};
      if (fullName != null && fullName.isNotEmpty) body['fullName'] = fullName;
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      final resp = await api.dio.post<dynamic>('/auth/register', data: body);
      final data = _dataOf(resp);
      final access = data?['accessToken'] as String?;
      final refresh = data?['refreshToken'] as String?;
      final user = data?['user'] as Map<String, dynamic>?;
      if (access == null || access.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'invalid response');
        return false;
      }
      await _saveTokens(
        accessToken: access,
        refreshToken: refresh,
        role: user?['role'] as String?,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _errorOf(e));
      return false;
    }
  }

  /// Refreshes using the stored refresh token (rotation). Returns true on
  /// success. The [ApiClient] 401 interceptor already covers the passive
  /// path; this is the explicit path for app start / retry buttons.
  Future<bool> refresh() async {
    String? stored = state.refreshToken;
    if (stored == null || stored.isEmpty) {
      try {
        stored = await api.storage.read(key: 'refreshToken');
      } catch (_) {
        stored = null;
      }
    }
    if (stored == null || stored.isEmpty) return false;
    try {
      // Bypass interceptors to avoid re-entrancy (same timeouts/headers/
      // logging as ApiClient via shared factory).
      final plain = buildUnauthenticatedDio(
        baseUrl: api.dio.options.baseUrl,
      );
      final resp = await plain.post<dynamic>(
        '/auth/refresh',
        data: <String, dynamic>{'refreshToken': stored},
      );
      final data = _dataOf(resp);
      final access = data?['accessToken'] as String?;
      final refreshToken = data?['refreshToken'] as String?;
      final user = data?['user'] as Map<String, dynamic>?;
      if (access == null || access.isEmpty) return false;
      await _saveTokens(
        accessToken: access,
        refreshToken: refreshToken,
        role: user?['role'] as String? ?? state.role,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: _errorOf(e));
      return false;
    }
  }

  /// Fetches `GET /auth/me` to populate [AuthState.role].
  Future<void> me() async {
    if (!state.isAuthenticated) return;
    try {
      final resp = await api.dio.get<dynamic>('/auth/me');
      final data = _dataOf(resp);
      final role = data?['role'] as String?;
      if (role != null) {
        state = state.copyWith(role: role, clearError: true);
      }
    } catch (e) {
      // Keep existing session; surface only if we have no role yet.
      if (state.role == null) {
        state = state.copyWith(error: _errorOf(e));
      }
    }
  }

  Future<void> logout() async {
    final logoutData = <String, dynamic>{};
    final rt = state.refreshToken;
    if (rt != null) logoutData['refreshToken'] = rt;
    try {
      await api.dio.post<dynamic>(
        '/auth/logout',
        data: logoutData,
      );
    } catch (_) {
      // Server logout is best-effort; always clear locally.
    }
    try {
      await api.storage.delete(key: 'accessToken');
      await api.storage.delete(key: 'refreshToken');
    } catch (_) {}
    state = const AuthState();
  }
}

final authStoreProvider =
    StateNotifierProvider<AuthStore, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthStore(api);
});
