import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_card.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/qty_stepper.dart';
import 'cart_store.dart';

/// Cart tab reskin.
///
/// Data flow is identical to the legacy screen: lines from
/// [cartStoreProvider] (qty edits via `setQty`, removals via `remove`),
/// preview subtotal folded from the cached snapshots, and continue via
/// `push('/cart/address')`. The banner states the server calculates the
/// final totals at checkout. New look only: line-item [AppCard]s with
/// steppers, a summary [AppCard], and an [AppButton] CTA.
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
          ? EmptyView(
              message: 'কার্ট খালি / Your cart is empty',
              actionLabel: 'কেনাকাটা করুন / Shop now',
              onAction: () => context.go('/search'),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.m),
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
                    'চূড়ান্ত মূল্য সার্ভার হিসাব করবে / Final totals are calculated by the server at checkout',
                    textAlign: TextAlign.center,
                    style: AppText.label(context),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpace.l),
                    itemCount: lines.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpace.m),
                    itemBuilder: (context, i) {
                      final line = lines[i];
                      final p = line.product;
                      final cap = p.stock >= 10 ? 10 : p.stock;
                      final url = p.imageUrl?.trim() ?? '';
                      return AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.m),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.card),
                                  child: url.isEmpty
                                      ? Container(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Icon(
                                              Icons.image_outlined),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: url,
                                          fit: BoxFit.cover,
                                          errorWidget:
                                              (context, url, error) =>
                                                  const Icon(Icons
                                                      .image_outlined),
                                        ),
                                ),
                              ),
                              const SizedBox(width: AppSpace.m),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.title(context),
                                    ),
                                    const SizedBox(height: AppSpace.xs),
                                    Text(
                                      Config.bdt(p.priceBdt),
                                      style: AppText.price(context).copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
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
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.l),
                    child: AppCard(
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
                                Text('আনুমানিক / Estimate:',
                                    style: AppText.title(context)),
                                Text(
                                  Config.bdt(preview),
                                  style: AppText.price(context).copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.m),
                            AppButton(
                              label: 'এগিয়ে যান / Proceed to checkout',
                              onPressed: () =>
                                  context.push('/cart/address'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
