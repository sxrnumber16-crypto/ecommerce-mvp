import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'models.dart';

/// Thin wrapper over the public catalog endpoints (no auth required):
/// `GET /categories`, `GET /products?search=&category=&page=&limit=`,
/// `GET /products/:id`. Base URL is `Config.apiBaseUrl + /api/v1`
/// (see [ApiClient]).
class CatalogApi {
  final Dio dio;

  CatalogApi(this.dio);

  Future<List<Category>> categories() async {
    final resp = await dio.get<dynamic>('/categories');
    final data = resp.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList();
    }
    return const [];
  }

  Future<PagedProducts> products({
    String? search,
    String? category,
    int page = 1,
    int limit = 12,
  }) async {
    final resp = await dio.get<dynamic>(
      '/products',
      queryParameters: <String, dynamic>{
        if (search != null && search.trim().isNotEmpty)
          'search': search.trim(),
        if (category != null && category.isNotEmpty) 'category': category,
        'page': page,
        'limit': limit,
      },
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) return PagedProducts.fromJson(data);
    return PagedProducts(items: const [], page: page, limit: limit, total: 0);
  }

  Future<Product> product(int id) async {
    final resp = await dio.get<dynamic>('/products/$id');
    return Product.fromJson(resp.data as Map<String, dynamic>);
  }
}

final catalogApiProvider = Provider<CatalogApi>((ref) {
  return CatalogApi(ref.watch(apiClientProvider).dio);
});
