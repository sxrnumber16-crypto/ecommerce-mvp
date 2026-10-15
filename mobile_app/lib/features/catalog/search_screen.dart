import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../design/components/app_chip.dart';
import '../../design/components/app_input.dart';
import '../../design/components/product_card.dart' as v2;
import '../../design/components/sheets.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import 'catalog_api.dart';
import 'models.dart';

/// Client-side sort order for the filter sheet. Applied over the
/// already-fetched API results — never sent as a query param.
enum _Sort { none, priceAsc, priceDesc }

String _sortLabel(_Sort s) => switch (s) {
      _Sort.none => 'ডিফল্ট / Default',
      _Sort.priceAsc => 'দাম: কম → বেশি / Price: low → high',
      _Sort.priceDesc => 'দাম: বেশি → কম / Price: high → low',
    };

/// Search tab navy restyle (Task 4, Orvix dark-navy concept).
///
/// Server data flow is identical to the legacy screen: search field +
/// category chips drive `GET /products?search=&category=&page=&limit=12`
/// (debounced 400ms), paginated with Load more; `initialCategory` comes
/// from the `?category=` query param. New look only: [AppInput] search
/// field, navy [AppChip] filters, a navy filter bottom-sheet whose
/// category/price/in-stock/sort controls apply CLIENT-side over the
/// fetched items, and a v2 grid (navy cards) with skeleton states.
/// Wishlist hearts are a local in-memory set; no backend calls.
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

  // Client-side filters (never sent to the API).
  bool _inStockOnly = false;
  double? _maxPrice;
  _Sort _sort = _Sort.none;

  // Local wishlist (product ids). No backend calls.
  final Set<int> _wished = {};

  bool get _hasMore => _items.length < _total;

  bool get _filtersActive =>
      _inStockOnly || _maxPrice != null || _sort != _Sort.none;

  int get _serverMax =>
      _items.isEmpty ? 0 : _items.map((p) => p.priceBdt).reduce(max);

  /// Fetched items with the client-side filters applied.
  List<Product> get _visible {
    final list = _items.where((p) {
      if (_inStockOnly && !p.inStock) return false;
      if (_maxPrice != null && p.priceBdt > _maxPrice!) return false;
      return true;
    }).toList();
    switch (_sort) {
      case _Sort.priceAsc:
        list.sort((a, b) => a.priceBdt.compareTo(b.priceBdt));
      case _Sort.priceDesc:
        list.sort((a, b) => b.priceBdt.compareTo(a.priceBdt));
      case _Sort.none:
        break;
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _category =
        widget.initialCategory?.isNotEmpty == true ? widget.initialCategory : null;
    _searchCtrl.addListener(_onCtrlChanged);
    _loadCategories();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onCtrlChanged);
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// [AppInput] exposes no onChanged, so the controller listener both
  /// refreshes the clear button and feeds the debounce (as onChanged did).
  void _onCtrlChanged() {
    setState(() {});
    _onSearchChanged(_searchCtrl.text);
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

  void _toggleWish(int id) => setState(() {
        if (!_wished.remove(id)) _wished.add(id);
      });

  void _resetAll() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() {
      _search = '';
      _category = null;
      _inStockOnly = false;
      _maxPrice = null;
      _sort = _Sort.none;
    });
    _reload();
  }

  /// Filter bottom-sheet: edits local copies, writes back only on Apply.
  /// All controls apply client-side over the fetched items.
  Future<void> _openFilters() async {
    final serverMax = _serverMax;
    var inStock = _inStockOnly;
    var sort = _sort;
    double? cap = _maxPrice;
    final applied = await showAppSheet<bool>(
      context,
      child: StatefulBuilder(
        builder: (context, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ফিল্টার / Filters',
              textAlign: TextAlign.center,
              style: AppText.title(context),
            ),
            const SizedBox(height: AppSpace.m),
            SwitchListTile(
              title: Text(
                'শুধু স্টকে / In stock only',
                style: AppText.body(context),
              ),
              value: inStock,
              activeColor: AppColors.seed,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setSheet(() => inStock = v),
            ),
            Text('সাজান / Sort', style: AppText.title(context)),
            const SizedBox(height: AppSpace.s),
            Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.s,
              children: [
                for (final s in _Sort.values)
                  AppChip(
                    label: _sortLabel(s),
                    selected: sort == s,
                    onTap: () => setSheet(() => sort = s),
                  ),
              ],
            ),
            if (serverMax > 0) ...[
              const SizedBox(height: AppSpace.m),
              Text(
                'সর্বোচ্চ দাম / Max price: '
                '${Config.bdt((cap ?? serverMax.toDouble()).round())}',
                style: AppText.title(context),
              ),
              Slider(
                value: (cap ?? serverMax.toDouble())
                    .clamp(0.0, serverMax.toDouble())
                    .toDouble(),
                min: 0,
                max: serverMax.toDouble(),
                divisions: serverMax > 20 ? 20 : null,
                activeColor: AppColors.seed,
                label: Config.bdt(
                    (cap ?? serverMax.toDouble()).round()),
                onChanged: (v) => setSheet(() => cap = v),
              ),
            ],
            const SizedBox(height: AppSpace.m),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setSheet(() {
                      inStock = false;
                      sort = _Sort.none;
                      cap = null;
                    }),
                    child: const Text('রিসেট / Reset'),
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('প্রয়োগ / Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (applied == true && mounted) {
      setState(() {
        _inStockOnly = inStock;
        _sort = sort;
        _maxPrice = cap;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('খুঁজুন / Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.l, AppSpace.m, AppSpace.l, AppSpace.s),
            child: Row(
              children: [
                Expanded(
                  child: AppInput(
                    controller: _searchCtrl,
                    label: 'পণ্য খুঁজুন / Search products…',
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _searchCtrl.clear,
                          ),
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                Badge(
                  isLabelVisible: _filtersActive,
                  child: IconButton.filledTonal(
                    onPressed: _openFilters,
                    tooltip: 'ফিল্টার / Filters',
                    icon: const Icon(Icons.tune),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: _catsFailed && _categories.isEmpty
                ? const SizedBox.shrink()
                : ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.l),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            right: AppSpace.s, top: 6, bottom: 6),
                        child: AppChip(
                          label: 'সব / All',
                          selected: _category == null,
                          onTap: () => _pickCategory(null),
                        ),
                      ),
                      for (final c in _categories)
                        Padding(
                          padding: const EdgeInsets.only(
                              right: AppSpace.s, top: 6, bottom: 6),
                          child: AppChip(
                            label: c.name,
                            selected: _category == c.slug,
                            onTap: () => _pickCategory(c.slug),
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
    if (_loading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpace.l),
        child: LoadingGrid(),
      );
    }
    if (_error != null) {
      return ErrorView(
        message: friendlyError(_error!),
        onRetry: _reload,
      );
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return EmptyView(
        message: _items.isEmpty
            ? 'কিছু পাওয়া যায়নি / No products found'
            : 'ফিল্টারে কিছু মেলেনি / No matches — adjust filters',
        actionLabel: 'রিসেট / Reset',
        onAction: _resetAll,
      );
    }
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpace.l),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: AppSpace.m,
                mainAxisSpacing: AppSpace.m,
              ),
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final p = visible[i];
                return v2.ProductCard(
                  product: p,
                  wished: _wished.contains(p.id),
                  onWish: () => _toggleWish(p.id),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.l, 0, AppSpace.l, AppSpace.l),
          child: _loadingMore
              ? const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _hasMore
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: _loadMore,
                        child: const Text('আরো দেখুন / Load more'),
                      ),
                    )
                  : Text(
                      'মোট $_total টি / $_total item(s)',
                      textAlign: TextAlign.center,
                      style: AppText.label(context),
                    ),
        ),
      ],
    );
  }
}
