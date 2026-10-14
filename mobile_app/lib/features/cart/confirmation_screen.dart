import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import '../orders/orders_api.dart';

/// Post-order success: order id, `pending` status, `unpaid` payment, and a
/// COD reassurance message. All figures come from `GET /orders/:id`.
class ConfirmationScreen extends ConsumerStatefulWidget {
  final int orderId;

  const ConfirmationScreen({super.key, required this.orderId});

  @override
  ConsumerState<ConfirmationScreen> createState() =>
      _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  late Future<OrderDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(ordersApiProvider).detail(widget.orderId);
  }

  void _reload() =>
      setState(() => _future = ref.read(ordersApiProvider).detail(widget.orderId));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('অর্ডার সম্পন্ন / Done')),
      body: FutureBuilder<OrderDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingState(
                message: 'অর্ডার নিশ্চিত হচ্ছে… / Confirming…');
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: friendlyError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final order = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(Icons.check_circle_outline,
                  size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'অর্ডার সফল! / Order placed!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'অর্ডার #${order.id} • অবস্থা: ${order.status} (pending) • পেমেন্ট: ${order.paymentStatus} (unpaid)',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'ক্যাশ অন ডেলিভারি — পণ্য হাতে পেয়ে টাকা দিন / Cash on Delivery — pay when you receive your order.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('সাবটোটাল / Subtotal:'),
                          Text(Config.bdt(order.subtotal)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ডেলিভারি / Delivery:'),
                          Text(Config.bdt(order.deliveryFee)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('সর্বমোট / Total:'),
                          Text(
                            Config.bdt(order.total),
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/orders/${order.id}'),
                child: const Text('অর্ডার দেখুন / View order'),
              ),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('আরো কেনাকাটা / Continue shopping'),
              ),
            ],
          );
        },
      ),
    );
  }
}
