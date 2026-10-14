import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import 'admin_api.dart';
import 'admin_gate.dart';

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

/// Admin orders: `GET /admin/orders` list with inline detail (items,
/// buyer email, payment `unpaid`/`paid` chip) and a status dropdown
/// (`PATCH /admin/orders/:id/status`). Guarded by [AdminGate].
class OrdersAdminScreen extends ConsumerStatefulWidget {
  const OrdersAdminScreen({super.key});

  @override
  ConsumerState<OrdersAdminScreen> createState() => _OrdersAdminScreenState();
}

class _OrdersAdminScreenState extends ConsumerState<OrdersAdminScreen> {
  late Future<PagedAdminOrders> _future;
  final _updating = <int>{};

  @override
  void initState() {
    super.initState();
    _future = ref.read(adminApiProvider).listOrders(limit: 20);
  }

  void _reload() => setState(
      () => _future = ref.read(adminApiProvider).listOrders(limit: 20));

  Future<void> _setStatus(AdminOrder order, String status) async {
    if (_updating.contains(order.id) || status == order.status) return;
    setState(() => _updating.add(order.id));
    try {
      final updated = await ref
          .read(adminApiProvider)
          .updateOrderStatus(order.id, status);
      if (!mounted) return;
      setState(() {
        _updating.remove(order.id);
        _future = _future.then((p) => PagedAdminOrders(
              items: p.items
                  .map((o) => o.id == order.id ? updated : o)
                  .toList(),
              page: p.page,
              limit: p.limit,
              total: p.total,
            ));
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('অর্ডার #${order.id} → $status')));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _updating.remove(order.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      fallback: const AdminDenied(),
      child: Scaffold(
        appBar: AppBar(title: const Text('অর্ডার পরিচালনা / Orders')),
        body: FutureBuilder<PagedAdminOrders>(
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
            final page = snapshot.data!;
            if (page.items.isEmpty) {
              return const EmptyState(
                message: 'কোনো অর্ডার নেই / No orders yet',
                icon: Icons.receipt_long_outlined,
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: page.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _OrderCard(order: page.items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final AdminOrder order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        context.findAncestorStateOfType<_OrdersAdminScreenState>();
    final color = _statusColor(context, order.status);
    final payColor = order.paymentStatus == 'paid'
        ? Colors.green
        : Theme.of(context).colorScheme.outline;
    return Card(
      child: ExpansionTile(
        title: Text('অর্ডার #${order.id} • ${order.userEmail}'),
        subtitle: Text(
            '${Config.bdt(order.total)} • ${order.paymentMethod}'),
        trailing: Chip(
          label: Text(order.paymentStatus),
          backgroundColor: payColor.withValues(alpha: 0.15),
          labelStyle:
              TextStyle(color: payColor, fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.map((it) => Text(
                    '• ${it['name'] ?? ''} × ${it['qty'] ?? ''} — ${Config.bdt((it['lineTotal'] as num?)?.toInt() ?? 0)}')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text(order.status),
                      backgroundColor: color.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                          color: color, fontWeight: FontWeight.w600),
                      side: BorderSide.none,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          isDense: true,
                        ),
                        child: DropdownButton<String>(
                          value: adminOrderStatuses.contains(order.status)
                              ? order.status
                              : null,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          hint: Text(order.status),
                          items: adminOrderStatuses
                              .map((s) => DropdownMenuItem(
                                  value: s, child: Text(s)))
                              .toList(),
                          onChanged: (s) {
                            if (s != null) state?._setStatus(order, s);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
