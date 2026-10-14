import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/qty_stepper.dart';
import 'cart_store.dart';

/// Cart tab: qty edit / remove, preview subtotal from cached snapshots.
/// The banner states the server calculates the final totals at checkout.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartStoreProvider);
    final cart = ref.read(cartStoreProvider.notifier);
    final preview =
        lines.fold(0, (sum, l) => sum + l.product.priceBdt * l.qty);

    return Scaffold(
      appBar: AppBar(title: const Text('কার্ট / Cart')),
      body: lines.isEmpty
          ? EmptyState(
              message: 'কার্ট খালি / Your cart is empty',
              icon: Icons.shopping_cart_outlined,
              actionLabel: 'কেনাকাটা করুন / Shop now',
              onAction: () => context.go('/search'),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  child: const Text(
                    'চূড়ান্ত মূল্য সার্ভার হিসাব করবে / Final totals are calculated by the server at checkout',
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: lines.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) {
                      final line = lines[i];
                      final p = line.product;
                      final cap = p.stock >= 10 ? 10 : p.stock;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: p.imageUrl != null &&
                                      p.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      p.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.image_outlined),
                                    )
                                  : const Icon(Icons.image_outlined),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  Config.bdt(p.priceBdt),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold),
                                ),
                                QtyStepper(
                                  value: line.qty,
                                  min: 1,
                                  max: cap < 1 ? 1 : cap,
                                  onChanged: (v) =>
                                      cart.setQty(p.id, v),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remove',
                            onPressed: () => cart.remove(p.id),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('আনুমানিক / Estimate:'),
                            Text(
                              Config.bdt(preview),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => context.push('/cart/address'),
                          child:
                              const Text('এগিয়ে যান / Proceed to checkout'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
