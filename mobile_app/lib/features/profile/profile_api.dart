import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// `GET /profile` returns `{user: {id, email, role}, profile}`.
/// `PATCH /profile` accepts `{fullName?, phone?}` and returns the profile.
class ProfileData {
  final int id;
  final String email;
  final String role;
  final String? fullName;
  final String? phone;

  const ProfileData({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    required this.phone,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final profile = json['profile'];
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    if (user is Map) {
      final p = profile is Map ? profile : null;
      return ProfileData(
        id: asInt(user['id']),
        email: user['email'] as String? ?? '',
        role: user['role'] as String? ?? 'customer',
        fullName: p?['fullName'] as String?,
        phone: p?['phone'] as String?,
      );
    }
    // PATCH shape: the profile row itself.
    return ProfileData(
      id: asInt(json['userId']),
      email: '',
      role: '',
      fullName: json['fullName'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class ProfileApi {
  final Dio dio;

  ProfileApi(this.dio);

  Future<ProfileData> get() async {
    final resp = await dio.get<dynamic>('/profile');
    return ProfileData.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ProfileData> patch({String? fullName, String? phone}) async {
    final resp = await dio.patch<dynamic>(
      '/profile',
      data: <String, dynamic>{
        if (fullName != null) 'fullName': fullName,
        if (phone != null) 'phone': phone,
      },
    );
    return ProfileData.fromJson(resp.data as Map<String, dynamic>);
  }
}

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(ref.watch(apiClientProvider).dio);
});
