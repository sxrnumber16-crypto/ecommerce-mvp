import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/auth_store.dart'
    show loginErrorMessage, suspendedAccountMessage;
import 'package:myapp/features/admin/admin_api.dart';
import 'package:myapp/features/admin/customer_detail_screen.dart';
import 'package:myapp/features/admin/customers_admin_screen.dart';
import 'package:myapp/features/admin/products_admin_screen.dart';
import 'package:myapp/features/catalog/models.dart';

// UNVERIFIED: no Flutter SDK on this machine — verified via CI (gate at Task 4).

// TDD RED: this file was written BEFORE `products_admin_screen.dart`
// existed, so it failed with an import error (`no screen`). GREEN after
// Task 3 implements the screen + pure [ProductsAdminListView] below.

/// Fake `GET /admin/products` items (Task 1 shape): one active, one
/// inactive with a nested `category {slug, name}` include.
List<Product> _fakeProducts() => <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': 'Panjabi',
        'slug': 'panjabi',
        'priceBdt': 1250,
        'stock': 10,
        'imageUrl': null,
        'isActive': true,
        'category': {'slug': 'mens', 'name': "Men's"},
      },
      <String, dynamic>{
        'id': 2,
        'name': 'Kurti',
        'slug': 'kurti',
        'priceBdt': 850,
        'stock': 0,
        'imageUrl': null,
        'isActive': false,
        'category': {'slug': 'womens', 'name': "Women's"},
      },
    ].map(Product.fromJson).toList();

