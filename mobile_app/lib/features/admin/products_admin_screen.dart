import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../design/components/app_card.dart';
import '../../design/components/app_chip.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import '../catalog/models.dart';
import 'admin_api.dart';
import 'admin_gate.dart';

/// Active filter values for `GET /admin/products` (`active` enum).
const _filterAll = 'all';
const _filterActive = 'true';
const _filterInactive = 'false';

List<Product> _itemsOf(Map<String, dynamic> data) {
  final raw = data['items'];
  if (raw is List) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();
  }
  return const [];
}

/// Admin products tab consuming Task 1 endpoints: `GET /admin/products`
/// (search + All/Active/Inactive filter) with rows routing to the
/// existing editor (`/admin/products/:id/edit`), quick
/// deactivate/reactivate via `PATCH /admin/products/:id {isActive}`
/// (same call the editor's re-activation uses), and hard delete via
/// `DELETE` with the 409 `has_orders` hint. Guarded by [AdminGate];
/// reachable from the dashboard Products entry and `/admin/products`.
/// Bilingual copy; design tokens only.
class ProductsAdminScreen extends ConsumerStatefulWidget {
  const ProductsAdminScreen({super.key});

  @override
  ConsumerState<ProductsAdminScreen> createState() =>
      _ProductsAdminScreenState();
}

class _ProductsAdminScreenState extends ConsumerState<ProductsAdminScreen> {
  final _search = TextEditingController();
  String _active = _filterAll;
  late Future<Map<String, dynamic>> _future;
  final _busy = <int>{};

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetch() {
    return ref.read(adminApiProvider).listProducts(
          search: _search.text,
          active: _active,
          limit: 50,
        );
  }

  void _reload() => setState(() => _future = _fetch());

  void _setActive(String value) {
    if (value == _active) return;
    setState(() => _active = value);
    _reload();
  }

  /// Quick deactivate/reactivate via the existing `PATCH`
  /// ([AdminApi.updateProduct]) — the same call the editor's
  /// re-activation path uses.
  Future<void> _toggleActive(Product product) async {
    if (_busy.contains(product.id)) return;
    setState(() => _busy.add(product.id));
    try {
      await ref.read(adminApiProvider).updateProduct(
        product.id,
        <String, dynamic>{'isActive': !product.isActive},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(product.isActive
            ? 'নিষ্ক্রিয় করা হয়েছে / Deactivated'
            : 'সক্রিয় করা হয়েছে / Re-activated'),
      ));
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(product.id));
    }
  }

  /// Hard delete via `DELETE /admin/products/:id`. A `409` means
  /// order items reference the product — the row stays and the
  /// deactivate-instead hint shows; otherwise the list reloads
  /// (removing the row).
  Future<void> _delete(Product product) async {
    if (_busy.contains(product.id)) return;
    setState(() => _busy.add(product.id));
    try {
      await ref.read(adminApiProvider).deleteProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('মুছে ফেলা হয়েছে / Deleted')),
      );
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.statusCode == 409
          ? 'অর্ডার আছে / Has orders — deactivate instead'
          : friendlyError(e);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy.remove(product.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      fallback: const AdminDenied(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('পণ্য পরিচালনা / Products'),
          actions: [
            IconButton(
              tooltip: 'নতুন পণ্য / New product',
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/admin/products/new'),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.l, AppSpace.m, AppSpace.l, AppSpace.s),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _reload(),
                decoration: InputDecoration(
                  labelText: 'খুঁজুন / Search',
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'খুঁজুন / Search',
                    icon: const Icon(Icons.arrow_forward_outlined),
                    onPressed: _reload,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.l,
                    vertical: AppSpace.m,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
              child: Row(
                children: [
                  AppChip(
                    label: 'সব / All',
                    selected: _active == _filterAll,
                    onTap: () => _setActive(_filterAll),
                  ),
                  const SizedBox(width: AppSpace.s),
                  AppChip(
                    label: 'সক্রিয় / Active',
                    selected: _active == _filterActive,
                    onTap: () => _setActive(_filterActive),
                  ),
                  const SizedBox(width: AppSpace.s),
                  AppChip(
                    label: 'নিষ্ক্রিয় / Inactive',
                    selected: _active == _filterInactive,
                    onTap: () => _setActive(_filterInactive),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: friendlyError(snapshot.error!),
                      onRetry: _reload,
                    );
                  }
                  final items = _itemsOf(snapshot.data!);
                  if (items.isEmpty) {
                    return EmptyView(
                      message: 'কোনো পণ্য নেই / No products',
                      actionLabel: 'নতুন পণ্য / New product',
                      onAction: () =>
                          context.push('/admin/products/new'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ProductsAdminListView(
                      items: items,
                      busyIds: _busy,
                      onTap: (p) =>
                          context.push('/admin/products/${p.id}/edit'),
                      onToggleActive: _toggleActive,
                      onDeleteConfirmed: _delete,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pure (API-free) products list: thumb/name/price/stock rows with an
/// active badge, a deactivate/reactivate button, and a delete button
/// behind a bilingual confirm dialog. Callbacks keep this widget
/// hermetic for widget tests; [ProductsAdminScreen] wires the real
/// admin API calls.
class ProductsAdminListView extends StatelessWidget {
  final List<Product> items;
  final ValueChanged<Product>? onTap;
  final ValueChanged<Product>? onToggleActive;
  final ValueChanged<Product>? onDeleteConfirmed;
  final Set<int> busyIds;

  const ProductsAdminListView({
    super.key,
    required this.items,
    this.onTap,
    this.onToggleActive,
    this.onDeleteConfirmed,
    this.busyIds = const {},
  });

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('মুছবেন? / Delete?'),
        content: const Text(
            'পণ্যটি স্থায়ীভাবে মুছে যাবে। / The product will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল / Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('মুছুন / Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) onDeleteConfirmed?.call(product);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.l),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.m),
      itemBuilder: (context, i) {
        final product = items[i];
        final busy = busyIds.contains(product.id);
        return _ProductRow(
          product: product,
          busy: busy,
          onTap: onTap == null ? null : () => onTap!(product),
          onToggleActive: onToggleActive == null
              ? null
              : () => onToggleActive!(product),
          onDelete: onDeleteConfirmed == null
              ? null
              : () => _confirmDelete(context, product),
        );
      },
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onToggleActive;
  final VoidCallback? onDelete;

  const _ProductRow({
    required this.product,
    required this.busy,
    this.onTap,
    this.onToggleActive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = product.isActive;
    final badgeColor = active ? AppColors.success : scheme.error;
    final imageUrl = (product.imageUrl ?? '').trim();
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl.isEmpty
                  ? Icon(
                      Icons.image_outlined,
                      color: scheme.onSurfaceVariant,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.image_not_supported_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(context),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    '${Config.bdt(product.priceBdt)} • স্টক: ${product.stock}',
                    style: AppText.body(context),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.m,
                      vertical: AppSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      active ? 'সক্রিয় / Active' : 'নিষ্ক্রিয় / Inactive',
                      style: AppText.label(context).copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              if (onToggleActive != null)
                IconButton(
                  tooltip: active
                      ? 'নিষ্ক্রিয় / Deactivate'
                      : 'সক্রিয় / Re-activate',
                  icon: Icon(active
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: onToggleActive,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'মুছুন / Delete',
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  onPressed: onDelete,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
