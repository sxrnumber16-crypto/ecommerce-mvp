import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/config.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import '../catalog/catalog_api.dart';
import '../catalog/models.dart';
import 'address_api.dart';
import 'cart_store.dart';
import 'checkout_api.dart';

/// Checkout: order summary with freshly refetched server prices, selected
/// address, and COD `POST /checkout`. Prices are never sent — only
/// `{addressId, items: [{productId, qty}], idempotencyKey}` (uuid v4,
/// generated once per screen so retries replay idempotently).
class CheckoutScreen extends ConsumerStatefulWidget {
  final int addressId;

  const CheckoutScreen({super.key, required this.addressId});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final String _idempotencyKey = const Uuid().v4();
  late Future<({Address? address, List<Product> priced})> _future;
  bool _placing = false;
  Object? _placeError;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Refetches each cart product (`GET /products/:id`) so the preview
  /// reflects current server prices. Final `deliveryFee`/`total` still come
  /// only from the `POST /checkout` response.
  Future<({Address? address, List<Product> priced})> _load() async {
    final lines = ref.read(cartStoreProvider);
    final addressApi = ref.read(addressApiProvider);
    final catalog = ref.read(catalogApiProvider);
    final addresses = await addressApi.list();
    Address? selected;
    for (final a in addresses) {
      if (a.id == widget.addressId) selected = a;
    }
    final priced = <Product>[];
    for (final l in lines) {
      try {
        priced.add(await catalog.product(l.product.id));
      } catch (_) {
        priced.add(l.product);
      }
    }
    return (address: selected, priced: priced);
  }

  void _reload() => setState(() {
        _placeError = null;
        _future = _load();
      });

  Future<void> _place() async {
    final lines = ref.read(cartStoreProvider);
    if (lines.isEmpty || _placing) return;
    setState(() {
      _placing = true;
      _placeError = null;
    });
    try {
      final order = await ref.read(checkoutApiProvider).place(
            addressId: widget.addressId,
            items: [
              for (final l in lines)
                (productId: l.product.id, qty: l.qty),
            ],
            idempotencyKey: _idempotencyKey,
          );
      ref.read(cartStoreProvider.notifier).clear();
      if (mounted) context.go('/cart/confirmation/${order.id}');
    } catch (e) {
      setState(() {
        _placing = false;
        _placeError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartStoreProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('চেকআউট / Checkout')),
      body: lines.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('কার্ট খালি / Cart is empty'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/cart'),
                    child: const Text('কার্টে ফিরুন / Back to cart'),
                  ),
                ],
              ),
            )
          : FutureBuilder<({Address? address, List<Product> priced})>(
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
                final byId = {for (final p in data.priced) p.id: p};
                var preview = 0;
                for (final l in lines) {
                  preview += (byId[l.product.id]?.priceBdt ?? 0) * l.qty;
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('অর্ডার সামারি / Order summary',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final l in lines)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(byId[l.product.id]?.name ?? l.product.name),
                        subtitle: Text(
                            '×${l.qty} • ${Config.bdt(byId[l.product.id]?.priceBdt ?? 0)}'),
                        trailing: Text(Config.bdt(
                            (byId[l.product.id]?.priceBdt ?? 0) * l.qty)),
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('পণ্য মোট / Items:'),
                        Text(Config.bdt(preview)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ডেলিভারি ফি + সর্বমোট সার্ভার হিসাব করবে / Delivery fee and total are calculated by the server',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    Text('ডেলিভারি ঠিকানা / Deliver to',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(data.address == null
                        ? 'ঠিকানা পাওয়া যায়নি / Address not found'
                        : '${data.address!.label} — ${data.address!.line1}, ${data.address!.city} • ${data.address!.phone}'),
                    const SizedBox(height: 16),
                    const Text('ক্যাশ অন ডেলিভারি / Cash on Delivery (COD)'),
                    if (_placeError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        friendlyError(_placeError!),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: (_placing || data.address == null)
                          ? null
                          : _place,
                      child: _placing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Text('অর্ডার করুন / Place order (COD)'),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