Widget _listFor(List<Product> items, {ValueChanged<Product>? onDelete}) {
  return MaterialApp(
    home: Scaffold(
      body: ProductsAdminListView(
        items: items,
        onDeleteConfirmed: onDelete ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('products list renders 2 fake products (1 inactive badge)',
      (tester) async {
    await tester.pumpWidget(_listFor(_fakeProducts()));
    await tester.pumpAndSettle();

    expect(find.text('Panjabi'), findsOneWidget);
    expect(find.text('Kurti'), findsOneWidget);
    // Inactive badge (bilingual) on the Kurti row only.
    expect(find.text('নিষ্ক্রিয় / Inactive'), findsOneWidget);
    expect(find.text('সক্রিয় / Active'), findsOneWidget);
  });

  testWidgets('delete button shows bilingual confirm dialog', (tester) async {
    Product? confirmed;
    await tester.pumpWidget(
      _listFor(_fakeProducts(), onDelete: (p) => confirmed = p),
    );
    await tester.pumpAndSettle();

    // Delete icon on the first row opens the confirm dialog.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    // Bilingual dialog copy present.
    expect(find.text('মুছবেন? / Delete?'), findsOneWidget);
    expect(find.textContaining('Cancel'), findsOneWidget);

    // Confirming forwards the tapped product to the caller.
    await tester.tap(find.text('মুছুন / Delete'));
    await tester.pumpAndSettle();
    expect(confirmed?.id, 1);
  });

  group('customers management (Task 4)', () {
    testWidgets('customers list renders 2 fake customers (1 suspended badge)',
        (tester) async {
      await tester.pumpWidget(_customersListFor(_fakeCustomers()));
      await tester.pumpAndSettle();

      expect(find.text('Rahim Uddin'), findsOneWidget);
      // Karim has no profile fullName, so the row falls back to the email
      // as the title AND shows the email line: 2 matching widgets.
      expect(find.text('karim@example.com'), findsNWidgets(2));
      // Suspended badge (red) on the suspended row only.
      expect(find.text('স্থগিত / Suspended'), findsOneWidget);
      expect(find.text('সক্রিয় / Active'), findsOneWidget);
    });

    testWidgets('suspend button shows bilingual confirm dialog', (tester) async {
      String? confirmed;
      await tester.pumpWidget(
        _customerDetailFor(
          _fakeCustomerDetail(status: 'active'),
          onStatus: (s) => confirmed = s,
        ),
      );
      await tester.pumpAndSettle();

      // Suspend button on the active customer's detail.
      await tester.tap(find.text('স্থগিত করুন / Suspend'));
      await tester.pumpAndSettle();

      // Bilingual dialog copy present.
      expect(find.text('স্থগিত করবেন? / Suspend?'), findsOneWidget);
      expect(find.textContaining('no longer be able to log in'), findsOneWidget);
      expect(find.text('বাতিল / Cancel'), findsOneWidget);

      // Confirming forwards 'suspended' to the caller.
      await tester.tap(find.text('স্থগিত / Suspend'));
      await tester.pumpAndSettle();
      expect(confirmed, 'suspended');
    });

    testWidgets('unsuspend button shows bilingual confirm dialog',
        (tester) async {
      String? confirmed;
      await tester.pumpWidget(
        _customerDetailFor(
          _fakeCustomerDetail(status: 'suspended'),
          onStatus: (s) => confirmed = s,
        ),
      );
      await tester.pumpAndSettle();

      // Suspended badge renders on the detail + unsuspend CTA.
      expect(find.text('স্থগিত / Suspended'), findsOneWidget);
      await tester.tap(find.text('সক্রিয় করুন / Unsuspend'));
      await tester.pumpAndSettle();

      expect(find.text('সক্রিয় করবেন? / Unsuspend?'), findsOneWidget);
      expect(
          find.textContaining('able to log in again'), findsOneWidget);

      await tester.tap(find.text('সক্রিয় / Unsuspend'));
      await tester.pumpAndSettle();
      expect(confirmed, 'active');
    });

    test('suspended login error maps to the bilingual support message', () {
      expect(
        loginErrorMessage('suspended'),
        'অ্যাকাউন্ট স্থগিত / Account suspended — support-এ যোগাযোগ করুন',
      );
      expect(loginErrorMessage('suspended'), suspendedAccountMessage);
      // Other codes pass through untouched.
      expect(loginErrorMessage('invalid credentials'), 'invalid credentials');
      expect(loginErrorMessage(null), '');
    });
  });
}

/// Fake `GET /admin/customers` items: one active, one suspended.
List<AdminCustomer> _fakeCustomers() => <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 3,
        'email': 'rahim@example.com',
        'role': 'customer',
        'status': 'active',
        'fullName': 'Rahim Uddin',
        'phone': '01700000001',
        'orderCount': 2,
        'totalSpent': 2500,
      },
      <String, dynamic>{
        'id': 4,
        'email': 'karim@example.com',
        'role': 'customer',
        'status': 'suspended',
        'fullName': null,
        'phone': null,
        'orderCount': 0,
        'totalSpent': 0,
      },
    ].map(AdminCustomer.fromJson).toList();

Widget _customersListFor(List<AdminCustomer> items) {
  return MaterialApp(
    home: Scaffold(
      body: CustomersAdminListView(items: items),
    ),
  );
}

/// Fake `GET /admin/customers/:id` detail with one order + payment
/// aggregates, matching the Task 2 backend shape.
AdminCustomerDetail _fakeCustomerDetail({String status = 'active'}) {
  return AdminCustomerDetail.fromJson(<String, dynamic>{
    'id': 3,
    'email': 'rahim@example.com',
    'role': 'customer',
    'status': status,
    'createdAt': '2026-10-01T00:00:00.000Z',
    'profile': <String, dynamic>{'fullName': 'Rahim Uddin', 'phone': '01700000001'},
    'addresses': const <Map<String, dynamic>>[],
    'orders': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 7,
        'total': 1500,
        'status': 'delivered',
        'createdAt': '2026-10-02T00:00:00.000Z',
        'payment': <String, dynamic>{'method': 'COD', 'status': 'paid'},
      },
    ],
    'payments': <String, dynamic>{
      'count': 1,
      'total': 1500,
      'paid': 1,
      'unpaid': 0,
      'paidTotal': 1500,
      'unpaidTotal': 0,
    },
    'orderCount': 1,
    'totalSpent': 1500,
  });
}

Widget _customerDetailFor(
  AdminCustomerDetail customer, {
  ValueChanged<String>? onStatus,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CustomerDetailView(
          customer: customer,
          onStatusConfirmed: onStatus,
        ),
      ),
    ),
  );
}
