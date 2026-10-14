import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';

/// Static first-run onboarding with a Skip path to `/login`.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const steps = <({IconData icon, String title, String sub})>[
      (
        icon: Icons.storefront_outlined,
        title: 'দেশি পণ্য, এক জায়গায়',
        sub: 'Local products in one shop',
      ),
      (
        icon: Icons.delivery_dining_outlined,
        title: 'ক্যাশ অন ডেলিভারি',
        sub: 'Cash on Delivery — pay at your door',
      ),
      (
        icon: Icons.receipt_long_outlined,
        title: 'সহজ অর্ডার ট্র্যাকিং',
        sub: 'Track every order from pending to delivered',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(Config.storeName),
        actions: [
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('স্কিপ / Skip'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            for (final s in steps) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(s.icon,
                    size: 40, color: theme.colorScheme.primary),
                title: Text(s.title,
                    style: theme.textTheme.titleMedium),
                subtitle: Text(s.sub),
              ),
              const SizedBox(height: 8),
            ],
            const Spacer(),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('শুরু করুন / Get started'),
            ),
            TextButton(
              onPressed: () => context.go('/register'),
              child:
                  const Text('নতুন অ্যাকাউন্ট / Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
