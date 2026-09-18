import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'copilot_sheet.dart';

/// Port of the web frontend's `Layout`: an editorial masthead (paper
/// background, serif wordmark, hairline rule), the page body, and the
/// always-available "Ask Volt" affordance. The web's horizontal nav becomes a
/// bottom navigation bar, which is where a phone user expects it.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    ('/', 'Dashboard', Icons.dashboard_outlined),
    ('/maintenance-plan', 'Maintenance', Icons.assignment_outlined),
  ];

  int _selectedIndex(String location) =>
      location.startsWith('/maintenance-plan') ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final isDetail = location.startsWith('/assets/');

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
            Text('OUTAGE PREDICTION & PLANNING', style: AppText.kicker(size: 9)),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: child,
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
          items: [
            for (final tab in _tabs)
              BottomNavigationBarItem(
                icon: Icon(tab.$3),
                label: tab.$2,
              ),
          ],
        ),
      ),
    );
  }
}
