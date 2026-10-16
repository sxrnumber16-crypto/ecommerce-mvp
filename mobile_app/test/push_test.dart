import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/push_service.dart';

// Widget-safe unit test: exercises ONLY the pure tap mapper `routeForPush`.
// No Firebase/plugin calls here (none available in `flutter test`).
//
// NOTE: no Flutter SDK on the authoring machine — verified via CI (Task 4).
void main() {
  group('routeForPush', () {
    test('new_product with id routes to the product page', () {
      expect(
        routeForPush({'type': 'new_product', 'productId': '42'}),
        '/product/42',
      );
    });

    test('order_update with id routes to the order page', () {
      expect(
        routeForPush({'type': 'order_update', 'orderId': '7'}),
        '/orders/7',
      );
    });

    test('missing or empty ids return null', () {
      expect(routeForPush({'type': 'new_product'}), isNull);
      expect(routeForPush({'type': 'new_product', 'productId': ''}), isNull);
      expect(routeForPush({'type': 'order_update'}), isNull);
      expect(routeForPush({'type': 'order_update', 'orderId': ''}), isNull);
    });

    test('unknown or missing type returns null', () {
      expect(routeForPush({'type': 'something_else', 'productId': '1'}),
          isNull);
      expect(routeForPush({}), isNull);
      expect(routeForPush({'type': ''}), isNull);
    });

    test('extra payload fields do not affect routing', () {
      expect(
        routeForPush({
          'type': 'order_update',
          'orderId': '9',
          'status': 'confirmed',
        }),
        '/orders/9',
      );
    });
  });
}
