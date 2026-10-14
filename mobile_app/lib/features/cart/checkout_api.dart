import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// Order DTO returned by `POST /checkout` (and `GET /orders*`).
/// Totals (`subtotal`, `deliveryFee`, `total`) always come from the server —
/// the client never sends prices.
class CheckoutOrder {
  final int id;
  final int subtotal;
  final int deliveryFee;
  final int total;
  final String status;
  final Map<String, dynamic>? payment;

  const CheckoutOrder({
    required this.id,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.status,
    required this.payment,
  });

  factory CheckoutOrder.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    final payment = json['payment'];
    return CheckoutOrder(
      id: asInt(json['id']),
      subtotal: asInt(json['subtotal']),
      deliveryFee: asInt(json['deliveryFee']),
      total: asInt(json['total']),
      status: json['status'] as String? ?? 'pending',
      payment: payment is Map<String, dynamic> ? payment : null,
    );
  }

  String get paymentStatus => payment?['status'] as String? ?? 'unpaid';
  String get paymentMethod => payment?['method'] as String? ?? 'COD';
}

/// `POST /checkout {addressId, items: [{productId, qty}], idempotencyKey}`.
/// Items carry ids + quantities only; pricing, stock checks, and totals are
/// all server-side. 200 = idempotent replay of the same key, 201 = created.
class CheckoutApi {
  final Dio dio;

  CheckoutApi(this.dio);

  Future<CheckoutOrder> place({
    required int addressId,
    required List<({int productId, int qty})> items,
    required String idempotencyKey,
  }) async {
    final resp = await dio.post<dynamic>(
      '/checkout',
      data: <String, dynamic>{
        'addressId': addressId,
        'items': [
          for (final i in items)
            {'productId': i.productId, 'qty': i.qty},
        ],
        'idempotencyKey': idempotencyKey,
      },
    );
    return CheckoutOrder.fromJson(resp.data as Map<String, dynamic>);
  }
}

final checkoutApiProvider = Provider<CheckoutApi>((ref) {
  return CheckoutApi(ref.watch(apiClientProvider).dio);
});
