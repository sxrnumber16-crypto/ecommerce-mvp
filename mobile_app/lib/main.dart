import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/push_service.dart';

/// Bootstrap: push init runs BEFORE `runApp` (crash-safe — a missing/broken
/// native Firebase config logs and returns, app runs push-less), tap routing
/// goes through the shared router. The container is pre-created so the tap
/// callback can `go(route)` even for terminated-state launches; router/auth
/// init order inside [MyApp] is unchanged.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await initPush(
    onTap: (String route) async {
      container.read(routerProvider).go(route);
    },
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}
