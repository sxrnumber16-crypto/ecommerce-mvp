import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import '../../shared/widgets/product_card.dart';
import 'catalog_api.dart';
import 'models.dart';

/// Search tab: search field + category filter chips →
/// `GET /products?search=&category=&page=&limit=`. Paginated list.
class SearchScreen extends ConsumerStatefulWidget {
  /// Initial category slug (from Home chips via `?category=`).
  final String? initialCategory;

  const SearchScreen({super.key, this.initialCategory});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _limit = 12;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Category> _categories = [];
  String? _category;
  String _search = '';
  List<Product> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  bool _catsFailed = false;

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _category =
        widget.initialCategory?.isNotEmpty == true ? widget.initialCategory : null;
    _loadCategories();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ref.read(catalogApiProvider).categories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {
      if (mounted) setState(() => _catsFailed = true);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final paged = await ref.read(catalogApiProvider).products(
            search: _search,
            category: _category,
            page: 1,
            limit: _limit,
          );
      if (!mounted) return;
      setState(() {
        _items = paged.items;
        _total = paged.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final paged = await ref.read(catalogApiProvider).products(
            search: _search,
            category: _category,
            page: _page + 1,
            limit: _limit,
          );
      if (!mounted) return;
      setState(() {
        _page = paged.page;
        _total = paged.total;
        _items = [..._items, ...paged.items];
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('আরো লোড হয়নি / Could not load more')),
        );
      }
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_search != v.trim()) {
        _search = v.trim();
        _reload();
      }
    });
  }

  void _pickCategory(String? slug) {
    if (_category == slug) return;
    setState(() => _category = slug);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('খুঁজুন / Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'পণ্য খুঁজুন / Search products…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (v) {
                setState(() {});
                _onSearchChanged(v);
              },
              onSubmitted: (_) => _reload(),
            ),
          ),
          SizedBox(
            height: 52,
            child: _catsFailed && _categories.isEmpty
                ? const SizedBox.shrink()
                : ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                        child: FilterChip(
                          label: const Text('সব / All'),
                          selected: _category == null,
                          onSelected: (_) => _pickCategory(null),
                        ),
                      ),
                      for (final c in _categories)
                        Padding(
                          padding:
                              const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                          child: FilterChip(
                            label: Text(c.name),
                            selected: _category == c.slug,
                            onSelected: (_) => _pickCategory(c.slug),
                          ),
                        ),
                    ],
                  ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) {
      return ErrorState(
        message: friendlyError(_error!),
        onRetry: _reload,
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        message: 'কিছু পাওয়া যায়নি / No products found',
        icon: Icons.search_off_outlined,
        actionLabel: 'রিসেট / Reset',
        onAction: () {
          _searchCtrl.clear();
          _search = '';
          _pickCategory(null);
        },
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == _items.length) {
            if (!_hasMore) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'মোট $_total টি / $_total item(s)',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : FilledButton.tonal(
                        onPressed: _loadMore,
                        child: const Text('আরো দেখুন / Load more'),
                      ),
              ),
            );
          }
          final p = _items[i];
          // Compact list rows reuse ProductCard's data contract via push nav.
          return SizedBox(
            height: 132,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ListRow(product: p),
            ),
          );
        },
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final Product product;

  const _ListRow({required this.product});

  @override
  Widget build(BuildContext context) {
    // Reuse the shared card for consistent BDT + stock-badge rendering.
    return ProductCard(product: product);
  }
}
