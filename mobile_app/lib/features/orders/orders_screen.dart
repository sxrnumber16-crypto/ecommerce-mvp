import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../design/components/app_card.dart';
import '../../design/components/app_chip.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import 'orders_api.dart';

/// Status pill color. Status STRINGS are never changed — only the
/// pill tint. Derived from theme scheme + success/error accents.
Color _statusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case 'pending':
      return AppColors.price;
    case 'confirmed':
      return scheme.primary;
    case 'shipped':
      return scheme.secondary;
    case 'delivered':
      return AppColors.success;
    case 'cancelled':
      return scheme.error;
    default:
      return scheme.onSurfaceVariant;
  }
}

/// `GET /orders` list navy restyle (Orvix dark-navy concept).
///
/// Data flow is identical to the legacy screen: one
/// `ordersApiProvider.list()` future, `_reload` for retry/pull, empty
/// state routing to `/search`, row tap routing to `/orders/:id`.
/// Status strings, payment fields, totals, and bilingual copy are
/// verbatim. New look only: status [AppChip] filters (client-side over
/// the fetched list — never a query param), navy order [AppCard]s with
/// a status pill, and a blue price via tokens.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

const _statuses = <String>[
  'pending',
  'confirmed',
  'shipped',
  'delivered',
  'cancelled',
];

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late Future<List<OrderSummary>> _future;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _future = ref.read(ordersApiProvider).list();
  }

  void _reload() =>
      setState(() => _future = ref.read(ordersApiProvider).list());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('অর্ডার / Orders')),
      body: FutureBuilder<List<OrderSummary>>(
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
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return EmptyView(
              message: 'কোনো অর্ডার নেই / No orders yet',
              actionLabel: 'কেনাকাটা করুন / Shop now',
              onAction: () => context.go('/search'),
            );
          }
          final visible = _filter == null
              ? orders
              : orders.where((o) => o.status == _filter).toList();
          return Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.l,
                    vertical: AppSpace.s,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.s),
                      child: AppChip(
                        label: 'সব / All',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                    ),
                    for (final s in _statuses)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpace.s),
                        child: AppChip(
                          label: s,
                          selected: _filter == s,
                          onTap: () => setState(() => _filter = s),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyView(
                        message: 'এই অবস্থায় কোনো অর্ডার নেই / '
                            'No orders with this status',
                        actionLabel: 'সব দেখুন / Show all',
                        onAction: () => setState(() => _filter = null),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _reload(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpace.l),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpace.m),
                          itemBuilder: (context, i) {
                            final o = visible[i];
                            final color = _statusColor(context, o.status);
                            return AppCard(
                              onTap: () => context.push('/orders/${o.id}'),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpace.m),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.card),
                                      ),
                                      child: Icon(
                                        Icons.receipt_long_outlined,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpace.m),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'অর্ডার #${o.id} • '
                                            '${o.itemCount} টি পণ্য',
                                            style:
                                                AppText.title(context),
                                          ),
                                          const SizedBox(
                                              height: AppSpace.xs),
                                          Text(
                                            Config.bdt(o.total),
                                            style: AppText.price(context)
                                                .copyWith(
                                              color: AppColors.price,
                                            ),
                                          ),
                                          const SizedBox(
                                              height: AppSpace.xs),
                                          Text(
                                            '${o.paymentMethod}/'
                                            '${o.paymentStatus}',
                                            style: AppText.body(context)
                                                .copyWith(
                                              color: scheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpace.s),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: AppSpace.m,
                                        vertical: AppSpace.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.pill),
                                      ),
                                      child: Text(
                                        o.status,
                                        style: AppText.label(context)
                                            .copyWith(
                                          color: color,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
