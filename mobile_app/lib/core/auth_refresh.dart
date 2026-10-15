import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_store.dart';

/// Listenable that pings [GoRouter] whenever auth state changes.
///
/// The router holds this as its `refreshListenable` so redirects
/// re-evaluate on auth flips WITHOUT recreating the `GoRouter` instance
/// (recreating it resets navigation back to `initialLocation: '/splash'`).
class AuthRefreshListenable extends ChangeNotifier {
  void ping() => notifyListeners();
}

final authRefreshProvider =
    ChangeNotifierProvider<AuthRefreshListenable>((ref) {
  final n = AuthRefreshListenable();
  ref.listen(authStoreProvider, (previous, next) => n.ping());
  return n;
});
