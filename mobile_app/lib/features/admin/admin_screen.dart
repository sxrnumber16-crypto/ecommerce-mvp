import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_card.dart';
import '../../design/components/app_chip.dart';
import '../../design/components/section_header.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import 'admin_api.dart';
import 'admin_gate.dart';

int _asInt(Object? v) => v is num ? v.toInt() : 0;

List<Map<String, dynamic>> _rows(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

Map<String, int> _statusOf(Object? v) {
  final status = <String, int>{};
  if (v is Map) {
    v.forEach((k, val) => status[k.toString()] = _asInt(val));
  }
  return status;
}

/// Admin dashboard v2 navy restyle (Orvix dark-navy concept): stat
/// [AppCard]s (`users`, `products`/`activeProducts`, total orders,
/// `revenue` from `GET /admin/dashboard`) plus analytics charts from
/// `GET /admin/analytics` ([AnalyticsCharts]) and entry points to
/// product create/edit and the admin orders list.
///
/// Data flow mirrors the legacy screen: a dashboard future plus an
/// analytics future keyed by the selected day-range, `_reload` for
/// retry/pull, low-stock rows routing to `/admin/products/:id/edit`.
/// Guarded by [AdminGate]; route `/admin` also redirects non-admins
/// to `/home` in `app.dart`. Bilingual copy. Blue accents via tokens.
/// New look only.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  static const _dayOptions = <int>[7, 14, 30];

  late Future<DashboardSummary> _future;
  late Future<Map<String, dynamic>> _analyticsFuture;
  int _days = 14;

  @override
  void initState() {
    super.initState();
    final api = ref.read(adminApiProvider);
    _future = api.dashboard();
    _analyticsFuture = api.getAnalytics(days: _days);
  }

  void _reload() => setState(() {
        final api = ref.read(adminApiProvider);
        _future = api.dashboard();
        _analyticsFuture = api.getAnalytics(days: _days);
      });

  void _reloadAnalytics() => setState(() {
        _analyticsFuture =
            ref.read(adminApiProvider).getAnalytics(days: _days);
      });

  void _setDays(int days) {
    if (days == _days) return;
    setState(() {
      _days = days;
      _analyticsFuture = ref.read(adminApiProvider).getAnalytics(days: days);
    });
  }

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
              return const Padding(
                padding: EdgeInsets.all(AppSpace.l),
                child: LoadingGrid(),
              );
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
                  const SectionHeader(title: 'Analytics / অ্যানালিটিক্স'),
                  Wrap(
                    spacing: AppSpace.s,
                    runSpacing: AppSpace.s,
                    children: _dayOptions
                        .map(
                          (v) => AppChip(
                            label: '$v days / $v দিন',
                            selected: v == _days,
                            onTap: () => _setDays(v),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpace.s),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _analyticsFuture,
                    builder: (context, analytics) {
                      if (analytics.connectionState ==
                          ConnectionState.waiting) {
                        return const LoadingGrid();
                      }
                      if (analytics.hasError) {
                        return ErrorView(
                          message: friendlyError(analytics.error!),
                          onRetry: _reloadAnalytics,
                        );
                      }
                      return AnalyticsCharts(
                        data: analytics.data!,
                        onSelectProduct: (id) =>
                            context.push('/admin/products/$id/edit'),
                      );
                    },
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Pure chart section for the dashboard, fed by the decoded
/// `GET /admin/analytics` map (`days`, `daily`, `topProducts`,
/// `ordersByStatus`, `lowStock`). Revenue as a blue [LineChart], orders
/// as a [BarChart], status as a donut [PieChart], plus the top-5 list
/// and low-stock cards. Blue-family chart colors
/// (`scheme.primary`/`secondary`/`tertiary`, reusing the status legend
/// palette — no hardcoded teal/green) + design tokens only, so
/// light/dark mode both work.
class AnalyticsCharts extends StatelessWidget {
  final Map<String, dynamic> data;
  final ValueChanged<int>? onSelectProduct;

  const AnalyticsCharts({
    super.key,
    required this.data,
    this.onSelectProduct,
  });

  @override
  Widget build(BuildContext context) {
    final daily = _rows(data['daily']);
    final topProducts = _rows(data['topProducts']);
    final lowStock = _rows(data['lowStock']);
    final status = _statusOf(data['ordersByStatus']);
    final totalRevenue =
        daily.fold<int>(0, (sum, e) => sum + _asInt(e['revenue']));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Revenue / আয়'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
          child: Text(
            Config.bdt(totalRevenue),
            style: AppText.headline(context),
          ),
        ),
        const SizedBox(height: AppSpace.s),
        _card(_revenueChart(context, daily)),
        const SizedBox(height: AppSpace.l),
        const SectionHeader(title: 'Orders / অর্ডার'),
        _card(_ordersChart(context, daily)),
        const SizedBox(height: AppSpace.l),
        const SectionHeader(title: 'Status / অবস্থা'),
        _card(_statusChart(context, status)),
        const SizedBox(height: AppSpace.s),
        _statusLegend(context, status),
        const SizedBox(height: AppSpace.l),
        const SectionHeader(title: 'Top products / সেরা পণ্য'),
        if (topProducts.isEmpty)
          const EmptyView(message: 'কোনো বিক্রি নেই / No sales yet')
        else
          ...topProducts.map(
            (p) => Padding(
              padding:
                  const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.s),
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
                              p['name'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title(context),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              'বিক্রি: ${_asInt(p['qty'])} • '
                              '${Config.bdt(_asInt(p['revenue']))}',
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
        const SizedBox(height: AppSpace.s),
        SectionHeader(
          title: 'Low stock (≤5): ${lowStock.length} / কম স্টক',
        ),
        if (lowStock.isEmpty)
          const EmptyView(
            message: 'সব স্টক ঠিক আছে / Stock levels OK',
          )
        else
          ...lowStock.map(
            (p) => Padding(
              padding:
                  const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.s),
              child: AppCard(
                onTap: onSelectProduct == null
                    ? null
                    : () => onSelectProduct!(_asInt(p['id'])),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.m),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.seed.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppRadius.card),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.seed,
                        ),
                      ),
                      const SizedBox(width: AppSpace.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title(context),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              'স্টক: ${_asInt(p['stock'])}',
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
    );
  }

  Widget _card(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: child,
          ),
        ),
      );

  Widget _revenueChart(
      BuildContext context, List<Map<String, dynamic>> daily) {
    if (daily.isEmpty) {
      return const EmptyView(message: 'কোনো তথ্য নেই / No data yet');
    }
    final scheme = Theme.of(context).colorScheme;
    final spots = <FlSpot>[
      for (var i = 0; i < daily.length; i++)
        FlSpot(i.toDouble(), _asInt(daily[i]['revenue']).toDouble()),
    ];
    final peak = spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: spots.length < 2 ? 1.0 : (spots.length - 1).toDouble(),
          minY: 0,
          maxY: peak <= 0 ? 1.0 : peak * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: scheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ordersChart(
      BuildContext context, List<Map<String, dynamic>> daily) {
    if (daily.isEmpty) {
      return const EmptyView(message: 'কোনো তথ্য নেই / No data yet');
    }
    final scheme = Theme.of(context).colorScheme;
    final peak = daily.fold<int>(0, (a, e) => a > _asInt(e['orders']) ? a : _asInt(e['orders']));
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: peak <= 0 ? 1.0 : (peak + 1).toDouble(),
          barGroups: [
            for (var i = 0; i < daily.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: _asInt(daily[i]['orders']).toDouble(),
                    color: scheme.primary,
                    width: 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChart(BuildContext context, Map<String, int> status) {
    final entries = status.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) {
      return const EmptyView(message: 'কোনো অর্ডার নেই / No orders yet');
    }
    final scheme = Theme.of(context).colorScheme;
    final palette = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
      scheme.outline,
    ];
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(enabled: false),
          sectionsSpace: 2,
          centerSpaceRadius: 36,
          sections: [
            for (var i = 0; i < entries.length; i++)
              PieChartSectionData(
                value: entries[i].value.toDouble(),
                color: palette[i % palette.length],
                title: '${entries[i].value}',
                radius: 44,
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusLegend(BuildContext context, Map<String, int> status) {
    final entries = status.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final palette = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
      scheme.outline,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
      child: Wrap(
        spacing: AppSpace.s,
        runSpacing: AppSpace.s,
        children: [
          for (var i = 0; i < entries.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: palette[i % palette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Text(
                  '${entries[i].key}: ${entries[i].value}',
                  style: AppText.label(context),
                ),
              ],
            ),
        ],
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
            Icon(icon, color: AppColors.seed),
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
