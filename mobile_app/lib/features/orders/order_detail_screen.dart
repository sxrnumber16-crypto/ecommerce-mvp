import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../design/components/app_card.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import 'orders_api.dart';

/// `GET /orders/:id` navy restyle (Orvix dark-navy concept): items +
/// payment + a vertical status timeline (`pending → confirmed →
/// shipped → delivered`; `cancelled` terminal).
///
/// Data flow is identical to the legacy screen:
/// `ordersApiProvider.detail(orderId)`, `_flow.indexOf(order.status)`
/// step math, the `cancelled` branch, and all money figures via
/// [Config.bdt] from server fields only. Bilingual copy verbatim.
/// New look only: navy status/payment/items/totals [AppCard]s, blue
/// icons/price/timeline accents via tokens, and a custom vertical
/// timeline with the current step highlighted.
class OrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() =>
      _OrderDetailScreenState();
}

const _flow = <String>['pending', 'confirmed', 'shipped', 'delivered'];

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late Future<OrderDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(ordersApiProvider).detail(widget.orderId);
  }

  void _reload() => setState(
      () => _future = ref.read(ordersApiProvider).detail(widget.orderId));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('অর্ডার #${widget.orderId}')),
      body: FutureBuilder<OrderDetail>(
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
          final order = snapshot.data!;
          final step = _flow.indexOf(order.status);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.l),
              children: [
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'অবস্থা / Status: ${order.status}',
                          style: AppText.title(context),
                        ),
                        const SizedBox(height: AppSpace.m),
                        if (order.status == 'cancelled')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.m,
                              vertical: AppSpace.s,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                  AppSpace.m),
                            ),
                            child: Text(
                              'বাতিল / Cancelled',
                              style: AppText.title(context).copyWith(
                                color: scheme.error,
                              ),
                            ),
                          )
                        else
                          _Timeline(
                            current: step < 0 ? 0 : step,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.m),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payments_outlined,
                                color: AppColors.seed),
                            const SizedBox(width: AppSpace.s),
                            Expanded(
                              child: Text(
                                'পেমেন্ট: ${order.paymentMethod} / '
                                '${order.paymentStatus} • '
                                '${Config.bdt(order.paymentAmount)}',
                                style: AppText.body(context),
                              ),
                            ),
                          ],
                        ),
                        if (order.addressLine != null) ...[
                          const SizedBox(height: AppSpace.s),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  color: AppColors.seed),
                              const SizedBox(width: AppSpace.s),
                              Expanded(
                                child: Text(
                                  'ঠিকানা / Address: '
                                  '${order.addressLine}',
                                  style: AppText.body(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.m),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('পণ্য / Items',
                            style: AppText.title(context)),
                        const SizedBox(height: AppSpace.s),
                        for (final item in order.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpace.s),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: AppText.body(context),
                                      ),
                                      const SizedBox(height: AppSpace.xs),
                                      Text(
                                        '×${item.qty} • '
                                        '${Config.bdt(item.unitPrice)}',
                                        style: AppText.body(context)
                                            .copyWith(
                                          color:
                                              scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  Config.bdt(item.lineTotal),
                                  style: AppText.title(context),
                                ),
                              ],
                            ),
                          ),
                        const Divider(height: AppSpace.xl),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('সাবটোটাল / Subtotal:',
                                style: AppText.body(context)),
                            Text(Config.bdt(order.subtotal),
                                style: AppText.body(context)),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ডেলিভারি / Delivery:',
                                style: AppText.body(context)),
                            Text(Config.bdt(order.deliveryFee),
                                style: AppText.body(context)),
                          ],
                        ),
                        const Divider(height: AppSpace.xl),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('সর্বমোট / Total:',
                                style: AppText.title(context)),
                            Text(
                              Config.bdt(order.total),
                              style: AppText.price(context).copyWith(
                                color: AppColors.price,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Vertical timeline over [_flow]. Steps before [current] show a
/// filled check dot, [current] a highlighted ring dot, later steps a
/// muted dot; a connecting line runs down the leading column.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < _flow.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    _Dot(done: i < current, now: i == current),
                    if (i < _flow.length - 1)
                      Container(
                        width: 2,
                        height: 24,
                        color: i < current
                            ? AppColors.seed
                            : scheme.surfaceContainerHighest,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: AppSpace.m),
                  child: Text(
                    _flow[i],
                    style: (i == current
                            ? AppText.title(context)
                            : AppText.body(context))
                        .copyWith(
                      color: i <= current
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      fontWeight: i == current
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.now});

  final bool done;
  final bool now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (done) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.seed,
        ),
        child: Icon(
          Icons.check,
          size: 14,
          color: scheme.onPrimary,
        ),
      );
    }
    if (now) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.seed, width: 2.5),
          color: AppColors.seed.withValues(alpha: 0.15),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.seed,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHighest,
      ),
    );
  }
}
