import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_store.dart';

/// Role gate: shows [child] only when `AuthStore.role == 'admin'`
/// (populated from `GET /auth/me`; backend `requireAdmin` re-confirms).
/// Customers (and logged-out users) see [fallback] instead — the Admin
/// tab/route must never be reachable for them.
class AdminGate extends ConsumerWidget {
  final Widget child;
  final Widget fallback;

  const AdminGate({super.key, required this.child, required this.fallback});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStoreProvider);
    if (auth.isAdmin) return child;
    return fallback;
  }
}

/// Convenience: "not allowed" placeholder for gated admin routes.
class AdminDenied extends StatelessWidget {
  const AdminDenied({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('অ্যাডমিন / Admin')),
      body: const Center(
        child: Text('অনুমতি নেই / Admins only'),
      ),
    );
  }
}
