import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
