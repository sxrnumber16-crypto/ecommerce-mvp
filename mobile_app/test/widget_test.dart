import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/config.dart';

void main() {
  test('api base defaults to Android-emulator host (UNVERIFIED: no SDK run)', () {
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
}
