/// Core app configuration.
///
/// [apiBaseUrl] is overridden at build/run time with:
/// `--dart-define=API_BASE_URL=<url>` (see mobile_app/README.md).
/// [storeName] is overridden with `--dart-define=STORE_NAME=<name>`.
class Config {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const storeName = String.fromEnvironment(
    'STORE_NAME',
    defaultValue: 'Orvix Shop',
  );

  /// Bengali-safe Taka formatter: always uses ASCII digits + thousands
  /// commas so `৳` renders without relying on `intl` locale data.
  ///
  /// Example: `Config.bdt(1234567)` -> `৳1,234,567`.
  static String bdt(int v) {
    final negative = v < 0;
    final digits = v.abs().toString();
    final buffer = StringBuffer();
    final len = digits.length;
    for (var i = 0; i < len; i++) {
      if (i != 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return '${negative ? '-' : ''}৳$buffer';
  }
}
