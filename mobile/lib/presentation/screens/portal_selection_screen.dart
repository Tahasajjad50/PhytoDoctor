import 'package:flutter/material.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/native_platform_service.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/phyto_logo.dart';
import 'login_screen.dart';

class PortalSelectionScreen extends StatefulWidget {
  const PortalSelectionScreen({Key? key}) : super(key: key);

  @override
  State<PortalSelectionScreen> createState() => _PortalSelectionScreenState();
}

class _PortalSelectionScreenState extends State<PortalSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-prompt runtime permissions (Camera & Location) and check mandatory app updates on startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NativePlatformService.requestPermissions();
      if (mounted) {
        AppUpdateService.checkAndPromptUpdate(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // 1. Official Phyto Doctor Logo First
                  const Center(
                    child: PhytoDoctorLogo(
                      width: 290,
                      height: 78,
                      showTagline: true,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // 2. Two Clearly Separated, Prominent Buttons
                  // Button A: Employee Login
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(
                            portal: PortalType.employee,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.botanicalPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, AppTheme.standardButtonHeight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.badge, size: 20),
                        SizedBox(width: 10),
                        Text('Employee Login'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Button B: Admin Login
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(
                            portal: PortalType.admin,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.adminSlate,
                      side: const BorderSide(color: AppTheme.adminSlate, width: 1.6),
                      backgroundColor: AppTheme.surfaceCard,
                      minimumSize: const Size(double.infinity, AppTheme.standardButtonHeight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.admin_panel_settings, size: 20),
                        SizedBox(width: 10),
                        Text('Admin Login'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Security Footnote
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock_outline, size: 14, color: AppTheme.textMuted),
                      SizedBox(width: 6),
                      Text(
                        'Authorized Personnel Only • No Public Registration',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
