import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth_store.dart';
import 'core/config.dart';
import 'design/theme.dart';
import 'features/admin/admin_gate.dart';
import 'features/admin/admin_screen.dart';
import 'features/admin/orders_admin_screen.dart';
import 'features/admin/product_editor_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/cart/address_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/cart/cart_store.dart';
import 'features/cart/checkout_screen.dart';
import 'features/cart/confirmation_screen.dart';
import 'features/catalog/product_detail_screen.dart';
import 'features/catalog/search_screen.dart';
import 'features/diagnostics/network_diagnostics_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/orders/order_detail_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/splash/splash_screen.dart';

/// App router. Shell holds the bottom-nav tabs (5 customer tabs + an
/// Admin tab visible only when `role == admin`); `/admin` sub-routes
/// redirect to `/home` unless `role == admin`.
/// Sub-routes live inside the shell so the nav bar persists:
/// `/product/:id`, `/cart/address`, `/cart/checkout`, `/orders/:id`,
/// `/admin/products/new`, `/admin/products/:id/edit`, `/admin/orders`.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStoreProvider);
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.uri.toString();
      final loggedIn = auth.isAuthenticated;

      // Admin guard (hidden route).
      if (loc.startsWith('/admin') && !auth.isAdmin) return '/home';

      // Auth guard for tabbed area + admin.
      const authedPrefixes = <String>[
        '/home',
        '/search',
        '/product',
        '/cart',
        '/orders',
        '/profile',
        '/admin',
      ];
      final needsAuth =
          authedPrefixes.any((p) => loc == p || loc.startsWith('$p/'));
      if (needsAuth && !loggedIn) return '/login';

      // Logged-in users skip auth screens.
      if (loggedIn && (loc == '/login' || loc == '/register')) {
        return '/home';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/diagnostics',
        builder: (context, state) => const NetworkDiagnosticsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => SearchScreen(
              initialCategory: state.uri.queryParameters['category'],
            ),
          ),
          GoRoute(
            path: '/product/:id',
            builder: (context, state) => ProductDetailScreen(
              productId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'address',
                builder: (context, state) => const AddressScreen(),
              ),
              GoRoute(
                path: 'checkout',
                builder: (context, state) => CheckoutScreen(
                  addressId: int.tryParse(
                          state.uri.queryParameters['addressId'] ?? '') ??
                      0,
                ),
              ),
              GoRoute(
                path: 'confirmation/:orderId',
                builder: (context, state) => ConfirmationScreen(
                  orderId: int.tryParse(
                          state.pathParameters['orderId'] ?? '') ??
                      0,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (context, state) => OrderDetailScreen(
                  orderId:
                      int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminGate(
              fallback: AdminDenied(),
              child: AdminScreen(),
            ),
            routes: <RouteBase>[
              GoRoute(
                path: 'products/new',
                builder: (context, state) => const AdminGate(
                  fallback: AdminDenied(),
                  child: ProductEditorScreen(),
                ),
              ),
              GoRoute(
                path: 'products/:id/edit',
                builder: (context, state) => AdminGate(
                  fallback: const AdminDenied(),
                  child: ProductEditorScreen(
                    productId: int.tryParse(
                            state.pathParameters['id'] ?? '') ??
                        0,
                  ),
                ),
              ),
              GoRoute(
                path: 'orders',
                builder: (context, state) => const AdminGate(
                  fallback: AdminDenied(),
                  child: OrdersAdminScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: Config.storeName,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: router,
    );
  }
}

/// Bottom-nav shell. Cart tab badge reflects [cartCountProvider].
class ScaffoldWithNav extends ConsumerWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  static const _paths = <String>[
    '/home',
    '/search',
    '/cart',
    '/orders',
    '/profile',
  ];

  static const _adminPath = '/admin';

  List<String> _pathsFor(bool isAdmin) =>
      isAdmin ? [..._paths, _adminPath] : _paths;

  int _indexFor(String loc, int count) {
    // /product/* belongs to the Search tab visually; checkout flow + order
    // detail keep their parent tab highlighted via prefix match below.
    // /admin/* always highlights the Admin tab when present.
    if (loc == '/product' || loc.startsWith('/product/')) return 1;
    final paths = count > _paths.length ? [..._paths, _adminPath] : _paths;
    for (var i = 0; i < paths.length; i++) {
      if (loc == paths[i] || loc.startsWith('${paths[i]}/')) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).uri.toString();
    final isAdmin = ref.watch(authStoreProvider).isAdmin;
    final paths = _pathsFor(isAdmin);
    final index = _indexFor(loc, paths.length).clamp(0, paths.length - 1);
    final cartCount = ref.watch(cartCountProvider);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(paths[i]),
        destinations: <Widget>[
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search'),
          NavigationDestination(
              icon: Badge(
                label: Text('$cartCount'),
                isLabelVisible: cartCount > 0,
                child: const Icon(Icons.shopping_cart),
              ),
              label: 'Cart'),
          const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
          if (isAdmin)
            const NavigationDestination(
                icon: Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: Icon(Icons.admin_panel_settings),
                label: 'Admin'),
        ],
      ),
    );
  }
}
