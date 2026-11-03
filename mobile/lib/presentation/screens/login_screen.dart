import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/phyto_logo.dart';
import 'admin_dashboard_screen.dart';
import 'employee_dashboard_screen.dart';

enum PortalType { employee, admin }

class LoginScreen extends StatefulWidget {
  final PortalType portal;
  final AuthService? authService;

  const LoginScreen({
    Key? key,
    required this.portal,
    this.authService,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  late final AuthService _authService;

  bool get isAdminPortal => widget.portal == PortalType.admin;
  Color get themeColor => isAdminPortal ? AppTheme.adminSlate : AppTheme.botanicalPrimary;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    if (kDebugMode) {
      if (isAdminPortal) {
        _identifierController.text = 'MehmoodAyyaz';
        _passwordController.text = 'Admin@PhytoDoctor';
      }
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.login(
        usernameOrEmail: _identifierController.text.trim(),
        password: _passwordController.text,
        portal: isAdminPortal ? 'admin' : 'employee',
      );

      if (!mounted) return;

      if (isAdminPortal) {
        if (!user.isAdmin) {
          setState(() {
            _errorMessage = 'Access denied: Administrator privileges required.';
          });
          return;
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboardScreen(user: user),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => EmployeeDashboardScreen(user: user),
          ),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected connection error occurred. Please verify server status.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: Text(isAdminPortal ? 'Admin Login' : 'Employee Login'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // Compact Official Logo Header
                  const Center(
                    child: PhytoDoctorLogo(
                      width: 240,
                      height: 60,
                      showTagline: false,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Portal Identifier Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isAdminPortal ? AppTheme.adminSlateLight : AppTheme.sageLight,
                      borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                      border: Border.all(
                        color: isAdminPortal ? AppTheme.adminSlate.withOpacity(0.3) : AppTheme.sageBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAdminPortal ? Icons.admin_panel_settings : Icons.badge,
                          size: 18,
                          color: themeColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAdminPortal ? 'MANAGEMENT CONSOLE' : 'FIELD AGRONOMIST ACCESS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: themeColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.alertCrimsonLight,
                        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                        border: Border.all(color: AppTheme.alertCrimson, width: 1.0),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error, color: AppTheme.alertCrimson, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.alertCrimson,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Form Container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                      border: Border.all(color: AppTheme.sageBorder, width: 1.0),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Username or Email',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMain,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _identifierController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: isAdminPortal
                                  ? 'owner@phytodoctor.com'
                                  : 'emp.john or registered email',
                              prefixIcon: const Icon(Icons.person, color: AppTheme.textMuted, size: 20),
                            ),
                            validator: (val) =>
                                (val == null || val.trim().isEmpty) ? 'Please enter your username or email' : null,
                          ),

                          const SizedBox(height: 18),

                          const Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMain,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(Icons.lock, color: AppTheme.textMuted, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppTheme.textMuted,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (val) =>
                                (val == null || val.isEmpty) ? 'Please enter your password' : null,
                          ),

                          const SizedBox(height: 24),

                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: themeColor.withOpacity(0.6),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    isAdminPortal ? 'Sign In as Administrator' : 'Sign In as Field Officer',
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Center(
                    child: Text(
                      'Account issues? Contact your branch manager or IT admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
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
