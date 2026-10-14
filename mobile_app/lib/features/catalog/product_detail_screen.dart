import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/config.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_card.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import '../../shared/widgets/qty_stepper.dart';
import '../cart/cart_store.dart';
import 'catalog_api.dart';
import 'models.dart';

/// `GET /products/:id`: gallery, price/stock header, qty stepper, and a
/// sticky bottom Add-to-Cart bar (disabled when out of stock).
///
/// Data flow is identical to the legacy screen: product via
/// `catalogApiProvider.product(id)`, add via
/// `cartStoreProvider.add(product, qty)`, then a SnackBar with a
/// `/cart` action. New look only.
class ProductDetailScreen extends ConsumerStatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late Future<Product> _future;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Product> _load() =>
      ref.read(catalogApiProvider).product(widget.productId);

  void _reload() => setState(() {
        _qty = 1;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('পণ্য / Product')),
      body: FutureBuilder<Product>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: friendlyError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final p = snapshot.data!;
          if (_qty > p.stock && p.inStock) _qty = p.stock;
          return _DetailBody(
            product: p,
            qty: p.inStock ? _qty : 0,
            onQty: (v) => setState(() => _qty = v),
          );
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final Product product;
  final int qty;
  final ValueChanged<int> onQty;

  const _DetailBody({
    required this.product,
    required this.qty,
    required this.onQty,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final max = product.stock >= 10 ? 10 : product.stock;
    final inStock = product.inStock;
    final lowStock = inStock && product.stock <= 5;
    final badgeLabel = !inStock
        ? 'স্টক নেই / Out of stock'
        : lowStock
            ? 'কম স্টক / Low stock'
            : 'স্টক আছে / In stock';
    final badgeColor = !inStock
        ? AppColors.error
        : lowStock
            ? AppColors.price
            : AppColors.success;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.l),
            children: [
              _Gallery(product: product),
              const SizedBox(height: AppSpace.l),
              Text(product.name, style: AppText.headline(context)),
              if (product.categoryName != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  product.categoryName!,
                  style: AppText.body(context)
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: AppSpace.s),
              Text(
                Config.bdt(product.priceBdt),
                style: AppText.price(context).copyWith(
                  color: scheme.primary,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s,
                  vertical: AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  inStock
                      ? '$badgeLabel • ${product.stock} টি / ${product.stock} pcs'
                      : badgeLabel,
                  style: AppText.label(context).copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.l),
              if (inStock)
                Row(
                  children: [
                    Text('পরিমাণ / Qty:', style: AppText.title(context)),
                    const SizedBox(width: AppSpace.s),
                    QtyStepper(
                        value: qty, min: 1, max: max, onChanged: onQty),
                  ],
                ),
              const SizedBox(height: AppSpace.l),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('বিবরণ / Details',
                          style: AppText.title(context)),
                      const SizedBox(height: AppSpace.s),
                      if (product.description.isNotEmpty)
                        Text(product.description,
                            style: AppText.body(context))
                      else
                        Text(
                          'বিবরণ নেই / No description yet',
                          style: AppText.body(context).copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                      const Divider(height: AppSpace.xl),
                      _SpecRow(
                          label: 'ক্যাটাগরি / Category',
                          value: product.categoryName ?? '—'),
                      const SizedBox(height: AppSpace.s),
                      _SpecRow(
                        label: 'স্টক / Stock',
                        value: inStock
                            ? '${product.stock} টি / ${product.stock} pcs'
                            : 'স্টক নেই / Out of stock',
                      ),
                      const SizedBox(height: AppSpace.s),
                      _SpecRow(
                          label: 'পণ্য কোড / SKU',
                          value: '#${product.id}'),
                    ],
                  ),
                ),
              ),
              if (!inStock) ...[
                const SizedBox(height: AppSpace.l),
                EmptyView(
                  message:
                      'এই পণ্যটি এখন নেই / This item is unavailable',
                ),
              ],
              // Clearance above the sticky bar.
              const SizedBox(height: AppSpace.s),
            ],
          ),
        ),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(AppSpace.l),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                top: BorderSide(color: scheme.surfaceContainerHighest),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                label: inStock
                    ? 'কার্টে যোগ করুন / Add to Cart'
                    : 'স্টক নেই / Out of stock',
                onPressed: !inStock
                    ? null
                    : () {
                        ref
                            .read(cartStoreProvider.notifier)
                            .add(product, qty);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'কার্টে যোগ হয়েছে / Added to cart (×$qty)'),
                            action: SnackBarAction(
                              label: 'কার্ট / Cart',
                              onPressed: () => context.go('/cart'),
                            ),
                          ),
                        );
                      },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.body(context)
                .copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(width: AppSpace.m),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppText.body(context),
          ),
        ),
      ],
    );
  }
}

/// Gallery card: [PageView] + dot indicator with [CachedNetworkImage]
/// pages (shimmer while loading). The backend exposes a single
/// [Product.imageUrl], so the gallery has one page (or a placeholder
/// when empty) — the pager/dots pattern stays for multi-image support.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.product});

  final Product product;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = widget.product.imageUrl?.trim() ?? '';
    final images = url.isEmpty ? const <String>[] : <String>[url];
    return AppCard(
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.4,
            child: images.isEmpty
                ? Container(
                    color: scheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_outlined, size: 64),
                  )
                : PageView.builder(
                    controller: _controller,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => CachedNetworkImage(
                      imageUrl: images[i],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: scheme.surfaceContainerHighest,
                        highlightColor: scheme.surface,
                        child: Container(
                          color: scheme.surfaceContainerHighest,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++)
                  Container(
                    width: i == _index ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(
                        horizontal: AppSpace.xs),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                      color: i == _index
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s),
          ],
        ],
      ),
    );
  }
}
