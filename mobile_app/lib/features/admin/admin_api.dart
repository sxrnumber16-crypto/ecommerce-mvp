import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// Low-stock row from `GET /admin/dashboard` (`lowStock` select:
/// `id, name, slug, stock, priceBdt, isActive`).
class LowStockItem {
  final int id;
  final String name;
  final String slug;
  final int stock;
  final int priceBdt;
  final bool isActive;

  const LowStockItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.stock,
    required this.priceBdt,
    required this.isActive,
  });

  factory LowStockItem.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return LowStockItem(
      id: asInt(json['id']),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      stock: asInt(json['stock']),
      priceBdt: asInt(json['priceBdt']),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// Dashboard from `GET /admin/dashboard`:
/// `{users, products, activeProducts, ordersByStatus, lowStock, revenue}`.
/// Backend also aliases `orders`/`totalRevenue`/`lowStockCount`; read the
/// canonical keys with fallbacks.
class DashboardSummary {
  final int users;
  final int products;
  final int activeProducts;
  final Map<String, int> ordersByStatus;
  final List<LowStockItem> lowStock;
  final int revenue;

  const DashboardSummary({
    required this.users,
    required this.products,
    required this.activeProducts,
    required this.ordersByStatus,
    required this.lowStock,
    required this.revenue,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    final rawStatus =
        json['ordersByStatus'] ?? json['orders'] as Object?;
    final status = <String, int>{};
    if (rawStatus is Map) {
      rawStatus.forEach((k, v) {
        status[k.toString()] = asInt(v);
      });
    }
    final rawLow = json['lowStock'];
    return DashboardSummary(
      users: asInt(json['users']),
      products: asInt(json['products']),
      activeProducts: asInt(json['activeProducts']),
      ordersByStatus: status,
      lowStock: rawLow is List
          ? rawLow
              .whereType<Map<String, dynamic>>()
              .map(LowStockItem.fromJson)
              .toList()
          : const [],
      revenue: asInt(json['revenue'] ?? json['totalRevenue']),
    );
  }
}

/// Order row from `GET /admin/orders` (includes `items`, `payment`,
/// `user{id, email}`). Payment status (`unpaid`/`paid`) is toggleable by
/// admins via `PATCH /admin/orders/:id/payment` ([AdminApi.setPaymentStatus]).
class AdminOrder {
  final int id;
  final String status;
  final int total;
  final int itemCount;
  final String paymentMethod;
  final String paymentStatus;
  final String userEmail;
  final String createdAt;
  final List<Map<String, dynamic>> items;

  const AdminOrder({
    required this.id,
    required this.status,
    required this.total,
    required this.itemCount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.userEmail,
    required this.createdAt,
    required this.items,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    final payment = json['payment'];
    final user = json['user'];
    final rawItems = json['items'];
    return AdminOrder(
      id: asInt(json['id']),
      status: json['status'] as String? ?? 'pending',
      total: asInt(json['total']),
      itemCount: rawItems is List ? rawItems.length : 0,
      paymentMethod:
          payment is Map ? payment['method'] as String? ?? 'COD' : 'COD',
      paymentStatus:
          payment is Map ? payment['status'] as String? ?? 'unpaid' : 'unpaid',
      userEmail: user is Map ? user['email'] as String? ?? '' : '',
      createdAt: json['createdAt'] as String? ?? '',
      items: rawItems is List
          ? rawItems.whereType<Map<String, dynamic>>().toList()
          : const [],
    );
  }

  AdminOrder copyWith({String? status, String? paymentStatus}) {
    return AdminOrder(
      id: id,
      status: status ?? this.status,
      total: total,
      itemCount: itemCount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      userEmail: userEmail,
      createdAt: createdAt,
      items: items,
    );
  }
}

/// Paginated envelope from `GET /admin/orders` (`{items, page, limit, total}`).
class PagedAdminOrders {
  final List<AdminOrder> items;
  final int page;
  final int limit;
  final int total;

  const PagedAdminOrders({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  factory PagedAdminOrders.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v, int fallback) => v is num ? v.toInt() : fallback;
    final raw = json['items'];
    return PagedAdminOrders(
      items: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(AdminOrder.fromJson)
              .toList()
          : const [],
      page: asInt(json['page'], 1),
      limit: asInt(json['limit'], 20),
      total: asInt(json['total'], 0),
    );
  }
}

/// Order statuses accepted by `PATCH /admin/orders/:id/status`.
const adminOrderStatuses = <String>[
  'pending',
  'confirmed',
  'shipped',
  'delivered',
  'cancelled',
];

/// Payment statuses accepted by `PATCH /admin/orders/:id/payment`.
const adminPaymentStatuses = <String>['paid', 'unpaid'];

/// Admin endpoints behind `requireAuth + requireAdmin` (see
/// `backend/src/routes/admin.ts`):
/// - `GET /admin/dashboard`
/// - `POST /admin/products` `{name, slug?, categoryId, description?,
///   priceBdt, stock?, imageUrl?, isActive?}`
/// - `PATCH /admin/products/:id` (partial of the above)
/// - `DELETE /admin/products/:id` (soft: sets `isActive=false`)
/// - `GET /admin/orders?page=&limit=`
/// - `PATCH /admin/orders/:id/status` `{status}`
/// - `PATCH /admin/orders/:id/payment` `{status: paid|unpaid}`
/// - `GET /admin/analytics?days=` (dashboard v2 charts).
class AdminApi {
  final Dio dio;

  AdminApi(this.dio);

  Future<DashboardSummary> dashboard() async {
    final resp = await dio.get<dynamic>('/admin/dashboard');
    return DashboardSummary.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Analytics from `GET /admin/analytics?days=`:
  /// `{days, daily[{date, orders, revenue}],
  /// topProducts[{id, name, qty, revenue}], ordersByStatus,
  /// lowStock[{id, name, stock}]}`.
  Future<Map<String, dynamic>> getAnalytics({int days = 14}) async {
    final resp = await dio.get<dynamic>(
      '/admin/analytics',
      queryParameters: <String, dynamic>{'days': days},
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createProduct(
      Map<String, dynamic> body) async {
    final resp = await dio.post<dynamic>('/admin/products', data: body);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProduct(
      int id, Map<String, dynamic> body) async {
    final resp = await dio.patch<dynamic>('/admin/products/$id', data: body);
    return resp.data as Map<String, dynamic>;
  }

  /// Soft-deactivates (`isActive=false`); no hard delete on the backend.
  Future<Map<String, dynamic>> deactivateProduct(int id) async {
    final resp = await dio.delete<dynamic>('/admin/products/$id');
    return resp.data as Map<String, dynamic>;
  }

  Future<PagedAdminOrders> listOrders({int page = 1, int limit = 20}) async {
    final resp = await dio.get<dynamic>(
      '/admin/orders',
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
    );
    return PagedAdminOrders.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<AdminOrder> updateOrderStatus(int id, String status) async {
    final resp = await dio.patch<dynamic>(
      '/admin/orders/$id/status',
      data: <String, dynamic>{'status': status},
    );
    return AdminOrder.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Toggles COD payment via `PATCH /admin/orders/:id/payment`.
  ///
  /// The backend returns a partial shape
  /// (`{id, status, payment: {status, method}}`), so this returns the
  /// new payment status string — callers merge it into their local
  /// order (see [AdminOrder.copyWith]). `409` means the order is
  /// `cancelled` (locked) or the method is not COD.
  Future<String> setPaymentStatus(int id, String status) async {
    final resp = await dio.patch<dynamic>(
      '/admin/orders/$id/payment',
      data: <String, dynamic>{'status': status},
    );
    final data = resp.data as Map<String, dynamic>;
    final payment = data['payment'];
    if (payment is Map && payment['status'] is String) {
      return payment['status'] as String;
    }
    return status;
  }
}

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(ref.watch(apiClientProvider).dio);
});
