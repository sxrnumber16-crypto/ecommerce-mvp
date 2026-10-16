import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_card.dart';
import '../../design/components/section_header.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import 'admin_api.dart';
import 'admin_gate.dart';
import 'customers_admin_screen.dart' show customerStatusErrorMessage;

/// Admin customer detail consuming `GET /admin/customers/:id` (info
/// card + addresses + order history + payment aggregates + spent) with
/// Suspend/Unsuspend via `PATCH /admin/customers/:id/status` behind a
/// bilingual confirm dialog. Guarded by [AdminGate]. Bilingual copy;
/// design tokens only. Suspended badge is red.
class CustomerDetailScreen extends ConsumerStatefulWidget {
  final int customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  late Future<AdminCustomerDetail> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(adminApiProvider).customerDetail(widget.customerId);
  }

  void _reload() => setState(
      () => _future = ref.read(adminApiProvider).customerDetail(widget.customerId));

  /// Suspend/unsuspend via `PATCH /admin/customers/:id/status`. A `409`
  /// means self-suspend (blocked with a hint); `403` means the target
  /// is an admin. On success the detail reloads (badge flips).
  Future<void> _setStatus(AdminCustomerDetail customer, String status) async {
    if (_busy || status == customer.status) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminApiProvider)
          .setCustomerStatus(customer.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'suspended'
            ? 'স্থগিত করা হয়েছে / Suspended'
            : 'সক্রিয় করা হয়েছে / Re-activated'),
      ));
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(customerStatusErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      fallback: const AdminDenied(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('গ্রাহক বিবরণ / Customer'),
        ),
        body: FutureBuilder<AdminCustomerDetail>(
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
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpace.l),
                child: CustomerDetailView(
                  customer: snapshot.data!,
                  busy: _busy,
                  onStatusConfirmed: (status) =>
                      _setStatus(snapshot.data!, status),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Pure (API-free) customer detail: info card + spent + order history +
/// a Suspend/Unsuspend button behind a bilingual confirm dialog. The
/// suspended badge is red ([ColorScheme.error]). Callbacks keep this
/// widget hermetic for widget tests; [CustomerDetailScreen] wires the
/// real admin API calls.
class CustomerDetailView extends StatelessWidget {
  final AdminCustomerDetail customer;
  final ValueChanged<String>? onStatusConfirmed;
  final bool busy;

  const CustomerDetailView({
    super.key,
    required this.customer,
    this.onStatusConfirmed,
    this.busy = false,
  });

  Future<void> _confirmStatus(BuildContext context) async {
    final suspending = !customer.isSuspended;
    final target = suspending ? 'suspended' : 'active';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspending
            ? 'স্থগিত করবেন? / Suspend?'
            : 'সক্রিয় করবেন? / Unsuspend?'),
        content: Text(suspending
            ? 'এই গ্রাহক আর লগইন করতে পারবে না। / '
                'This customer will no longer be able to log in.'
            : 'এই গ্রাহক আবার লগইন করতে পারবে। / '
                'This customer will be able to log in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল / Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
                suspending ? 'স্থগিত / Suspend' : 'সক্রিয় / Unsuspend'),
          ),
        ],
      ),
    );
    if (confirm == true) onStatusConfirmed?.call(target);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suspended = customer.isSuspended;
    final badgeColor = suspended ? scheme.error : AppColors.success;
    final payments = customer.payments;
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer.displayName,
                        style: AppText.title(context),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.m,
                        vertical: AppSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        suspended
                            ? 'স্থগিত / Suspended'
                            : 'সক্রিয় / Active',
                        style: AppText.label(context).copyWith(
                          color: badgeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s),
                Text(customer.email, style: AppText.body(context)),
                if (customer.phone.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(customer.phone, style: AppText.body(context)),
                ],
                const SizedBox(height: AppSpace.xs),
                Text(
                  'ভূমিকা: ${customer.role} • যোগদান: ${customer.createdAt}',
                  style: AppText.label(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.l),
        const SectionHeader(title: 'খরচ / Spending'),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: Text(
              'অর্ডার: ${customer.orderCount} • '
              'মোট: ${Config.bdt(customer.totalSpent)} • '
              'পরিশোধিত: ${asInt(payments['paid'])} • '
              'বকেয়া: ${asInt(payments['unpaid'])}',
              style: AppText.body(context),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.l),
        SectionHeader(
            title: 'অর্ডার ইতিহাস (${customer.orders.length}) / History'),
        if (customer.orders.isEmpty)
          const EmptyView(message: 'কোনো অর্ডার নেই / No orders yet')
        else
          ...customer.orders.map(
            (o) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s),
              child: AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.m),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${o['id']} • ${o['status']}',
                              style: AppText.title(context),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              '${Config.bdt(asInt(o['total']))} • '
                              '${o['createdAt'] ?? ''}',
                              style: AppText.body(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpace.l),
        if (onStatusConfirmed != null)
          AppButton(
            label: suspended
                ? 'সক্রিয় করুন / Unsuspend'
                : 'স্থগিত করুন / Suspend',
            outlined: suspended,
            loading: busy,
            onPressed: busy ? null : () => _confirmStatus(context),
          ),
      ],
    );
  }
}
