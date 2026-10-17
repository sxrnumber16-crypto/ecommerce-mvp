import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_store.dart';
import '../../core/config.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';

/// Animated professional splash.
///
/// Visual only — data flow unchanged: restores the session then
/// `→ /home` if authenticated else `→ /onboarding`.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _taglineFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 1, curve: Curves.easeOut)),
    );
    _ctrl.forward();

    Future.microtask(() async {
      try {
        await ref.read(authStoreProvider.notifier).loadFromStorage();
      } catch (_) {}
      if (!mounted) return;
      // Let the animation be seen briefly even on fast devices.
      await Future<void>.delayed(const Duration(milliseconds: 650));
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.seed.withValues(alpha: 0.28),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.darkOutline.withValues(alpha: 0.9),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: Image.asset(
                            'assets/app_logo.png',
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.l),
                FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Text(
                      Config.storeName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppText.display(context).copyWith(
                        color: Colors.white,
                        letterSpacing: 5,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s),
                FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    'EVERYTHING. ONE PLACE.',
                    textAlign: TextAlign.center,
                    style: AppText.label(context).copyWith(
                      color: AppColors.darkMuted,
                      letterSpacing: 3.2,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                FadeTransition(
                  opacity: _taglineFade,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.seed),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.l),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
