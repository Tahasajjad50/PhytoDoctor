import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'core/models/user_model.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/admin_dashboard_screen.dart';
import 'presentation/screens/employee_dashboard_screen.dart';
import 'presentation/screens/portal_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  }

  runApp(PhytoDoctorApp(initialUser: savedUser));
}

class PhytoDoctorApp extends StatelessWidget {
  final UserModel? initialUser;

  const PhytoDoctorApp({Key? key, this.initialUser}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _resolveInitialScreen(),
    );
  }

  Widget _resolveInitialScreen() {
    if (initialUser != null && initialUser!.isActive) {
      if (initialUser!.isAdmin) {
        return AdminDashboardScreen(user: initialUser!);
      } else {
        return EmployeeDashboardScreen(user: initialUser!);
      }
    }
    return const PortalSelectionScreen();
  }
}
