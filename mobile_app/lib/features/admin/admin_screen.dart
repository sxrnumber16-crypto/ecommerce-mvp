import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import 'admin_api.dart';
import 'admin_gate.dart';

/// Admin dashboard: stat cards (`users`, `products`/`activeProducts`,
/// `ordersByStatus`, `lowStock`, `revenue` from `GET /admin/dashboard`)
/// plus entry points to product create/edit and the admin orders list.
/// Guarded by [AdminGate]; route `/admin` also redirects non-admins
/// to `/home` in `app.dart`.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  late Future<DashboardSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(adminApiProvider).dashboard();
  }

  void _reload() =>
      setState(() => _future = ref.read(adminApiProvider).dashboard());

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      fallback: const AdminDenied(),
      child: Scaffold(
        appBar: AppBar(title: const Text('অ্যাডমিন / Admin')),
        body: FutureBuilder<DashboardSummary>(
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
            final d = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatChip(
                          label: 'Users', value: '${d.users}'),
                      _StatChip(
                          label: 'Products',
                          value: '${d.activeProducts}/${d.products}'),
                      _StatChip(
                          label: 'Revenue', value: Config.bdt(d.revenue)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Orders by status',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (d.ordersByStatus.isEmpty)
                    const Text('No orders yet')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: d.ordersByStatus.entries
                          .map((e) => Chip(
                              label: Text('${e.key}: ${e.value}')))
                          .toList(),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              context.push('/admin/products/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('নতুন পণ্য / New product'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => context.push('/admin/orders'),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('অর্ডার / Orders'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                      'Low stock (≤5): ${d.lowStock.length}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (d.lowStock.isEmpty)
                    const EmptyState(
                      message: 'সব স্টক ঠিক আছে / Stock levels OK',
                      icon: Icons.check_circle_outline,
                    )
                  else
                    ...d.lowStock.map(
                      (p) => Card(
                        child: ListTile(
                          title: Text(p.name),
                          subtitle: Text(
                              'Stock: ${p.stock} • ${Config.bdt(p.priceBdt)}'
                              '${p.isActive ? '' : ' • inactive'}'),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () => context
                              .push('/admin/products/${p.id}/edit'),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
