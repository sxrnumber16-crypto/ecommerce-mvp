import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/config.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_card.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import '../catalog/catalog_api.dart';
import '../catalog/models.dart';
import 'address_api.dart';
import 'cart_store.dart';
import 'checkout_api.dart';

/// Checkout reskin: order summary with freshly refetched server prices,
/// selected address, and COD `POST /checkout`.
///
/// Payload contract is unchanged — prices are never sent, only
/// `{addressId, items: [{productId, qty}], idempotencyKey}` (uuid v4,
/// generated once per screen so retries replay idempotently; see
/// [CheckoutApi.place]). The summary [AppCard] renders server figures
/// only; `deliveryFee`/`total` still come only from the `POST
/// /checkout` response. New look only.
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
    final scheme = Theme.of(context).colorScheme;
    final lines = ref.watch(cartStoreProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('চেকআউট / Checkout')),
      body: lines.isEmpty
          ? EmptyView(
              message: 'কার্ট খালি / Cart is empty',
              actionLabel: 'কার্টে ফিরুন / Back to cart',
              onAction: () => context.go('/cart'),
            )
          : FutureBuilder<({Address? address, List<Product> priced})>(
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
                final data = snapshot.data!;
                final byId = {for (final p in data.priced) p.id: p};
                var preview = 0;
                for (final l in lines) {
                  preview += (byId[l.product.id]?.priceBdt ?? 0) * l.qty;
                }
                return ListView(
                  padding: const EdgeInsets.all(AppSpace.l),
                  children: [
                    Text('অর্ডার সামারি / Order summary',
                        style: AppText.title(context)),
                    const SizedBox(height: AppSpace.s),
                    for (final l in lines)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpace.s),
                        child: AppCard(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(AppSpace.m),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.card),
                                    child: _Thumb(
                                        url: (byId[l.product.id]
                                                    ?.imageUrl ??
                                                l.product.imageUrl)
                                            ?.trim()),
                                  ),
                                ),
                                const SizedBox(width: AppSpace.m),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        byId[l.product.id]?.name ??
                                            l.product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.title(context),
                                      ),
                                      const SizedBox(
                                          height: AppSpace.xs),
                                      Text(
                                        '×${l.qty} • ${Config.bdt(byId[l.product.id]?.priceBdt ?? 0)}',
                                        style: AppText.body(context)
                                            .copyWith(
                                                color: scheme
                                                    .onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  Config.bdt(
                                      (byId[l.product.id]?.priceBdt ??
                                              0) *
                                          l.qty),
                                  style: AppText.price(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpace.s),
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.l),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('পণ্য মোট / Items:',
                                    style: AppText.title(context)),
                                Text(
                                  Config.bdt(preview),
                                  style: AppText.price(context).copyWith(
                                      color: scheme.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.s),
                            Text(
                              'ডেলিভারি ফি + সর্বমোট সার্ভার হিসাব করবে / Delivery fee and total are calculated by the server',
                              style: AppText.body(context).copyWith(
                                fontStyle: FontStyle.italic,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.l),
                    Text('ডেলিভারি ঠিকানা / Deliver to',
                        style: AppText.title(context)),
                    const SizedBox(height: AppSpace.s),
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.l),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                color: scheme.primary),
                            const SizedBox(width: AppSpace.s),
                            Expanded(
                              child: Text(
                                data.address == null
                                    ? 'ঠিকানা পাওয়া যায়নি / Address not found'
                                    : '${data.address!.label} — ${data.address!.line1}, ${data.address!.city} • ${data.address!.phone}',
                                style: AppText.body(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.l),
                    Text(
                      'ক্যাশ অন ডেলিভারি / Cash on Delivery (COD)',
                      style: AppText.title(context),
                    ),
                    if (_placeError != null) ...[
                      const SizedBox(height: AppSpace.s),
                      Text(
                        friendlyError(_placeError!),
                        style: AppText.body(context)
                            .copyWith(color: scheme.error),
                      ),
                    ],
                    const SizedBox(height: AppSpace.m),
                    AppButton(
                      label: 'অর্ডার করুন / Place order (COD)',
                      loading: _placing,
                      onPressed: (_placing || data.address == null)
                          ? null
                          : _place,
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = (url ?? '').trim();
    if (u.isEmpty) {
      return Container(
        color: scheme.surfaceContainerHighest,
        child: const Icon(Icons.image_outlined),
      );
    }
    return CachedNetworkImage(
      imageUrl: u,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) =>
          const Icon(Icons.image_outlined),
    );
  }
}
