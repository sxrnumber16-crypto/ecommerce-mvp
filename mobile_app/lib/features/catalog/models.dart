/// Customer catalog models. Field names mirror the backend Prisma schema
/// (`priceBdt`, `imageUrl`, `isActive`) and the JSON shapes returned by
/// `GET /categories`, `GET /products?...`, `GET /products/:id`.
class Category {
  final int id;
  final String name;
  final String slug;
  final String? icon;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }
}

/// `category` is the nested `{slug, name}` include from the backend.
class Product {
  final int id;
  final int categoryId;
  final String name;
  final String slug;
  final String description;
  final int priceBdt;
  final int stock;
  final String? imageUrl;
  final bool isActive;
  final String? categorySlug;
  final String? categoryName;

  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.description,
    required this.priceBdt,
    required this.stock,
    required this.imageUrl,
    required this.isActive,
    this.categorySlug,
    this.categoryName,
  });

  bool get inStock => stock > 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return Product(
      id: (json['id'] as num).toInt(),
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priceBdt: (json['priceBdt'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      categorySlug: category is Map ? category['slug'] as String? : null,
      categoryName: category is Map ? category['name'] as String? : null,
    );
  }
}

/// Paginated envelope from `GET /products` (`{items, page, limit, total}`).
class PagedProducts {
  final List<Product> items;
  final int page;
  final int limit;
  final int total;

  const PagedProducts({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  factory PagedProducts.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(Product.fromJson)
            .toList()
        : <Product>[];
    int asInt(Object? v, int fallback) =>
        v is num ? v.toInt() : fallback;
    return PagedProducts(
      items: items,
      page: asInt(json['page'], 1),
      limit: asInt(json['limit'], items.length),
      total: asInt(json['total'], items.length),
    );
  }
}
