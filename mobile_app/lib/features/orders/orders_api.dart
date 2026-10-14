import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// Order line item (`OrderItem`: `name`, `unitPrice`, `qty`, `lineTotal`).
class OrderItem {
  final int productId;
  final String name;
  final int unitPrice;
  final int qty;
  final int lineTotal;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.qty,
    required this.lineTotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return OrderItem(
      productId: asInt(json['productId']),
      name: json['name'] as String? ?? '',
      unitPrice: asInt(json['unitPrice']),
      qty: asInt(json['qty']),
      lineTotal: asInt(json['lineTotal']),
    );
  }
}

/// Order summary from `GET /orders` (includes `items`, `payment`).
class OrderSummary {
  final int id;
  final String status;
  final int total;
  final int itemCount;
  final String paymentMethod;
  final String paymentStatus;
  final String createdAt;

  const OrderSummary({
    required this.id,
    required this.status,
    required this.total,
    required this.itemCount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    final payment = json['payment'];
    final items = json['items'];
    final count = json['_count'];
    return OrderSummary(
      id: asInt(json['id']),
      status: json['status'] as String? ?? 'pending',
      total: asInt(json['total']),
      itemCount: count is Map
          ? asInt(count['items'])
          : (items is List ? items.length : 0),
      paymentMethod:
          payment is Map ? payment['method'] as String? ?? 'COD' : 'COD',
      paymentStatus:
          payment is Map ? payment['status'] as String? ?? 'unpaid' : 'unpaid',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

/// Full order from `GET /orders/:id` (includes `items`, `payment`, `address`).
class OrderDetail {
  final int id;
  final String status;
  final int subtotal;
  final int deliveryFee;
  final int total;
  final String paymentMethod;
  final String paymentStatus;
  final int paymentAmount;
  final List<OrderItem> items;
  final String createdAt;
  final String? addressLine;

  const OrderDetail({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paymentAmount,
    required this.items,
    required this.createdAt,
    required this.addressLine,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    final payment = json['payment'];
    final rawItems = json['items'];
    final address = json['address'];
    return OrderDetail(
      id: asInt(json['id']),
      status: json['status'] as String? ?? 'pending',
      subtotal: asInt(json['subtotal']),
      deliveryFee: asInt(json['deliveryFee']),
      total: asInt(json['total']),
      paymentMethod:
          payment is Map ? payment['method'] as String? ?? 'COD' : 'COD',
      paymentStatus:
          payment is Map ? payment['status'] as String? ?? 'unpaid' : 'unpaid',
      paymentAmount: payment is Map ? asInt(payment['amount']) : 0,
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(OrderItem.fromJson)
              .toList()
          : const [],
      createdAt: json['createdAt'] as String? ?? '',
      addressLine: address is Map
          ? '${address['line1'] ?? ''}, ${address['city'] ?? ''}'
          : null,
    );
  }
}

/// Customer order history: `GET /orders` (own list, newest first) and
/// `GET /orders/:id` (own order or 404). Auth via [ApiClient].
class OrdersApi {
  final Dio dio;

  OrdersApi(this.dio);

  Future<List<OrderSummary>> list() async {
    final resp = await dio.get<dynamic>('/orders');
    final data = resp.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(OrderSummary.fromJson)
          .toList();
    }
    return const [];
  }

  Future<OrderDetail> detail(int id) async {
    final resp = await dio.get<dynamic>('/orders/$id');
    return OrderDetail.fromJson(resp.data as Map<String, dynamic>);
  }
}

final ordersApiProvider = Provider<OrdersApi>((ref) {
  return OrdersApi(ref.watch(apiClientProvider).dio);
});
