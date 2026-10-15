import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_store.dart';
import '../../core/config.dart';
import '../../design/components/app_scaffold.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';

/// Splash: restores the session, then `→ /home` if authenticated,
/// else `→ /onboarding`.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(authStoreProvider.notifier).loadFromStorage();
      } catch (_) {}
      if (!mounted) return;
      final auth = ref.read(authStoreProvider);
      if (auth.isAuthenticated) {
        context.go('/home');
      } else {
        context.go('/onboarding');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppRadius.card),
                    child: Image.asset(
                      'assets/app_logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: AppSpace.m),
                  Text(
                    Config.storeName,
                    style: AppText.display(context).copyWith(
                      color: scheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
