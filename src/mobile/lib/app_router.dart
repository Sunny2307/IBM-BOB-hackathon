import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/admin_assignments_page.dart';
import 'pages/admin_send_alert_page.dart';
import 'pages/admin_users_page.dart';
import 'pages/alerts_page.dart';
import 'pages/asset_detail_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/login_page.dart';
import 'pages/maintenance_plan_page.dart';
import 'state/auth_controller.dart';
import 'widgets/app_shell.dart';

/// Same route shapes as the web app's `App.tsx`, so a deep link works the
/// same way on both clients.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => const _RedirectHome(),
  // Re-evaluates every redirect when the session changes, so signing in or out
  // moves the user immediately instead of leaving a stale screen behind.
  refreshListenable: AuthController.instance,
  redirect: (context, state) {
    final auth = AuthController.instance;
    final path = state.uri.path;

    // Hold still until the stored session has been read back, or a returning
    // user gets a flash of the login screen on every cold start.
    if (auth.isRestoring) return null;

    if (!auth.isSignedIn) {
      // The dashboard, asset detail and maintenance plan stay PUBLIC — the
      // deployed web demo works without an account and the mobile app should
      // match. Only the operator surface requires signing in.
      const operatorPaths = ['/alerts', '/admin'];
      final needsAuth = operatorPaths.any(path.startsWith);
      return needsAuth ? '/login' : null;
    }

    // Signed in: no reason to sit on the login screen.
    if (path == '/login') return auth.isAdmin ? '/' : '/alerts';

    // Role guard. Enforced on the server too — this only avoids showing a
    // field user a screen that would 403 anyway.
    if (path.startsWith('/admin') && !auth.isAdmin) return '/alerts';

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _fadeThrough(state, const LoginPage()),
    ),
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
        GoRoute(
          path: '/alerts',
          pageBuilder: (context, state) =>
              _fadeThrough(state, const AlertsPage()),
        ),
        GoRoute(
          path: '/admin/users',
          pageBuilder: (context, state) =>
              _fadeThrough(state, const AdminUsersPage()),
        ),
        GoRoute(
          path: '/admin/send-alert',
          pageBuilder: (context, state) =>
              _fadeThrough(state, const AdminSendAlertPage()),
        ),
        GoRoute(
          path: '/admin/assignments',
          pageBuilder: (context, state) =>
              _fadeThrough(state, const AdminAssignmentsPage()),
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
