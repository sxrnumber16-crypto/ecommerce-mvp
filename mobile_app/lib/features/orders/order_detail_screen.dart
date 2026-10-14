import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import 'orders_api.dart';

/// `GET /orders/:id`: items + payment + a status timeline
/// (`pending → confirmed → shipped → delivered`; `cancelled` terminal).
/// All money figures are server-calculated.
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

  void _reload() =>
      setState(() => _future = ref.read(ordersApiProvider).detail(widget.orderId));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('অর্ডার #${widget.orderId}')),
      body: FutureBuilder<OrderDetail>(
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
          final order = snapshot.data!;
          final step = _flow.indexOf(order.status);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('অবস্থা / Status: ${order.status}',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (order.status == 'cancelled')
                  Chip(
                    label: const Text('বাতিল / Cancelled'),
                    backgroundColor:
                        theme.colorScheme.error.withValues(alpha: 0.15),
                  )
                else
                  Stepper(
                    currentStep: step < 0 ? 0 : step,
                    controlsBuilder: (_, __) => const SizedBox.shrink(),
                    physics: const NeverScrollableScrollPhysics(),
                    steps: [
                      for (var i = 0; i < _flow.length; i++)
                        Step(
                          title: Text(_flow[i]),
                          content: const SizedBox.shrink(),
                          isActive: i <= step,
                          state: i < step
                              ? StepState.complete
                              : i == step
                                  ? StepState.indexed
                                  : StepState.disabled,
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                Text(
                    'পেমেন্ট: ${order.paymentMethod} / ${order.paymentStatus} • ${Config.bdt(order.paymentAmount)}'),
                if (order.addressLine != null)
                  Text('ঠিকানা / Address: ${order.addressLine}'),
                const Divider(height: 32),
                Text('পণ্য / Items',
                    style: theme.textTheme.titleMedium),
                for (final item in order.items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(
                        '×${item.qty} • ${Config.bdt(item.unitPrice)}'),
                    trailing: Text(Config.bdt(item.lineTotal)),
                  ),
                const Divider(),
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
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('সর্বমোট / Total:'),
                    Text(
                      Config.bdt(order.total),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
