import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_card.dart';
import '../../design/components/app_scaffold.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';

/// Static first-run onboarding with a Skip path to `/login`.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
    return AppScaffold(
      title: Config.storeName,
      actions: [
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('স্কিপ / Skip'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.xl),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navyCard, AppColors.seed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 40,
                  color: scheme.onPrimary,
                ),
                const SizedBox(height: AppSpace.m),
                Text(
                  'স্বাগতম / Welcome',
                  style: AppText.headline(context).copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: AppSpace.s),
                Text(
                  'Shop local, pay on delivery',
                  style: AppText.body(context).copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.l),
          for (final s in steps) ...[
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.m),
                child: Row(
                  children: [
                    Icon(s.icon, size: 40, color: scheme.primary),
                    const SizedBox(width: AppSpace.l),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title, style: AppText.title(context)),
                          const SizedBox(height: AppSpace.s),
                          Text(s.sub, style: AppText.body(context)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.m),
          ],
          const Spacer(),
          AppButton(
            label: 'শুরু করুন / Get started',
            onPressed: () => context.go('/login'),
          ),
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text('নতুন অ্যাকাউন্ট / Create account'),
          ),
        ],
      ),
    );
  }
}
