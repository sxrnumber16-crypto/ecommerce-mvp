import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import '../../shared/widgets/product_card.dart';
import '../catalog/catalog_api.dart';
import '../catalog/models.dart';

/// Home tab: categories horizontal chips (`GET /categories`) + featured
/// products (`GET /products?limit=8`). Loading / empty / error states.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<({List<Category> categories, List<Product> featured})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<Category> categories, List<Product> featured})> _load() async {
    final api = ref.read(catalogApiProvider);
    final results = await Future.wait([
      api.categories(),
      api.products(limit: 8),
    ]);
    return (
      categories: results[0] as List<Category>,
      featured: (results[1] as PagedProducts).items,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Config.storeName)),
      body: FutureBuilder<
          ({List<Category> categories, List<Product> featured})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingState();
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: friendlyError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          if (data.categories.isEmpty && data.featured.isEmpty) {
            return EmptyState(
              message: 'কোনো পণ্য নেই / No products yet',
              actionLabel: 'আবার চেষ্টা করুন / Retry',
              onAction: _reload,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'ক্যাটাগরি / Categories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (data.categories.isEmpty)
                  const Text('—')
                else
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: data.categories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final c = data.categories[i];
                        return ActionChip(
                          label: Text(c.name),
                          onPressed: () => context.push(
                            '/search?category=${Uri.encodeComponent(c.slug)}',
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'ফিচার্ড / Featured',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (data.featured.isEmpty)
                  const EmptyState(
                    message: 'কোনো ফিচার্ড পণ্য নেই / No featured products',
                    icon: Icons.storefront_outlined,
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: data.featured.length,
                    itemBuilder: (context, i) =>
                        ProductCard(product: data.featured[i]),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
