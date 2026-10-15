import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/admin/admin_screen.dart';

// UNVERIFIED: no Flutter SDK on this machine — verified via CI.

// Pumps the dashboard chart section ([AnalyticsCharts]) with the plan's
// fake analytics JSON (days 7, daily 2 rows, topProducts Panjabi,
// ordersByStatus, lowStock Kurti) and expects revenue text + top product.
void main() {
  testWidgets('analytics charts show revenue and top product', (tester) async {
    final fake = <String, dynamic>{
      'days': 7,
      'daily': [
        {'date': '2026-10-08', 'orders': 2, 'revenue': 2500},
        {'date': '2026-10-09', 'orders': 0, 'revenue': 0},
      ],
      'topProducts': [
        {'id': 1, 'name': 'Panjabi', 'qty': 5, 'revenue': 6250},
      ],
      'ordersByStatus': {'pending': 1, 'delivered': 1},
      'lowStock': [
        {'id': 2, 'name': 'Kurti', 'stock': 3},
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AnalyticsCharts(data: fake)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2,500'), findsWidgets);
    expect(find.text('Panjabi'), findsOneWidget);
  });

  testWidgets('analytics charts show low-stock row', (tester) async {
    final fake = <String, dynamic>{
      'days': 7,
      'daily': [
        {'date': '2026-10-08', 'orders': 2, 'revenue': 2500},
        {'date': '2026-10-09', 'orders': 0, 'revenue': 0},
      ],
      'topProducts': [
        {'id': 1, 'name': 'Panjabi', 'qty': 5, 'revenue': 6250},
      ],
      'ordersByStatus': {'pending': 1, 'delivered': 1},
      'lowStock': [
        {'id': 2, 'name': 'Kurti', 'stock': 3},
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AnalyticsCharts(data: fake)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kurti'), findsOneWidget);
  });
}
