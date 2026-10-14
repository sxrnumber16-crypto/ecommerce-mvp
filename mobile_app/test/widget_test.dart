import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/config.dart';
import 'package:myapp/design/components/product_card.dart' as design_card;
import 'package:myapp/features/catalog/models.dart';
import 'package:myapp/shared/widgets/product_card.dart';

void main() {
  test('api base defaults to Android-emulator host', () {
    expect(Config.apiBaseUrl, 'http://10.0.2.2:3000');
    expect('${Config.apiBaseUrl}/api/v1', 'http://10.0.2.2:3000/api/v1');
  });

  test('bdt formats thousands with Taka sign', () {
    expect(Config.bdt(0), '৳0');
    expect(Config.bdt(500), '৳500');
    expect(Config.bdt(1234567), '৳1,234,567');
    expect(Config.bdt(-42000), '-৳42,000');
    expect(Config.storeName, isNotEmpty);
  });

  testWidgets('ProductCard shows BDT price and stock badge', (tester) async {
    const product = Product(
      id: 1,
      categoryId: 2,
      name: 'Test Saree',
      slug: 'test-saree',
      description: '',
      priceBdt: 1234,
      stock: 3,
      imageUrl: null,
      isActive: true,
      categorySlug: 'fashion',
      categoryName: 'Fashion',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProductCard(product: product)),
      ),
    );
    expect(find.text('Test Saree'), findsOneWidget);
    expect(find.text(Config.bdt(1234)), findsOneWidget);
    expect(find.textContaining('Low'), findsOneWidget);
  });

  testWidgets('ProductCard v2 shows BDT price and wishlist heart',
      (tester) async {
    const product = Product(
      id: 7,
      categoryId: 2,
      name: 'Test Panjabi',
      slug: 'test-panjabi',
      description: '',
      priceBdt: 2599,
      stock: 12,
      imageUrl: '',
      isActive: true,
      categorySlug: 'fashion',
      categoryName: 'Fashion',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          // Constrain to a grid-cell width like real usage; an
          // unconstrained full-screen width would overflow vertically
          // because of the square image.
          body: Center(
            child: SizedBox(
              width: 200,
              child: design_card.ProductCard(product: product, wished: true),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Test Panjabi'), findsOneWidget);
    expect(find.text(Config.bdt(2599)), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });
}
