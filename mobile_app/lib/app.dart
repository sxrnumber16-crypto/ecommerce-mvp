import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth_store.dart';
import 'core/config.dart';

/// App router. Shell holds the 5 bottom-nav tabs; `/admin` stays hidden
/// from the bar and redirects to `/home` unless `role == admin`.
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
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
    ],
  );
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final light = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    );
    final dark = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    );
    return MaterialApp.router(
      title: Config.storeName,
      theme: light,
      darkTheme: dark,
      routerConfig: router,
    );
  }
}

/// Bottom-nav shell. Cart tab shows a badge (count wired in later tasks).
class ScaffoldWithNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  static const _paths = <String>[
    '/home',
    '/search',
    '/cart',
    '/orders',
    '/profile',
  ];

  int _indexFor(String loc) {
    for (var i = 0; i < _paths.length; i++) {
      if (loc == _paths[i] || loc.startsWith('${_paths[i]}/')) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final index = _indexFor(loc);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_paths[i]),
        destinations: const <Widget>[
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search'),
          NavigationDestination(
              icon: Badge(label: Text('0'), child: Icon(Icons.shopping_cart)),
              label: 'Cart'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}

// --- Placeholder screens (real UI lands in later tasks) ---

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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Config.storeName, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Config.storeName)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welcome — onboarding lands in a later task.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Get started'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Login form lands in a later task.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Continue (placeholder)'),
            ),
            TextButton(
              onPressed: () => context.go('/register'),
              child: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Register form lands in a later task.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Continue (placeholder)'),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Have an account? Log in'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Config.storeName)),
      body: const Center(child: Text('Home catalog lands in a later task.')),
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: const Center(child: Text('Search lands in a later task.')),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: const Center(child: Text('Cart lands in a later task.')),
    );
  }
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: const Center(child: Text('Orders land in a later task.')),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStoreProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Role: ${auth.role ?? 'unknown'}'),
            const SizedBox(height: 12),
            if (auth.isAdmin)
              FilledButton.tonal(
                onPressed: () => context.go('/admin'),
                child: const Text('Admin'),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await ref.read(authStoreProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: const Center(child: Text('Admin panel lands in a later task.')),
    );
  }
}
