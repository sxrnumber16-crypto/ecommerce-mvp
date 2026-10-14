import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_card.dart';
import '../../design/components/app_chip.dart';
import '../../design/components/section_header.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import 'admin_api.dart';
import 'admin_gate.dart';

/// Admin dashboard reskin: stat [AppCard]s (`users`,
/// `products`/`activeProducts`, total orders, `revenue` from
/// `GET /admin/dashboard`) plus entry points to product create/edit
/// and the admin orders list.
///
/// Data flow is identical to the legacy screen: one
/// `adminApiProvider.dashboard()` future, `_reload` for retry/pull,
/// `ordersByStatus` chips, low-stock rows routing to
/// `/admin/products/:id/edit`. Guarded by [AdminGate]; route `/admin`
/// also redirects non-admins to `/home` in `app.dart`. Bilingual copy
/// verbatim. New look only.
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
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(
                message: friendlyError(snapshot.error!),
                onRetry: _reload,
              );
            }
            final d = snapshot.data!;
            final orderTotal =
                d.ordersByStatus.values.fold<int>(0, (a, b) => a + b);
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.l),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppSpace.m,
                    crossAxisSpacing: AppSpace.m,
                    childAspectRatio: 1.6,
                    children: [
                      _StatCard(
                        icon: Icons.people_outline,
                        label: 'Users / ব্যবহারকারী',
                        value: '${d.users}',
                      ),
                      _StatCard(
                        icon: Icons.inventory_2_outlined,
                        label: 'Products / পণ্য',
                        value: '${d.activeProducts}/${d.products}',
                      ),
                      _StatCard(
                        icon: Icons.receipt_long_outlined,
                        label: 'Orders / অর্ডার',
                        value: '$orderTotal',
                      ),
                      _StatCard(
                        icon: Icons.payments_outlined,
                        label: 'Revenue / আয়',
                        value: Config.bdt(d.revenue),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.l),
                  const SectionHeader(
                      title: 'Orders by status / অবস্থা অনুযায়ী'),
                  if (d.ordersByStatus.isEmpty)
                    Text(
                      'কোনো অর্ডার নেই / No orders yet',
                      style: AppText.body(context),
                    )
                  else
                    Wrap(
                      spacing: AppSpace.s,
                      runSpacing: AppSpace.s,
                      children: d.ordersByStatus.entries
                          .map((e) => AppChip(label: '${e.key}: ${e.value}'))
                          .toList(),
                    ),
                  const SizedBox(height: AppSpace.l),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'নতুন পণ্য / New',
                          onPressed: () =>
                              context.push('/admin/products/new'),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s),
                      Expanded(
                        child: AppButton(
                          label: 'অর্ডার / Orders',
                          outlined: true,
                          onPressed: () => context.push('/admin/orders'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.l),
                  SectionHeader(
                    title:
                        'Low stock (≤5): ${d.lowStock.length} / কম স্টক',
                  ),
                  if (d.lowStock.isEmpty)
                    const EmptyView(
                      message: 'সব স্টক ঠিক আছে / Stock levels OK',
                    )
                  else
                    ...d.lowStock.map(
                      (p) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpace.s),
                        child: AppCard(
                          onTap: () => context
                              .push('/admin/products/${p.id}/edit'),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.m),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.card),
                                  ),
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
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
                                        'স্টক: ${p.stock} • '
                                        '${Config.bdt(p.priceBdt)}'
                                        '${p.isActive ? '' : ' • নিষ্ক্রিয় / inactive'}',
                                        style: AppText.body(context),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit_outlined),
                              ],
                            ),
                          ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: AppSpace.s),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.headline(context),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(context).copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
