import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app.dart';
import 'package:myapp/core/api_client.dart';
import 'package:myapp/core/auth_refresh.dart';
import 'package:myapp/core/auth_store.dart';
import 'package:myapp/features/auth/login_screen.dart';
import 'package:myapp/features/catalog/catalog_api.dart';
import 'package:myapp/features/catalog/models.dart';
import 'package:myapp/features/home/home_screen.dart';
import 'package:myapp/features/onboarding/onboarding_screen.dart';

// Regression test for: "login flips auth state 3-4 times -> router
// recreated -> bounced back to /splash each time (frozen spinner)".
//
// The router must be a STABLE instance (refreshListenable, not rebuilds)
// so auth flips only re-evaluate `redirect` instead of resetting
// navigation to `initialLocation: '/splash'`.
//
// NOTE: no Flutter SDK on the authoring machine — verified via CI.

/// [AuthStore] seeded to a fixed state without touching secure storage.
class _SeededAuthStore extends AuthStore {
  _SeededAuthStore(super.api, AuthState seed) {
    state = seed;
  }

  @override
  Future<void> loadFromStorage() async {
    // No-op in tests: FlutterSecureStorage has no plugin here (on CI the
    // real call stalls), so async session restore would hang splash.
    // The seeded [state] IS the fixture: it is exactly what an empty
    // (logged-out) or restored (logged-in) storage load would produce.
  }
}

/// [CatalogApi] that returns empty payloads instantly (no network — the
/// real [HomeScreen] fetches categories + featured products on init).
class _FakeCatalogApi extends CatalogApi {
  _FakeCatalogApi() : super(Dio());

  @override
  Future<List<Category>> categories() async => const [];

  @override
  Future<PagedProducts> products({
    String? search,
    String? category,
    int page = 1,
    int limit = 12,
  }) async =>
      PagedProducts(items: const [], page: page, limit: limit, total: 0);
}

const _loggedOut = AuthState();

const _loggedIn = AuthState(
  accessToken: 'test-access',
  refreshToken: 'test-refresh',
  role: 'customer',
);

/// Bounded pump helper: advances fake time so microtasks, futures and
/// GoRouter redirects flush WITHOUT waiting for perpetual animations
/// (splash spinner, carousel autoplay) to stop — `pumpAndSettle` never
/// converges while those are on screen.
Future<void> _pumpFrames(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, [
  int maxFrames = 30,
]) async {
  for (var i = 0; i < maxFrames && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps the REAL app router inside a controllable container.
/// Returns the container so tests can flip auth state mid-test.
Future<ProviderContainer> _pumpRealRouter(
  WidgetTester tester, {
  required AuthState seed,
}) async {
  final container = ProviderContainer(
    overrides: [
      authStoreProvider.overrideWith(
        (ref) => _SeededAuthStore(ref.watch(apiClientProvider), seed),
      ),
      catalogApiProvider.overrideWithValue(_FakeCatalogApi()),
    ],
  );
  addTearDown(container.dispose);

  // Realistic portrait-phone surface: the default 800x600 test viewport is
  // squatter than any phone, which makes full screens (e.g. onboarding's
  // Column) RenderFlex-overflow and fail the test on a rendering error
  // that never occurs on device.
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          final router = ref.watch(routerProvider);
          return MaterialApp.router(routerConfig: router);
        },
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets(
      'logged-out at /splash leaves splash for onboarding/login '
      '(not stuck on /splash)', (tester) async {
    final container = await _pumpRealRouter(tester, seed: _loggedOut);
    await _waitFor(tester, find.byType(OnboardingScreen));
    await _pumpFrames(tester, 5); // let the push transition finish

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(
      find.textContaining('Get started'),
      findsOneWidget,
      reason: 'onboarding CTA visible after splash session restore',
    );

    // Auth guard still enforced: guarded route redirects to /login.
    container.read(routerProvider).go('/home');
    await _pumpFrames(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
      'logged-in go("/home") stays on home (BottomNav visible), '
      'router instance stable across auth flips', (tester) async {
    final container = await _pumpRealRouter(tester, seed: _loggedIn);
    await _waitFor(tester, find.byType(HomeScreen));
    await _pumpFrames(tester, 5); // let the push transition finish

    final router = container.read(routerProvider);

    // Splash restores the seeded session and moves to /home.
    router.go('/home');
    await _pumpFrames(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Simulate login's 3-4 rapid auth state flips: router must be the
    // IDENTICAL instance afterwards and navigation must NOT bounce to
    // /splash (the reported bug).
    final notifier = container.read(authStoreProvider.notifier);
    notifier.state = notifier.state.copyWith(isLoading: true);
    await tester.pump();
    notifier.state = notifier.state.copyWith(isLoading: false);
    await tester.pump();
    notifier.state = const AuthState(
      accessToken: 'test-access-2',
      refreshToken: 'test-refresh-2',
      role: 'customer',
    );
    await _pumpFrames(tester);

    expect(
      identical(container.read(routerProvider), router),
      isTrue,
      reason: 'GoRouter instance must survive auth state flips',
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Logged-in users skip auth screens.
    router.go('/login');
    await _pumpFrames(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  test('AuthRefreshListenable pings listeners', () {
    final n = AuthRefreshListenable();
    var calls = 0;
    n.addListener(() => calls++);
    n.ping();
    expect(calls, 1);
    n.dispose();
  });

  test('routerProvider returns a stable instance per container', () {
    final container = ProviderContainer(
      overrides: [
        catalogApiProvider.overrideWithValue(_FakeCatalogApi()),
      ],
    );
    addTearDown(container.dispose);

    final first = container.read(routerProvider);
    // Flip auth state several times, as login does.
    final notifier = container.read(authStoreProvider.notifier);
    notifier.state = const AuthState(accessToken: 'a');
    notifier.state = notifier.state.copyWith(isLoading: true);
    notifier.state = notifier.state.copyWith(isLoading: false);
    notifier.state = const AuthState(accessToken: 'b', role: 'customer');

    expect(identical(container.read(routerProvider), first), isTrue);
  });
}
