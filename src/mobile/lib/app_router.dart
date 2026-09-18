import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/asset_detail_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/maintenance_plan_page.dart';
import 'widgets/app_shell.dart';

/// Same route shapes as the web app's `App.tsx`, so a deep link works the
/// same way on both clients.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => const _RedirectHome(),
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              _fadeThrough(state, const DashboardPage()),
        ),
        GoRoute(
          path: '/assets/:id',
          pageBuilder: (context, state) => _fadeThrough(
            state,
            AssetDetailPage(assetId: state.pathParameters['id'] ?? ''),
          ),
        ),
        GoRoute(
          path: '/maintenance-plan',
          pageBuilder: (context, state) =>
              _fadeThrough(state, const MaintenancePlanPage()),
        ),
      ],
    ),
  ],
);

/// The web's `.page-transition` keyframe — a short fade + rise on every
/// route change.
CustomTransitionPage<void> _fadeThrough(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Mirrors the web's catch-all `<Route path="*" element={<Navigate to="/" />} />`.
class _RedirectHome extends StatefulWidget {
  const _RedirectHome();

  @override
  State<_RedirectHome> createState() => _RedirectHomeState();
}

class _RedirectHomeState extends State<_RedirectHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
