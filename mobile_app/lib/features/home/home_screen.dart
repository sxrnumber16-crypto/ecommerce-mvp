import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../design/components/app_chip.dart';
import '../../design/components/product_card.dart' as v2;
import '../../design/components/section_header.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import '../catalog/catalog_api.dart';
import '../catalog/models.dart';

/// Home tab reskin (Task 5).
///
/// Data flow is identical to the legacy screen: categories via
/// `GET /categories`, featured via `GET /products?limit=8`, category taps
/// navigate to `/search?category=<slug>`, card taps to `/product/:id`
/// (inside the v2 card). New look only: category hero banner, [AppChip]
/// row, featured 2-col grid of v2 [v2.ProductCard], and a best-sellers
/// rail reusing the same card over the already-fetched payload (no extra
/// API calls). Wishlist hearts are a local in-memory set; no backend calls.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<({List<Category> categories, List<Product> featured})> _future;
  final Set<int> _wished = {};
  int _bannerIndex = 0;

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

  void _reload() => setState(() {
        _future = _load();
        _bannerIndex = 0;
      });

  void _toggleWish(int id) => setState(() {
        if (!_wished.remove(id)) _wished.add(id);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Config.storeName)),
      body: FutureBuilder<
          ({List<Category> categories, List<Product> featured})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SingleChildScrollView(
              padding: EdgeInsets.all(AppSpace.l),
              child: LoadingGrid(),
            );
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: friendlyError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          if (data.categories.isEmpty && data.featured.isEmpty) {
            return EmptyView(
              message: 'কোনো পণ্য নেই / No products yet',
              actionLabel: 'আবার চেষ্টা করুন / Retry',
              onAction: _reload,
            );
          }
          // Same payload, reversed, for the rail — no extra API calls.
          final bestSellers = data.featured.reversed.toList();
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.l),
              children: [
                if (data.categories.isNotEmpty) ...[
                  _HeroBanner(
                    categories: data.categories,
                    activeIndex: _bannerIndex,
                    onPage: (i) => setState(() => _bannerIndex = i),
                  ),
                  const SizedBox(height: AppSpace.l),
                  const SectionHeader(title: 'ক্যাটাগরি / Categories'),
                  const SizedBox(height: AppSpace.s),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: data.categories.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpace.s),
                      itemBuilder: (context, i) {
                        final c = data.categories[i];
                        return AppChip(
                          label: c.name,
                          onTap: () => context.push(
                            '/search?category=${Uri.encodeComponent(c.slug)}',
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpace.l),
                ],
                const SectionHeader(title: 'ফিচার্ড / Featured'),
                const SizedBox(height: AppSpace.s),
                if (data.featured.isEmpty)
                  const EmptyView(
                    message:
                        'কোনো ফিচার্ড পণ্য নেই / No featured products',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: AppSpace.m,
                      mainAxisSpacing: AppSpace.m,
                    ),
                    itemCount: data.featured.length,
                    itemBuilder: (context, i) {
                      final p = data.featured[i];
                      return v2.ProductCard(
                        product: p,
                        wished: _wished.contains(p.id),
                        onWish: () => _toggleWish(p.id),
                      );
                    },
                  ),
                if (bestSellers.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.l),
                  const SectionHeader(title: 'বেস্ট সেলার / Best sellers'),
                  const SizedBox(height: AppSpace.s),
                  SizedBox(
                    height: 284,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: bestSellers.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpace.m),
                      itemBuilder: (context, i) {
                        final p = bestSellers[i];
                        return SizedBox(
                          width: 160,
                          child: v2.ProductCard(
                            product: p,
                            wished: _wished.contains(p.id),
                            onWish: () => _toggleWish(p.id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Auto-playing hero banner built from the category list. Each slide shows
/// the category icon + name and navigates to `/search?category=<slug>`.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.categories,
    required this.activeIndex,
    required this.onPage,
  });

  final List<Category> categories;
  final int activeIndex;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        CarouselSlider(
          items: [
            for (final c in categories) _HeroSlide(category: c),
          ],
          options: CarouselOptions(
            height: 168,
            viewportFraction: 0.88,
            enlargeCenterPage: true,
            autoPlay: categories.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            onPageChanged: (i, _) => onPage(i),
          ),
        ),
        const SizedBox(height: AppSpace.s),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < categories.length; i++)
              Container(
                width: i == activeIndex % categories.length ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  color: i == activeIndex % categories.length
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push(
        '/search?category=${Uri.encodeComponent(category.slug)}',
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.tertiary],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _categoryIcon(category.icon),
              color: scheme.onPrimary,
              size: 28,
            ),
            const SizedBox(height: AppSpace.s),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.headline(context)
                  .copyWith(color: scheme.onPrimary),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'কেনাকাটা করুন / Shop now →',
              style: AppText.label(context)
                  .copyWith(color: scheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Backend seeds `Category.icon` with Material icon names
/// (`checkroom`, `devices`, `home`, `spa`, `watch`, `category`).
IconData _categoryIcon(String? name) {
  return switch (name) {
    'checkroom' => Icons.checkroom,
    'devices' => Icons.devices,
    'home' => Icons.home_outlined,
    'spa' => Icons.spa,
    'watch' => Icons.watch,
    'category' => Icons.category_outlined,
    _ => Icons.grid_view_rounded,
  };
}
