import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import 'orders_api.dart';

Color _statusColor(BuildContext context, String status) {
  switch (status) {
    case 'pending':
      return Colors.orange;
    case 'confirmed':
      return Colors.blue;
    case 'shipped':
      return Colors.purple;
    case 'delivered':
      return Colors.green;
    case 'cancelled':
      return Theme.of(context).colorScheme.error;
    default:
      return Theme.of(context).colorScheme.outline;
  }
}

/// `GET /orders` list with status chips. Tap → `/orders/:id`.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late Future<List<OrderSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(ordersApiProvider).list();
  }

  void _reload() =>
      setState(() => _future = ref.read(ordersApiProvider).list());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('অর্ডার / Orders')),
      body: FutureBuilder<List<OrderSummary>>(
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
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return EmptyState(
              message: 'কোনো অর্ডার নেই / No orders yet',
              icon: Icons.receipt_long_outlined,
              actionLabel: 'কেনাকাটা করুন / Shop now',
              onAction: () => context.go('/search'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final o = orders[i];
                final color = _statusColor(context, o.status);
                return Card(
                  child: ListTile(
                    onTap: () => context.push('/orders/${o.id}'),
                    title: Text('অর্ডার #${o.id} • ${o.itemCount} টি পণ্য'),
                    subtitle: Text(
                        '${Config.bdt(o.total)} • ${o.paymentMethod}/${o.paymentStatus}'),
                    trailing: Chip(
                      label: Text(o.status),
                      backgroundColor: color.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                          color: color, fontWeight: FontWeight.w600),
                      side: BorderSide.none,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
