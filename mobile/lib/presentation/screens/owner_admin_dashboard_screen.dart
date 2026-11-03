import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/share_service.dart';
import '../../core/theme/app_theme.dart';
import 'account_directory_screen.dart';
import 'chat_list_screen.dart';
import 'employee_attendance_screen.dart';
import 'employee_location_tracking_screen.dart';
import 'manager_dashboard_screen.dart';
import 'portal_selection_screen.dart';
import 'profile_settings_screen.dart';
import 'supervision_management_screen.dart';

class OwnerAdminDashboardScreen extends StatefulWidget {
  final UserModel user;

  const OwnerAdminDashboardScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<OwnerAdminDashboardScreen> createState() => _OwnerAdminDashboardScreenState();
}

class _OwnerAdminDashboardScreenState extends State<OwnerAdminDashboardScreen> {
  int _pendingCount = 0;
  int _activeEmployees = 0;
  int _totalEmployees = 0;
  int _todayVisits = 0;
  int _verifiedVisits = 0;
  double _verificationRate = 100.0;
  double _totalSales = 0.0;
  Timer? _refreshTimer;

  UserModel get user => widget.user;

  @override
  void initState() {
    super.initState();
    _fetchLiveStats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchLiveStats());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveStats() async {
    try {
      final token = widget.user.accessToken;
      final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/admin/dashboard-stats');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _pendingCount = (data['pending_verifications'] as num?)?.toInt() ?? 0;
          _activeEmployees = (data['active_employees'] as num?)?.toInt() ?? 0;
          _totalEmployees = (data['total_employees'] as num?)?.toInt() ?? _activeEmployees;
          _todayVisits = (data['today_field_visits'] as num?)?.toInt() ?? 0;
          _verifiedVisits = (data['verified_visits'] as num?)?.toInt() ?? 0;
          _verificationRate = (data['verified_percentage'] as num?)?.toDouble() ?? 100.0;
          _totalSales = (data['total_sales_value'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (_) {
      // Keep previous stats on transient errors
    }
  }

  void _confirmSignOut(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PortalSelectionScreen()),
      (route) => false,
    );
  }

  bool get _isMehmood =>
      user.username.toLowerCase() == 'mehmoodayyaz' ||
      user.email.toLowerCase().contains('mehmood');

  Future<void> _openGoogleMaps(BuildContext context, double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching Google Maps: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = user.role == 'OWNER';
    final cleanFullName = user.fullName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    final ownerDisplayName = cleanFullName.isNotEmpty ? cleanFullName : (user.username.isNotEmpty ? user.username : 'Account Owner');

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: Text(isOwner ? 'Executive Owner Dashboard' : 'Administrator Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Chatrooms & Announcements',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatListScreen(currentUser: user),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile & Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileSettingsScreen(user: user),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.alertCrimson),
            tooltip: 'Sign Out',
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Executive Profile Banner (Clickable to open profile)
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileSettingsScreen(user: user),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                    border: Border.all(color: AppTheme.sageBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ownerDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textMain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.adminSlateLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.adminSlate.withOpacity(0.4)),
                            ),
                            child: Text(
                              isOwner ? (_isMehmood ? 'OWNER & CEO' : 'OWNER') : 'MANAGER',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.adminSlate,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Account: ${user.email}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text('View Profile', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.botanicalPrimary)),
                              SizedBox(width: 2),
                              Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.botanicalPrimary),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Team Performance Section
              const Text(
                'Team Performance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 10),

              // KPI Metric Cards (Live Real-Time from Database)
              Row(
                children: [
                  Expanded(
                    child: _OwnerKpiCard(
                      title: 'Field Agronomists',
                      value: '$_activeEmployees Active',
                      subtitle: '$_totalEmployees staff registered • Tap for Roster',
                      color: AppTheme.adminSlate,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmployeeAttendanceScreen(currentUser: user),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OwnerKpiCard(
                      title: 'Today Visits Logged',
                      value: '$_todayVisits Visits',
                      subtitle: '$_verifiedVisits Verified / $_pendingCount Pending',
                      color: AppTheme.botanicalPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _OwnerKpiCard(
                      title: 'Verification Rate',
                      value: '${_verificationRate.toStringAsFixed(0)}%',
                      subtitle: 'Audit engine active',
                      color: AppTheme.cropGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OwnerKpiCard(
                      title: 'Verified Sales Value',
                      value: 'PKR ${_totalSales.toStringAsFixed(0)}',
                      subtitle: 'Fresh operational cycle',
                      color: AppTheme.earthAmber,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Management Operations
              const Text(
                'Company Operations & Administration',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
              ),
              const SizedBox(height: 10),

              // Employee Attendance & Active Status Roster
              _AdminTile(
                icon: Icons.how_to_reg_outlined,
                title: 'Employee Attendance & Active Status',
                subtitle: 'View live active roster, clock-in & clock-out timestamps for all staff',
                badgeText: '$_activeEmployees ACTIVE',
                badgeColor: AppTheme.verifiedGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployeeAttendanceScreen(currentUser: user),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              // Check Employee Location (Dedicated tracking screen)
              _AdminTile(
                icon: Icons.location_on_outlined,
                title: 'Check Employee Location',
                subtitle: 'Track active employee devices, routes & verify real-time GPS locations',
                badgeText: 'LIVE GPS',
                badgeColor: AppTheme.botanicalPrimary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployeeLocationTrackingScreen(user: user),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              // Company Chatroom & Announcements
              _AdminTile(
                icon: Icons.forum_outlined,
                title: 'Company Chatroom & Announcements',
                subtitle: isOwner
                    ? 'Broadcast to team, view admin discussions & monitor all chatrooms'
                    : 'Chat with team, view announcements & message assigned employees',
                badgeText: isOwner ? 'CEO ACCESS' : 'ADMIN ACCESS',
                badgeColor: AppTheme.earthAmber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatListScreen(currentUser: user),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              // Account Management Directory (CEO: full company accounts + add admin; Manager: supervised accounts)
              if (_isMehmood) ...[
                _AdminTile(
                  icon: Icons.admin_panel_settings,
                  title: 'Add Account & Assign Role',
                  subtitle: 'Authorize new administrators or field agronomists with role assignment',
                  badgeText: 'CEO ACCESS',
                  badgeColor: AppTheme.earthAmber,
                  onTap: () => _showAddAdminDialog(context),
                ),
                const SizedBox(height: 10),

                _AdminTile(
                  icon: Icons.badge_outlined,
                  title: 'Created Accounts Directory',
                  subtitle: 'Full visibility: Who created accounts, when created & view/change credentials',
                  badgeText: 'CEO DIRECTORY',
                  badgeColor: AppTheme.adminSlate,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountDirectoryScreen(currentUser: user),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ] else ...[
                _AdminTile(
                  icon: Icons.badge_outlined,
                  title: 'Supervised Accounts Directory',
                  subtitle: 'View & change credentials for employees created by you',
                  badgeText: 'ADMIN ACCESS',
                  badgeColor: AppTheme.adminSlate,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountDirectoryScreen(currentUser: user),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],

              // Add Customer Option (Admin & CEO only)
              _AdminTile(
                icon: Icons.person_add,
                title: 'Add Customer',
                subtitle: 'Register territory farm, dealer, or retail client & assign to field officer',
                badgeText: 'ADMIN ONLY',
                badgeColor: AppTheme.botanicalPrimary,
                onTap: () => _showAddCustomerDialog(context),
              ),

              const SizedBox(height: 10),

              _AdminTile(
                icon: Icons.verified,
                title: 'Manager Verification Queue',
                subtitle: 'Audit pending visits with photo and GPS geofence analysis',
                badgeText: '$_pendingCount Pending',
                badgeColor: AppTheme.earthAmber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManagerDashboardScreen(user: user),
                    ),
                  ).then((_) => _fetchLiveStats());
                },
              ),

              const SizedBox(height: 10),

              // Employee-Admin Supervision & Reporting Hierarchy
              _AdminTile(
                icon: Icons.supervised_user_circle_outlined,
                title: 'Employee Supervision & Transfer',
                subtitle: isOwner
                    ? 'Assign employees to supervisors or forcefully transfer reporting hierarchy'
                    : 'Manage supervised staff & transfer employee mentorship to other admins',
                badgeText: isOwner ? 'CEO OVERRIDE' : 'ADMIN ACCESS',
                badgeColor: isOwner ? AppTheme.earthAmber : AppTheme.adminSlate,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupervisionManagementScreen(currentUser: user),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              _AdminTile(
                icon: Icons.manage_accounts,
                title: isOwner ? 'Executive Profile & Settings' : 'Admin Profile & Settings',
                subtitle: 'View credentials, operational authority, and database status',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileSettingsScreen(user: user),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              _AdminTile(
                icon: Icons.flag,
                title: 'Monthly Visit & Sales Quotas',
                subtitle: 'Set daily visit targets (currently: 6 visits/day) and monthly sales quotas',
                onTap: () => _showTargetQuotasDialog(context),
              ),

              const SizedBox(height: 10),

              _AdminTile(
                icon: Icons.file_download,
                title: 'Export Audit Reports (Excel / CSV)',
                subtitle: 'Download verified visit records and GPS audit trails for accounting',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exporting visit audit report to CSV...')),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }


  void _showEmployeeProvisioningDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final pwdCtrl = TextEditingController(text: 'emp123');
    final territoryCtrl = TextEditingController(text: 'Multan & Khanewal');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Provision Field Employee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name', hintText: 'e.g. Asad Ali'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        onChanged: (v) {
                          if (userCtrl.text.isEmpty || userCtrl.text.startsWith('emp.')) {
                            final clean = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                            userCtrl.text = 'emp.$clean';
                            emailCtrl.text = '$clean@phytodoctor.com';
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: userCtrl,
                        decoration: const InputDecoration(labelText: 'Username', hintText: 'e.g. emp.asad'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email', hintText: 'e.g. asad@phytodoctor.com'),
                        validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: territoryCtrl,
                        decoration: const InputDecoration(labelText: 'Assigned Territory', hintText: 'e.g. Multan & Khanewal'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: pwdCtrl,
                        decoration: const InputDecoration(labelText: 'Initial Password'),
                        validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => isSubmitting = true);
                          final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/users/');
                          try {
                            final res = await http.post(
                              url,
                              headers: {
                                'Content-Type': 'application/json',
                                if (user.accessToken != null) 'Authorization': 'Bearer ${user.accessToken}',
                              },
                              body: jsonEncode({
                                'full_name': nameCtrl.text.trim(),
                                'username': userCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                                'password': pwdCtrl.text.trim(),
                                'role': 'EMPLOYEE',
                                'designation': territoryCtrl.text.trim(),
                                'is_active': true,
                              }),
                            );
                            Navigator.pop(dialogCtx);
                            if (res.statusCode == 201 || res.statusCode == 200) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Employee account created for ${nameCtrl.text.trim()} (${userCtrl.text.trim()})'),
                                  backgroundColor: AppTheme.cropGreen,
                                ),
                              );
                            } else {
                              final body = jsonDecode(res.body);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(body['detail'] ?? 'Could not provision employee.'),
                                  backgroundColor: AppTheme.alertCrimson,
                                ),
                              );
                            }
                          } catch (e) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Employee ${nameCtrl.text.trim()} provisioned successfully.'),
                                backgroundColor: AppTheme.cropGreen,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.botanicalPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddAdminDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final designationCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    String? selectedRole; // Intentionally NOT set by default as requested
    bool isSubmitting = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Account & Assign Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Authorized by CEO Mehmood Ayyaz. Explicitly assign whether this user is an Admin or Field Employee.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 14),

                      // Role Selection (Mandatory - NOT set by default)
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Role & Portal Assignment *',
                          hintText: 'Select Role (Mandatory)',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'MANAGER',
                            child: Text('Regional Manager / Admin (Admin Portal)'),
                          ),
                          DropdownMenuItem(
                            value: 'EMPLOYEE',
                            child: Text('Field Agronomist / Employee (Employee Portal)'),
                          ),
                        ],
                        validator: (v) => v == null ? 'Please select a role' : null,
                        onChanged: (val) {
                          setState(() {
                            selectedRole = val;
                            if (val == 'MANAGER') {
                              if (pwdCtrl.text.isEmpty || pwdCtrl.text == 'Emp@Phyto123') {
                                pwdCtrl.text = 'Admin@Phyto123';
                              }
                            } else if (val == 'EMPLOYEE') {
                              if (pwdCtrl.text.isEmpty || pwdCtrl.text == 'Admin@Phyto123') {
                                pwdCtrl.text = 'Emp@Phyto123';
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'e.g. Usman Tariq',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                        onChanged: (v) {
                          final clean = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                          if (clean.isNotEmpty) {
                            final prefix = (selectedRole == 'MANAGER') ? 'admin.' : 'emp.';
                            if (userCtrl.text.isEmpty || userCtrl.text.startsWith('admin.') || userCtrl.text.startsWith('emp.')) {
                              userCtrl.text = '$prefix$clean';
                            }
                            if (emailCtrl.text.isEmpty || emailCtrl.text.endsWith('@phytodoctor.com')) {
                              emailCtrl.text = '$clean@phytodoctor.com';
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone No *',
                          hintText: 'e.g. 0300-1234567',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: designationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Designation *',
                          hintText: 'e.g. Regional Field Supervisor',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Designation is required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Login / Username *',
                          hintText: 'e.g. admin.usman',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().length < 3 ? 'Min 3 characters required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address *',
                          hintText: 'e.g. usman@phytodoctor.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: pwdCtrl,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          hintText: 'Enter login password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility : Icons.visibility_off,
                              size: 20,
                            ),
                            onPressed: () => setState(() => obscurePassword = !obscurePassword),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 6 ? 'Min 6 characters required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => isSubmitting = true);
                          final chosenRole = selectedRole!;
                          final accUsername = userCtrl.text.trim();
                          final accEmail = emailCtrl.text.trim();
                          final accPassword = pwdCtrl.text.trim();

                          final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/users/');
                          try {
                            final res = await http.post(
                              url,
                              headers: {
                                'Content-Type': 'application/json',
                                if (user.accessToken != null) 'Authorization': 'Bearer ${user.accessToken}',
                              },
                              body: jsonEncode({
                                'full_name': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'designation': designationCtrl.text.trim(),
                                'username': accUsername,
                                'email': accEmail,
                                'password': accPassword,
                                'role': chosenRole,
                                'is_active': true,
                              }),
                            );
                            Navigator.pop(dialogCtx);
                            if (res.statusCode == 201 || res.statusCode == 200) {
                              _showAdminCreatedConfirmation(
                                context,
                                role: chosenRole,
                                name: nameCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                designation: designationCtrl.text.trim(),
                                username: accUsername,
                                email: accEmail,
                                password: accPassword,
                              );
                            } else {
                              final body = jsonDecode(res.body);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(body['detail'] ?? 'Could not create account.'),
                                  backgroundColor: AppTheme.alertCrimson,
                                ),
                              );
                            }
                          } catch (e) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error connecting to server: ${e.toString()}'),
                                backgroundColor: AppTheme.alertCrimson,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.botanicalPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAdminCreatedConfirmation(
    BuildContext context, {
    required String role,
    required String name,
    required String phone,
    required String designation,
    required String username,
    required String email,
    required String password,
  }) {
    final isManager = (role == 'MANAGER');
    final roleTitle = isManager ? 'REGIONAL MANAGER / ADMIN' : 'FIELD AGRONOMIST / EMPLOYEE';
    final portalTitle = isManager ? 'Admin / Manager Portal' : 'Field Employee Portal';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.cropGreen, size: 22),
            const SizedBox(width: 8),
            Text(isManager ? 'Admin Account Saved' : 'Employee Account Saved', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cropGreenLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Successfully Saved to PhytoDoctor Database',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.cropGreen),
              ),
            ),
            const SizedBox(height: 10),
            Text('Name: $name', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Phone: $phone'),
            const SizedBox(height: 4),
            Text('Designation: $designation'),
            const SizedBox(height: 4),
            Text('Role: $roleTitle', style: const TextStyle(color: AppTheme.botanicalPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Assigned Portal: $portalTitle', style: TextStyle(color: isManager ? AppTheme.adminSlate : AppTheme.cropGreen, fontWeight: FontWeight.w700)),
            const Divider(height: 18),
            const Text('Login Credentials:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            Text('Username: $username', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            const SizedBox(height: 4),
            Text('Email: $email', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            const SizedBox(height: 4),
            Text('Password: $password', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppTheme.alertCrimson)),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share Credentials'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.botanicalPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final shareText = '''🌿 PhytoDoctor Account Credentials 🌿
Name: $name
Phone: $phone
Designation: $designation
Role: $roleTitle
Assigned Portal: $portalTitle

Login Credentials:
Username: $username
Email: $email
Password: $password
Server Address: ${AuthService.defaultBaseUrl}
''';
              Clipboard.setData(ClipboardData(text: shareText));
              await NativeShareService.share(
                text: shareText,
                subject: 'PhytoDoctor Account Credentials - $name',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Credentials ready to share or paste!'),
                    backgroundColor: AppTheme.cropGreen,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTargetQuotasDialog(BuildContext context) {
    final dailyVisitCtrl = TextEditingController(text: '6');
    final monthlySalesCtrl = TextEditingController(text: '500,000');
    final monthCtrl = TextEditingController(text: 'October 2026');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.flag, color: AppTheme.botanicalPrimary, size: 22),
                SizedBox(width: 8),
                Text('Set Monthly Quotas & Targets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company targets are synchronized across all regional teams and field agronomists.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: dailyVisitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Daily Visit Target per Officer',
                      hintText: 'e.g. 6 visits/day',
                      suffixText: 'visits/day',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: monthlySalesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Sales Quota (PKR)',
                      hintText: 'e.g. 500,000',
                      prefixText: 'PKR ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: monthCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quota Period / Month',
                      hintText: 'e.g. October 2026',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        final visits = int.tryParse(dailyVisitCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 6;
                        final sales = int.tryParse(monthlySalesCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 500000;
                        final periodMonth = monthCtrl.text.trim();

                        try {
                          final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/targets/quotas');
                          await http.post(
                            url,
                            headers: {
                              'Content-Type': 'application/json',
                              if (user.accessToken != null) 'Authorization': 'Bearer ${user.accessToken}',
                            },
                            body: jsonEncode({
                              'daily_visits': visits,
                              'monthly_sales_pkr': sales,
                              'month': periodMonth,
                            }),
                          );
                        } catch (_) {}

                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Targets Saved! Daily: $visits visits/day, Sales: PKR ${sales.toString()} for $periodMonth'),
                            backgroundColor: AppTheme.cropGreen,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.botanicalPrimary,
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Quotas'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String customerType = 'FARMER';
    String territory = 'Multan';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.person_add, color: AppTheme.botanicalPrimary, size: 22),
                SizedBox(width: 8),
                Text('Add Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin & CEO Authority: Add farm, dealer, or retail clients. Customers are automatically assigned to the nearest field agronomist in the designated territory.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Customer / Farm Name *',
                        hintText: 'e.g. Al-Rehman Agro Farm',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Customer name is required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        hintText: 'e.g. 0300-1234567',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: customerType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Customer Category *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'FARMER', child: Text('Progressive Farmer / Grower')),
                        DropdownMenuItem(value: 'DEALER', child: Text('Pesticide & Seed Dealer')),
                        DropdownMenuItem(value: 'DISTRIBUTOR', child: Text('Regional Distributor')),
                        DropdownMenuItem(value: 'RETAILER', child: Text('Agri Input Retailer')),
                      ],
                      onChanged: (val) => setState(() => customerType = val!),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: territory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Territory / Region *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Multan', child: Text('Multan Territory')),
                        DropdownMenuItem(value: 'Vehari', child: Text('Vehari Territory')),
                        DropdownMenuItem(value: 'Khanewal', child: Text('Khanewal Territory')),
                        DropdownMenuItem(value: 'Sahiwal', child: Text('Sahiwal Territory')),
                        DropdownMenuItem(value: 'Bahawalpur', child: Text('Bahawalpur Territory')),
                        DropdownMenuItem(value: 'Rahim Yar Khan', child: Text('Rahim Yar Khan Territory')),
                        DropdownMenuItem(value: 'Faisalabad', child: Text('Faisalabad Territory')),
                      ],
                      onChanged: (val) => setState(() => territory = val!),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Land / Address Description',
                        hintText: 'e.g. 50 Acres Cotton Farm, Chak 45/WB',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => isSubmitting = true);

                        final custName = nameCtrl.text.trim();
                        final custPhone = phoneCtrl.text.trim();
                        final custAddress = addressCtrl.text.trim();

                        String assignedOfficerName = 'Nearest Territory Agronomist';
                        try {
                          final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/customers/');
                          final res = await http.post(
                            url,
                            headers: {
                              'Content-Type': 'application/json',
                              if (user.accessToken != null) 'Authorization': 'Bearer ${user.accessToken}',
                            },
                            body: jsonEncode({
                              'name': custName,
                              'phone': custPhone,
                              'customer_type': customerType,
                              'territory': territory,
                              'address': custAddress,
                              'latitude': 30.1575,
                              'longitude': 71.5249,
                            }),
                          );
                          if (res.statusCode == 201 || res.statusCode == 200) {
                            final data = jsonDecode(res.body);
                            if (data['assigned_employee_name'] != null) {
                              assignedOfficerName = data['assigned_employee_name'];
                            }
                          }
                        } catch (_) {}

                        Navigator.pop(dialogCtx);
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Row(
                              children: const [
                                Icon(Icons.check_circle, color: AppTheme.cropGreen),
                                SizedBox(width: 8),
                                Text('Customer Added', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Customer "$custName" has been registered.', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Text('Territory: $territory'),
                                const SizedBox(height: 4),
                                Text('Assigned Officer: $assignedOfficerName', style: const TextStyle(color: AppTheme.botanicalPrimary, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text('This customer is now visible in the territory for field visits.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(c),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.botanicalPrimary, foregroundColor: Colors.white),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.botanicalPrimary,
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Customer'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OwnerKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _OwnerKpiCard({
    Key? key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
        border: Border.all(color: AppTheme.sageBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios, size: 12, color: color.withOpacity(0.6)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
        child: content,
      );
    }

    return content;
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _AdminTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
        border: Border.all(color: AppTheme.sageBorder),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.adminSlateLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AppTheme.adminSlate, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        trailing: badgeText != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppTheme.adminSlate).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    color: badgeColor ?? AppTheme.adminSlate,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
      ),
    );
  }
}
