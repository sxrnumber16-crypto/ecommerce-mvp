import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// Address model mirroring `GET /addresses` / `POST /addresses`.
class Address {
  final int id;
  final String label;
  final String line1;
  final String city;
  final String? postal;
  final String phone;
  final bool isDefault;

  const Address({
    required this.id,
    required this.label,
    required this.line1,
    required this.city,
    required this.postal,
    required this.phone,
    required this.isDefault,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: (json['id'] as num).toInt(),
      label: json['label'] as String? ?? 'home',
      line1: json['line1'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postal: json['postal'] as String?,
      phone: json['phone'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

/// `GET /addresses` (ordered `isDefault` first, server-side) and
/// `POST /addresses` (`{label, line1, city, postal?, phone, isDefault?}`).
class AddressApi {
  final Dio dio;

  AddressApi(this.dio);

  Future<List<Address>> list() async {
    final resp = await dio.get<dynamic>('/addresses');
    final data = resp.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Address.fromJson)
          .toList();
    }
    return const [];
  }

  Future<Address> create({
    required String label,
    required String line1,
    required String city,
    String? postal,
    required String phone,
    bool? isDefault,
  }) async {
    final data = <String, dynamic>{
      'label': label,
      'line1': line1,
      'city': city,
      'phone': phone,
    };
    if (postal != null && postal.isNotEmpty) data['postal'] = postal;
    if (isDefault != null) data['isDefault'] = isDefault;
    final resp = await dio.post<dynamic>(
      '/addresses',
      data: data,
    );
    return Address.fromJson(resp.data as Map<String, dynamic>);
  }
}

final addressApiProvider = Provider<AddressApi>((ref) {
  return AddressApi(ref.watch(apiClientProvider).dio);
});
