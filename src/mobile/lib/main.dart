import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_router.dart';
import 'services/notifications.dart';
import 'state/alert_poller.dart';
import 'state/auth_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Tapping a notification deep-links straight to the inbox. The router's own
  // redirect handles the case where the session expired while the app was
  // backgrounded — the tap lands on /login instead of an empty list.
  await NotificationService.instance.init(
    onAlertTapped: (_) => appRouter.go('/alerts'),
  );

  // Restore any stored session BEFORE the first frame, so a returning operator
  // is not shown the login screen for a moment on every cold start.
  await AuthController.instance.restore();
  if (AuthController.instance.isSignedIn) {
    AlertPoller.instance.start();
  }

  // Signing in later must also start polling; signing out must stop it.
  AuthController.instance.addListener(() {
    if (AuthController.instance.isSignedIn) {
      AlertPoller.instance.start();
    } else {
      AlertPoller.instance.stop();
    }
  });

  runApp(const GridAdvisorApp());
}

class GridAdvisorApp extends StatelessWidget {
  const GridAdvisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Grid Failure Advisor',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
