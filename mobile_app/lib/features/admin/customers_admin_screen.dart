import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../design/components/app_card.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import 'admin_api.dart';
import 'admin_gate.dart';

/// Admin customers tab consuming `GET /admin/customers` (search over
/// email/fullName/phone, `page`/`limit` envelope) with rows routing to
/// the customer detail (`/admin/customers/:id`). Guarded by [AdminGate];
/// reachable from the dashboard Customers entry and `/admin/customers`.
/// Bilingual copy; design tokens only.
class CustomersAdminScreen extends ConsumerStatefulWidget {
  const CustomersAdminScreen({super.key});

  @override
  ConsumerState<CustomersAdminScreen> createState() =>
      _CustomersAdminScreenState();
}

class _CustomersAdminScreenState extends ConsumerState<CustomersAdminScreen> {
  final _search = TextEditingController();
  late Future<PagedAdminCustomers> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<PagedAdminCustomers> _fetch() {
    return ref.read(adminApiProvider).listCustomers(
          search: _search.text,
          limit: 20,
        );
  }

  void _reload() => setState(() => _future = _fetch());

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      fallback: const AdminDenied(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('গ্রাহক / Customers'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.l, AppSpace.m, AppSpace.l, AppSpace.s),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _reload(),
                decoration: InputDecoration(
                  labelText: 'খুঁজুন / Search',
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'খুঁজুন / Search',
                    icon: const Icon(Icons.arrow_forward_outlined),
                    onPressed: _reload,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.l,
                    vertical: AppSpace.m,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<PagedAdminCustomers>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: friendlyError(snapshot.error!),
                      onRetry: _reload,
                    );
                  }
                  final items = snapshot.data!.items;
                  if (items.isEmpty) {
                    return const EmptyView(
                      message: 'কোনো গ্রাহক নেই / No customers',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: CustomersAdminListView(
                      items: items,
                      onTap: (c) =>
                          context.push('/admin/customers/${c.id}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pure (API-free) customers list: name/email/order-count rows with a
/// status badge (suspended = red). Callbacks keep this widget hermetic
/// for widget tests; [CustomersAdminScreen] wires the real admin API.
class CustomersAdminListView extends StatelessWidget {
  final List<AdminCustomer> items;
  final ValueChanged<AdminCustomer>? onTap;

  const CustomersAdminListView({
    super.key,
    required this.items,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.l),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.m),
      itemBuilder: (context, i) {
        final customer = items[i];
        return _CustomerRow(
          customer: customer,
          onTap: onTap == null ? null : () => onTap!(customer),
        );
      },
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final AdminCustomer customer;
  final VoidCallback? onTap;

  const _CustomerRow({required this.customer, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suspended = customer.isSuspended;
    final badgeColor = suspended ? scheme.error : AppColors.success;
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.seed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.seed,
              ),
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(context),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    customer.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(context),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'অর্ডার: ${customer.orderCount} • '
                    '${Config.bdt(customer.totalSpent)}',
                    style: AppText.body(context),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.m,
                      vertical: AppSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
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
            ),
            const Icon(Icons.chevron_right_outlined),
          ],
        ),
      ),
    );
  }
}

/// Suspend/unsuspend error surfaced by `PATCH
/// /admin/customers/:id/status` when an admin targets themselves.
String customerStatusErrorMessage(DioException e) {
  if (e.response?.statusCode == 409) {
    return 'নিজেকে স্থগিত করা যাবে না / You cannot suspend yourself';
  }
  if (e.response?.statusCode == 403) {
    return 'অনুমতি নেই / You are not allowed to do this';
  }
  return friendlyError(e);
}
