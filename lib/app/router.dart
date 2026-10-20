import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/adaptive_shell.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/books/book_detail_screen.dart';
import '../features/books/books_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/onboarding_store.dart';
import '../features/settings/settings_screen.dart';
import '../features/transactions/transactions_screen.dart';

/// Fade + gentle rise between pages; instant when the user prefers reduced motion.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondary, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

/// Router whose redirects follow the auth state: signed-out users see the sign-in screen,
/// signed-in (or sample-mode) users never do.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider.select((a) => a.status), (_, _) => refresh.value++);
  ref.listen(onboardingProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final a = ref.read(authProvider);
      final o = ref.read(onboardingProvider);
      final loc = state.matchedLocation;
      if (a.status == AuthStatus.unknown || (!a.isIn && !o.loaded)) {
        return loc == '/splash' ? null : '/splash';
      }
      // First launch: the intro comes before sign-in. Signed-in users can still replay it from Settings.
      if (!a.isIn) {
        final target = o.seen ? '/login' : '/welcome';
        return loc == target ? null : target;
      }
      if (loc == '/login' || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/welcome',
        pageBuilder: (_, s) => _page(s, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, s) => _page(s, const AuthScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdaptiveShell(
          index: shell.currentIndex,
          onSelect: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          child: shell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (_, s) => _page(s, const DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/books',
                pageBuilder: (_, s) => _page(s, const BooksScreen()),
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder: (_, s) => _page(
                      s,
                      BookDetailScreen(bookId: s.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                pageBuilder: (_, s) => _page(s, const TransactionsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                pageBuilder: (_, s) => _page(s, const InsightsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (_, s) => _page(s, const SettingsScreen()),
                routes: [
                  GoRoute(
                    path: 'categories',
                    pageBuilder: (_, s) => _page(s, const CategoriesScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
