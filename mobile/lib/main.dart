import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'core/models/user_model.dart';
import 'core/services/auth_service.dart';
import 'core/services/chat_notification_monitor.dart';
import 'core/services/notification_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/admin_dashboard_screen.dart';
import 'presentation/screens/employee_dashboard_screen.dart';
import 'presentation/screens/portal_selection_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize native Android system notification channel & permissions
  await NotificationService().initialize();

  final storage = SecureStorageService();
  final lastBuildNumber = await storage.getStoredBuildNumber();
  UserModel? savedUser;

  // Requirement: Reopen without asking credentials unless app was updated or reinstalled
  if (lastBuildNumber == null || lastBuildNumber != AppConfig.buildNumber) {
    // New version or fresh install -> require fresh authentication
    await storage.clearAll();
    savedUser = null;
  } else {
    // Normal reopen -> auto-reopen without credentials prompt
    savedUser = await storage.getUserSession();
    if (savedUser != null && savedUser.isActive) {
      AuthService.activeSessionUser = savedUser;
      ChatNotificationMonitor().start(savedUser);
    }
  }

  runApp(PhytoDoctorApp(initialUser: savedUser));
}

class PhytoDoctorApp extends StatefulWidget {
  final UserModel? initialUser;

  const PhytoDoctorApp({Key? key, this.initialUser}) : super(key: key);

  @override
  State<PhytoDoctorApp> createState() => _PhytoDoctorAppState();
}

class _PhytoDoctorAppState extends State<PhytoDoctorApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().checkInitialLaunchPayload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _resolveInitialScreen(),
    );
  }

  Widget _resolveInitialScreen() {
    if (widget.initialUser != null && widget.initialUser!.isActive) {
      if (widget.initialUser!.isAdmin) {
        return AdminDashboardScreen(user: widget.initialUser!);
      } else {
        return EmployeeDashboardScreen(user: widget.initialUser!);
      }
    }
    return const PortalSelectionScreen();
  }
}
