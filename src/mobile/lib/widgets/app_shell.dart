import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/alert_poller.dart';
import '../state/auth_controller.dart';
import '../theme/app_theme.dart';
import 'copilot_sheet.dart';

/// Port of the web frontend's `Layout`: an editorial masthead (paper
/// background, serif wordmark, hairline rule), the page body, and the
/// always-available "Ask Volt" affordance. The web's horizontal nav becomes a
/// bottom navigation bar, which is where a phone user expects it.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _auth = AuthController.instance;
  final _poller = AlertPoller.instance;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onChanged);
    _poller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onChanged);
    _poller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Navigation is a function of role. An administrator manages the team and
  /// coverage; field crew get their inbox and their own patch. The server
  /// enforces this independently — these tabs are convenience, not security.
  List<(String, String, IconData)> get _tabs => _auth.isAdmin
      ? const [
          ('/', 'Dashboard', Icons.dashboard_outlined),
          ('/alerts', 'Alerts', Icons.notifications_outlined),
          ('/admin/users', 'Team', Icons.people_outline),
          ('/admin/assignments', 'Coverage', Icons.map_outlined),
        ]
      : const [
          ('/alerts', 'Alerts', Icons.notifications_outlined),
          ('/', 'Dashboard', Icons.dashboard_outlined),
          ('/maintenance-plan', 'Plan', Icons.assignment_outlined),
        ];

  int _selectedIndex(String location) {
    var best = 0;
    var bestLength = -1;
    for (var i = 0; i < _tabs.length; i++) {
      final path = _tabs[i].$1;
      final matches = path == '/' ? location == '/' : location.startsWith(path);
      if (matches && path.length > bestLength) {
        best = i;
        bestLength = path.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final isDetail = location.startsWith('/assets/');
    final session = _auth.session;

    return Scaffold(
      backgroundColor: AppColors.gray10,
      appBar: AppBar(
        toolbarHeight: 64,
        leading: isDetail
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.gray100),
                tooltip: 'Back to dashboard',
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Grid Failure Advisor',
              style: AppText.serif(
                size: 19,
                weight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              session == null
                  ? 'OUTAGE PREDICTION & PLANNING'
                  : '${session.companyName.toUpperCase()} · ${session.role.label.toUpperCase()}',
              style: AppText.kicker(size: 9),
            ),
          ],
        ),
        actions: [
          if (session != null)
            PopupMenuButton<String>(
              tooltip: 'Account',
              icon: const Icon(Icons.account_circle_outlined, color: AppColors.gray70),
              onSelected: (value) {
                if (value == 'signout') {
                  _poller.stop();
                  _auth.signOut();
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.fullName, style: AppText.serif(size: 15, weight: FontWeight.w600)),
                      Text(session.email, style: AppText.mono(size: 11, color: AppColors.gray60)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'signout',
                  child: Text('Sign out', style: AppText.sans(size: 14)),
                ),
              ],
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: widget.child,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCopilotSheet(context),
        backgroundColor: AppColors.blue60,
        foregroundColor: AppColors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.gray100),
        ),
        icon: const Icon(Icons.bolt, size: 18),
        label: Text(
          'Ask Volt',
          style: AppText.sans(
            size: 14,
            weight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.gray20)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex(location),
          onTap: (index) => context.go(_tabs[index].$1),
          type: BottomNavigationBarType.fixed,
          items: [
            for (final tab in _tabs)
              BottomNavigationBarItem(
                icon: tab.$1 == '/alerts' && _poller.openCount > 0
                    // The count is the whole point of the tab: an operator
                    // should know there is work without opening it.
                    ? Badge.count(count: _poller.openCount, child: Icon(tab.$3))
                    : Icon(tab.$3),
                label: tab.$2,
              ),
          ],
        ),
      ),
    );
  }
}
