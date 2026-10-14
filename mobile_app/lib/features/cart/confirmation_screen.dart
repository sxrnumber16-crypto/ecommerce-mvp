import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_card.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import '../orders/orders_api.dart';

/// Post-order success reskin: order id, `pending` status, `unpaid`
/// payment, and a COD reassurance message.
///
/// Data flow is identical to the legacy screen — all figures come from
/// `GET /orders/:id` via `ordersApiProvider.detail(id)`; buttons route
/// to `/orders/:id` and `/home`. COD messaging stays `pending`/`unpaid`.
/// New look only: [AppCard] summary, [AppButton] actions, and a
/// [ScaleTransition] success pop (no new packages).
class ConfirmationScreen extends ConsumerStatefulWidget {
  final int orderId;

  const ConfirmationScreen({super.key, required this.orderId});

  @override
  ConsumerState<ConfirmationScreen> createState() =>
      _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late Future<OrderDetail> _future;
  late final AnimationController _pop;
  late final Animation<double> _scale;
  bool _played = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(ordersApiProvider).detail(widget.orderId);
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _pop, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _played = false;
        _pop.reset();
        _future = ref.read(ordersApiProvider).detail(widget.orderId);
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('অর্ডার সম্পন্ন / Done')),
      body: FutureBuilder<OrderDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpace.m),
                  Text(
                    'অর্ডার নিশ্চিত হচ্ছে… / Confirming…',
                    style: AppText.body(context),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: friendlyError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final order = snapshot.data!;
          if (!_played) {
            _played = true;
            _pop.forward();
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpace.xl),
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 64,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.m),
              Text(
                'অর্ডার সফল! / Order placed!',
                textAlign: TextAlign.center,
                style: AppText.headline(context),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                'অর্ডার #${order.id} • অবস্থা: ${order.status} (pending) • পেমেন্ট: ${order.paymentStatus} (unpaid)',
                textAlign: TextAlign.center,
                style: AppText.body(context),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                'ক্যাশ অন ডেলিভারি — পণ্য হাতে পেয়ে টাকা দিন / Cash on Delivery — pay when you receive your order.',
                textAlign: TextAlign.center,
                style: AppText.body(context)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpace.l),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.l),
                  child: Column(
                    children: [
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
                                color: scheme.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.l),
              AppButton(
                label: 'অর্ডার দেখুন / View order',
                onPressed: () => context.go('/orders/${order.id}'),
              ),
              const SizedBox(height: AppSpace.s),
              AppButton(
                label: 'আরো কেনাকাটা / Continue shopping',
                outlined: true,
                onPressed: () => context.go('/home'),
              ),
            ],
          );
        },
      ),
    );
  }
}
