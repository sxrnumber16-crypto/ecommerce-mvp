import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../design/components/app_button.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';

/// Professional minimal onboarding.
///
/// Data flow unchanged: Skip / Get started `→ /login`, Create account `→ /register`.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  static const _pages = <({IconData icon, String title, String sub})>[
    (
      icon: Icons.storefront_outlined,
      title: 'দেশি পণ্য, এক জায়গায়',
      sub: 'Local products in one shop — curated, authentic, fast.',
    ),
    (
      icon: Icons.delivery_dining_outlined,
      title: 'ক্যাশ অন ডেলিভারি',
      sub: 'Cash on Delivery — pay at your door, no hassle.',
    ),
    (
      icon: Icons.receipt_long_outlined,
      title: 'সহজ অর্ডার ট্র্যাকিং',
      sub: 'Track every order from pending to delivered.',
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _page.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, AppSpace.s, AppSpace.s, 0),
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'স্কিপ / Skip',
                    style: AppText.label(context).copyWith(color: AppColors.darkMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpace.l),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.m),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.darkOutline.withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.seed.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: AppColors.seed),
                  ),
                  const SizedBox(width: AppSpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Config.storeName.toUpperCase(),
                          style: AppText.title(context).copyWith(
                            color: Colors.white,
                            letterSpacing: 2.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'EVERYTHING. ONE PLACE.',
                          style: AppText.label(context).copyWith(
                            color: AppColors.darkMuted,
                            letterSpacing: 1.6,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.m),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: AppColors.seed.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.darkOutline.withValues(alpha: 0.5)),
                          ),
                          child: Icon(p.icon, size: 44, color: AppColors.seed),
                        ),
                        const SizedBox(height: AppSpace.l),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: AppText.headline(context).copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: AppSpace.s),
                        Text(
                          p.sub,
                          textAlign: TextAlign.center,
                          style: AppText.body(context).copyWith(color: AppColors.darkMuted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  Container(
                    width: i == _index ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: i == _index ? AppColors.seed : AppColors.darkOutline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.l),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: _index == _pages.length - 1 ? 'শুরু করুন / Get started' : 'পরবর্তী / Next',
                    onPressed: _next,
                  ),
                  const SizedBox(height: AppSpace.s),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('নতুন অ্যাকাউন্ট / Create account'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
