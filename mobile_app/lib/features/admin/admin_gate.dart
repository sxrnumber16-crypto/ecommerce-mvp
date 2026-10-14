import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_store.dart';
import '../../design/tokens/app_space.dart';

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
/// Tokens-only reskin; shown under the exact same condition
/// (`AuthStore.role != 'admin'`).
class AdminDenied extends StatelessWidget {
  const AdminDenied({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('অ্যাডমিন / Admin')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 48,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'অনুমতি নেই / Admins only',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
