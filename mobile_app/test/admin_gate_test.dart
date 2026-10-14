import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/api_client.dart';
import 'package:myapp/core/auth_store.dart';
import 'package:myapp/features/admin/admin_api.dart';
import 'package:myapp/features/admin/admin_gate.dart';

// UNVERIFIED: no Flutter SDK on this machine — not run.

/// Test [AuthStore] preset to a fixed role without touching storage.
class _TestAuthStore extends AuthStore {
  _TestAuthStore(super.api, String? role) {
    state = AuthState(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      role: role,
    );
  }
}

Widget _gateFor(String? role) {
  return ProviderScope(
    overrides: [
      authStoreProvider.overrideWith((ref) => _TestAuthStore(
            ref.watch(apiClientProvider),
            role,
          )),
    ],
    child: const MaterialApp(
      home: AdminGate(
        fallback: Text('denied'),
        child: Text('admin-content'),
      ),
    ),
  );
}

void main() {
  test('AuthState.isAdmin is true only for role == admin', () {
    expect(const AuthState(role: 'admin').isAdmin, isTrue);
    expect(const AuthState(role: 'customer').isAdmin, isFalse);
    expect(const AuthState().isAdmin, isFalse);
  });

  testWidgets('AdminGate shows child for admin role', (tester) async {
    await tester.pumpWidget(_gateFor('admin'));
    await tester.pump();
    expect(find.text('admin-content'), findsOneWidget);
    expect(find.text('denied'), findsNothing);
  });

  testWidgets('AdminGate shows fallback for customer role', (tester) async {
    await tester.pumpWidget(_gateFor('customer'));
    await tester.pump();
    expect(find.text('denied'), findsOneWidget);
    expect(find.text('admin-content'), findsNothing);
  });

  testWidgets('AdminGate shows fallback when logged out', (tester) async {
    await tester.pumpWidget(_gateFor(null));
    await tester.pump();
    expect(find.text('denied'), findsOneWidget);
    expect(find.text('admin-content'), findsNothing);
  });

  test('DashboardSummary parses backend shape with aliases', () {
    final d = DashboardSummary.fromJson(<String, dynamic>{
      'users': 10,
      'products': 25,
      'activeProducts': 20,
      'ordersByStatus': {'pending': 3, 'delivered': 7},
      'lowStock': [
        {
          'id': 1,
          'name': 'Saree',
          'slug': 'saree',
          'stock': 2,
          'priceBdt': 1500,
          'isActive': true,
        },
      ],
      'revenue': 99900,
    });
    expect(d.users, 10);
    expect(d.activeProducts, 20);
    expect(d.ordersByStatus['pending'], 3);
    expect(d.lowStock, hasLength(1));
    expect(d.revenue, 99900);
    expect(adminOrderStatuses,
        containsAll(['pending', 'confirmed', 'shipped', 'delivered', 'cancelled']));
  });
}
