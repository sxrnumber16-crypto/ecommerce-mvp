import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../design/components/app_card.dart';
import '../../design/components/sheets.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import 'admin_api.dart';
import 'admin_gate.dart';

/// Status pill tint. Status STRINGS are never changed — only the pill
/// tint. Same accents as the customer orders list.
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

/// Admin orders reskin: `GET /admin/orders` list with inline detail
/// (items, buyer email, read-only payment `unpaid`/`paid` chip) and a
/// status bottom-sheet (`PATCH /admin/orders/:id/status`). Guarded by
/// [AdminGate].
///
/// Paging (`page`/`limit`/`total` envelope, `limit: 20`), the
/// `_updating` guard, the status enum, and all SnackBar copy are
/// identical to the legacy screen. New look only: order [AppCard]s
/// with a status pill and a [showAppSheet] status picker instead of
/// the inline dropdown. Payment stays read-only.
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

  /// Status bottom-sheet: lists [adminOrderStatuses] with a check on
  /// the current status; returns the picked status (or null when
  /// dismissed) and applies it via [_setStatus].
  Future<void> _pickStatus(AdminOrder order) async {
    final picked = await showAppSheet<String>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'স্ট্যাটাস / Status — অর্ডার #${order.id}',
            textAlign: TextAlign.center,
            style: AppText.title(context),
          ),
          const SizedBox(height: AppSpace.m),
          for (final s in adminOrderStatuses)
            _StatusOption(
              status: s,
              selected: s == order.status,
              onTap: () => Navigator.of(context).pop(s),
            ),
        ],
      ),
    );
    if (picked != null && mounted) await _setStatus(order, picked);
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
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(
                message: friendlyError(snapshot.error!),
                onRetry: _reload,
              );
            }
            final page = snapshot.data!;
            if (page.items.isEmpty) {
              return const EmptyView(
                message: 'কোনো অর্ডার নেই / No orders yet',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpace.l),
                itemCount: page.items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpace.m),
                itemBuilder: (context, i) {
                  final order = page.items[i];
                  final updating = _updating.contains(order.id);
                  return _OrderCard(
                    order: order,
                    updating: updating,
                    onChangeStatus: () => _pickStatus(order),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final AdminOrder order;
  final bool updating;
  final VoidCallback onChangeStatus;

  const _OrderCard({
    required this.order,
    required this.updating,
    required this.onChangeStatus,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _statusColor(context, order.status);
    final payColor = order.paymentStatus == 'paid'
        ? AppColors.success
        : scheme.onSurfaceVariant;
    return AppCard(
      child: ExpansionTile(
        title: Text(
          'অর্ডার #${order.id} • ${order.userEmail}',
          style: AppText.title(context),
        ),
        subtitle: Text(
          '${Config.bdt(order.total)} • ${order.paymentMethod}',
          style: AppText.body(context),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.m,
            vertical: AppSpace.xs,
          ),
          decoration: BoxDecoration(
            color: payColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            order.paymentStatus,
            style: AppText.label(context).copyWith(
              color: payColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.l, 0, AppSpace.l, AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final it in order.items)
                  Text(
                    '• ${it['name'] ?? ''} × ${it['qty'] ?? ''} — ${Config.bdt((it['lineTotal'] as num?)?.toInt() ?? 0)}',
                    style: AppText.body(context),
                  ),
                const SizedBox(height: AppSpace.s),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.m,
                        vertical: AppSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        order.status,
                        style: AppText.label(context).copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (updating)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton.icon(
                        onPressed: onChangeStatus,
                        icon: const Icon(Icons.swap_horiz_outlined),
                        label:
                            const Text('পরিবর্তন / Change'),
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

class _StatusOption extends StatelessWidget {
  final String status;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s),
      child: AppCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.m,
                  vertical: AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  status,
                  style: AppText.label(context).copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (selected)
                Icon(Icons.check_circle, color: color)
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
