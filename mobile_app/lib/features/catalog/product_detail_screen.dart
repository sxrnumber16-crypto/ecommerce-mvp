import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import '../../shared/widgets/qty_stepper.dart';
import '../cart/cart_store.dart';
import 'catalog_api.dart';
import 'models.dart';

/// `GET /products/:id`: image, price, stock, qty stepper, Add to Cart.
/// Add is disabled when out of stock.
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
            return const LoadingState();
          }
          if (snapshot.hasError) {
            return ErrorState(
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
    final theme = Theme.of(context);
    final max = product.stock >= 10 ? 10 : product.stock;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 1.4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported_outlined,
                        size: 64),
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_outlined, size: 64),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(product.name, style: theme.textTheme.headlineSmall),
        if (product.categoryName != null) ...[
          const SizedBox(height: 4),
          Text(product.categoryName!,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 8),
        Text(
          Config.bdt(product.priceBdt),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        if (product.inStock)
          Text(
            'স্টক: ${product.stock} টি / ${product.stock} in stock',
            style: theme.textTheme.bodyMedium,
          )
        else
          Text(
            'স্টক নেই / Out of stock',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.error),
          ),
        if (product.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(product.description),
        ],
        const SizedBox(height: 16),
        if (product.inStock)
          Row(
            children: [
              const Text('পরিমাণ / Qty:'),
              const SizedBox(width: 8),
              QtyStepper(value: qty, min: 1, max: max, onChanged: onQty),
            ],
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: !product.inStock
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
          icon: const Icon(Icons.add_shopping_cart_outlined),
          label: Text(product.inStock
              ? 'কার্টে যোগ করুন / Add to Cart'
              : 'স্টক নেই / Out of stock'),
        ),
        if (!product.inStock)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: EmptyState(
              message: 'এই পণ্যটি এখন নেই / This item is unavailable',
              icon: Icons.remove_shopping_cart_outlined,
            ),
          ),
      ],
    );
  }
}
