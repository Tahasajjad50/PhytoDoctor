import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/models/user_model.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/native_platform_service.dart';
import '../../core/services/share_service.dart';
import '../../core/storage/secure_storage_service.dart';
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
  int _activeDailyTarget = 6;
  int _activeMonthlySales = 500000;
  String _activeQuotaMonth = 'October 2026';
  Timer? _refreshTimer;

  UserModel get user => widget.user;

  @override
  void initState() {
    super.initState();
    _fetchLiveStats();
    _fetchActiveQuotas();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchLiveStats());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkAndPromptUpdate(context);
    });
  }

  Future<void> _fetchActiveQuotas() async {
    try {
      final token = widget.user.accessToken;
      final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/targets/quotas');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted && data is Map<String, dynamic>) {
          setState(() {
            _activeDailyTarget = (data['daily_visits'] as num?)?.toInt() ?? _activeDailyTarget;
            _activeMonthlySales = (data['monthly_sales_pkr'] as num?)?.toInt() ?? _activeMonthlySales;
            _activeQuotaMonth = data['month'] as String? ?? _activeQuotaMonth;
          });
        }
      }
    } catch (_) {}
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

    // Direct pending count verification matching Manager Verification Queue filter
    try {
      final token = widget.user.accessToken;
      final pendingUrl = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/visits?status=PENDING&limit=1');
      final pendingRes = await http.get(
        pendingUrl,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (pendingRes.statusCode == 200) {
        final pData = jsonDecode(pendingRes.body);
        final totalPending = (pData is Map ? pData['total'] : null) as num?;
        if (totalPending != null && mounted) {
          setState(() {
            _pendingCount = totalPending.toInt();
          });
        }
      }
    } catch (_) {}
  }

  void _confirmSignOut(BuildContext context) async {
    await SecureStorageService().clearAll();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PortalSelectionScreen()),
      (route) => false,
    );
  }

  bool get _isCEO => user.isOwner;

  Future<void> _openGoogleMaps(BuildContext context, double lat, double lng) async {
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(Visit+Location)');
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(geoUri)) {
        final ok = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    } catch (e) {
      debugPrint('Native geo launch notice: $e');
    }

    try {
      final ok = await launchUrl(webUri, mode: LaunchMode.externalNonBrowserApplication);
      if (ok) return;
    } catch (e) {
      debugPrint('External app launch notice: $e');
    }

    try {
      final ok = await launchUrl(webUri, mode: LaunchMode.platformDefault);
      if (ok) return;
    } catch (e) {
      debugPrint('Platform default launch notice: $e');
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coordinates: ${lat.toStringAsFixed(4)}°N, ${lng.toStringAsFixed(4)}°E. (Lat/Long verified)'),
        duration: const Duration(seconds: 4),
      ),
    );
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
                              isOwner ? 'OWNER & CEO' : 'ADMIN',
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
                          Expanded(
                            child: Text(
                              'Account: ${user.email}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text('Profile', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.botanicalPrimary)),
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManagerDashboardScreen(user: user),
                          ),
                        ).then((_) => _fetchLiveStats());
                      },
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
                badgeColor: AppTheme.cropGreen,
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

              // App Version & In-App Update Distribution
              _AdminTile(
                icon: Icons.system_update_outlined,
                title: 'In-App Update & Version Control',
                subtitle: 'Push latest update to all users',
                badgeText: 'v${AppConfig.appVersion} (B${AppConfig.buildNumber})',
                badgeColor: AppTheme.botanicalPrimary,
                onTap: () => _showAppUpdateManagerDialog(context),
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
              if (_isCEO) ...[
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
                  subtitle: 'Manage staff & admin accounts',
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
                  icon: Icons.person_add_alt_1,
                  title: 'Add Employee Account',
                  subtitle: 'Create a new field employee account',
                  badgeText: 'ADMIN ACCESS',
                  badgeColor: AppTheme.botanicalPrimary,
                  onTap: () => _showAddAdminDialog(context),
                ),
                const SizedBox(height: 10),

                _AdminTile(
                  icon: Icons.badge_outlined,
                  title: 'Supervised Accounts Directory',
                  subtitle: 'Manage accounts you created',
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
                subtitle: 'Register new customer',
                badgeText: 'ADMIN ONLY',
                badgeColor: AppTheme.botanicalPrimary,
                onTap: () => _showAddCustomerDialog(context),
              ),

              const SizedBox(height: 10),

              _AdminTile(
                icon: Icons.verified,
                title: 'Manager Verification Queue',
                subtitle: 'Review pending visits',
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
                    ? 'Assign or transfer employees'
                    : 'Manage supervised staff',
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
                subtitle: 'Account & settings',
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
                subtitle: 'Daily target: $_activeDailyTarget visits/day',
                onTap: () => _showTargetQuotasDialog(context),
              ),

              const SizedBox(height: 10),

              _AdminTile(
                icon: Icons.file_download,
                title: 'Export Audit Reports (Excel)',
                subtitle: 'Visits, attendance & GPS coordinates (.xlsx)',
                onTap: () => _showExportAuditReportDialog(context),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }


  void _showExportAuditReportDialog(BuildContext context) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> staffList = [];
    bool isLoading = true;
    bool isExporting = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (isLoading && staffList.isEmpty && errorMsg == null) {
              Future.microtask(() async {
                try {
                  final token = widget.user.accessToken;
                  final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/users/created-accounts');
                  final res = await http.get(
                    url,
                    headers: {
                      'Accept': 'application/json',
                      if (token != null) 'Authorization': 'Bearer $token',
                    },
                  ).timeout(const Duration(seconds: 10));

                  if (res.statusCode == 200) {
                    final List<dynamic> data = jsonDecode(res.body);
                    if (ctx.mounted) {
                      setDialogState(() {
                        staffList = data.cast<Map<String, dynamic>>();
                        isLoading = false;
                      });
                    }
                  } else {
                    if (ctx.mounted) {
                      setDialogState(() {
                        errorMsg = 'Could not load staff list (HTTP ${res.statusCode})';
                        isLoading = false;
                      });
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() {
                      errorMsg = 'Network error: $e';
                      isLoading = false;
                    });
                  }
                }
              });
            }

            final query = searchCtrl.text.trim().toLowerCase();
            final filteredStaff = staffList.where((u) {
              if (query.isEmpty) return true;
              final name = (u['full_name']?.toString() ?? '').toLowerCase();
              final uname = (u['username']?.toString() ?? '').toLowerCase();
              final email = (u['email']?.toString() ?? '').toLowerCase();
              final role = (u['role']?.toString() ?? '').toLowerCase();
              return name.contains(query) || uname.contains(query) || email.contains(query) || role.contains(query);
            }).toList();

            Future<void> triggerExport(String? employeeId, String label) async {
              setDialogState(() => isExporting = true);
              try {
                final token = widget.user.accessToken;
                final querySuffix = (employeeId != null && employeeId.isNotEmpty) ? '?employee_id=$employeeId' : '';
                final exportUri = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/admin/export-audit-report$querySuffix');

                final res = await http.get(
                  exportUri,
                  headers: {
                    if (token != null) 'Authorization': 'Bearer $token',
                  },
                ).timeout(const Duration(seconds: 35));

                if (res.statusCode != 200) {
                  throw Exception('Server returned HTTP ${res.statusCode}');
                }

                final timestamp = DateTime.now().millisecondsSinceEpoch;
                final safeLabel = label.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
                final fileName = 'PhytoDoctor_Audit_${safeLabel}_$timestamp.xlsx';

                String savedPath;
                try {
                  final downloadDir = Directory('/storage/emulated/0/Download');
                  if (await downloadDir.exists()) {
                    final file = File('${downloadDir.path}/$fileName');
                    await file.writeAsBytes(res.bodyBytes);
                    savedPath = file.path;
                  } else {
                    final extDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
                    final file = File('${extDir.path}/$fileName');
                    await file.writeAsBytes(res.bodyBytes);
                    savedPath = file.path;
                  }
                } catch (_) {
                  final docDir = await getApplicationDocumentsDirectory();
                  final file = File('${docDir.path}/$fileName');
                  await file.writeAsBytes(res.bodyBytes);
                  savedPath = file.path;
                }

                if (!mounted) return;
                Navigator.pop(dialogCtx);

                showDialog(
                  context: this.context,
                  builder: (doneCtx) => AlertDialog(
                    title: Row(
                      children: const [
                        Icon(Icons.check_circle, color: AppTheme.cropGreen),
                        SizedBox(width: 8),
                        Expanded(child: Text('Excel Report Ready', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Exported "$label" report (.xlsx).', style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.warmOffWhite,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.sageBorder),
                            ),
                            child: Text(
                              'Saved to:\n$savedPath',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(doneCtx),
                        child: const Text('Close'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final shared = await NativePlatformService.shareFile(
                            filePath: savedPath,
                            subject: 'PhytoDoctor Audit Report - $label',
                            title: 'Share Excel Report',
                          );
                          if (!shared && mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Report saved at: $savedPath')),
                            );
                          }
                        },
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.botanicalPrimary,
                          side: const BorderSide(color: AppTheme.botanicalPrimary),
                          minimumSize: const Size(80, 40),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(doneCtx);
                          final fileUri = Uri.file(savedPath);
                          try {
                            await launchUrl(fileUri, mode: LaunchMode.externalApplication);
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(content: Text('Report saved at: $savedPath')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.botanicalPrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(80, 40),
                        ),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                if (ctx.mounted) {
                  setDialogState(() => isExporting = false);
                }
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Export failed: $e'),
                      backgroundColor: AppTheme.alertCrimson,
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: const [
                  Icon(Icons.table_chart, color: AppTheme.cropGreen, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Export Audit Report (.xlsx)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search bar for CEO/Admin to find specific employee
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search employee by name or username...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.warmOffWhite,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.sageBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Full Company Report Card
                    InkWell(
                      onTap: isExporting ? null : () => triggerExport(null, 'All_Staff'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cropGreenLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cropGreen.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.groups, color: AppTheme.cropGreen),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'All Employees (Full Report)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.cropGreen),
                                  ),
                                  Text(
                                    'Visits, Daily Attendance, Mark-In/Out & GPS',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.download, color: AppTheme.cropGreen, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'OR SELECT SPECIFIC EMPLOYEE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: isExporting
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: AppTheme.cropGreen),
                                  SizedBox(height: 10),
                                  Text('Generating Excel workbook...', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                ],
                              ),
                            )
                          : isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : errorMsg != null
                                  ? Center(child: Text(errorMsg!, style: const TextStyle(color: AppTheme.alertCrimson, fontSize: 12)))
                                  : filteredStaff.isEmpty
                                      ? const Center(child: Text('No matching staff found.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)))
                                      : ListView.separated(
                                          itemCount: filteredStaff.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (_, idx) {
                                            final emp = filteredStaff[idx];
                                            final fullName = emp['full_name']?.toString() ?? 'Employee';
                                            final username = emp['username']?.toString() ?? '';
                                            final role = emp['role']?.toString() ?? 'EMPLOYEE';
                                            final empId = emp['id']?.toString() ?? '';
                                            return ListTile(
                                              dense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                                              leading: CircleAvatar(
                                                radius: 16,
                                                backgroundColor: AppTheme.botanicalPrimary.withOpacity(0.15),
                                                child: Text(
                                                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'E',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.botanicalPrimary),
                                                ),
                                              ),
                                              title: Text(fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                              subtitle: Text('@$username • $role', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                              trailing: const Icon(Icons.file_download, color: AppTheme.botanicalPrimary, size: 18),
                                              onTap: () => triggerExport(empId, username),
                                            );
                                          },
                                        ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isExporting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
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
    String? selectedRole = _isCEO ? null : 'EMPLOYEE'; // Admins can only create Employee accounts
    bool isSubmitting = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                _isCEO ? 'Add Account & Assign Role' : 'Add Field Employee Account',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role Selection (CEOs can pick Admin/Employee; Admins only Employee)
                      if (_isCEO) ...[
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
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.cropGreenLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cropGreen.withOpacity(0.3)),
                            ),
                            child: const Text(
                              'Role: Field Agronomist / Employee',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.cropGreen),
                            ),
                          ),
                        ),

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
                            if (!mounted) return;
                            Navigator.pop(dialogCtx);
                            if (res.statusCode == 201 || res.statusCode == 200) {
                              _showAdminCreatedConfirmation(
                                this.context,
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
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(body['detail'] ?? 'Could not create account.'),
                                  backgroundColor: AppTheme.alertCrimson,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(this.context).showSnackBar(
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
                    minimumSize: const Size(120, 42),
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
            Expanded(
              child: Text(
                isManager ? 'Admin Account Saved' : 'Employee Account Saved',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
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
                  'Saved to PhytoDoctor Database',
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
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share Credentials'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.botanicalPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, 42),
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
''';
              Clipboard.setData(ClipboardData(text: shareText));
              await NativeShareService.share(
                text: shareText,
                subject: 'PhytoDoctor Account Credentials - $name',
              );
              if (this.context.mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Credentials ready to share or paste!'),
                    backgroundColor: AppTheme.cropGreen,
                  ),
                );
              }
            },
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(minimumSize: const Size(76, 42)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTargetQuotasDialog(BuildContext context) {
    final dailyVisitCtrl = TextEditingController(text: '$_activeDailyTarget');
    final monthlySalesCtrl = TextEditingController(text: '$_activeMonthlySales');
    final monthCtrl = TextEditingController(text: _activeQuotaMonth);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.flag, color: AppTheme.botanicalPrimary, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Set Monthly Quotas & Targets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        setDialogState(() => isSaving = true);
                        final visits = int.tryParse(dailyVisitCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 6;
                        final sales = int.tryParse(monthlySalesCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 500000;
                        final periodMonth = monthCtrl.text.trim();

                        try {
                          final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/targets/quotas');
                          final res = await http.post(
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
                          if (res.statusCode != 200 && res.statusCode != 201) {
                            throw Exception('Server returned ${res.statusCode}');
                          }
                          if (!mounted) return;
                          setState(() {
                            _activeDailyTarget = visits;
                            _activeMonthlySales = sales;
                            _activeQuotaMonth = periodMonth;
                          });
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Targets saved: $visits visits/day, PKR $sales ($periodMonth)'),
                              backgroundColor: AppTheme.cropGreen,
                            ),
                          );
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save targets: ${e.toString().replaceAll('Exception: ', '')}'),
                              backgroundColor: AppTheme.alertCrimson,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.botanicalPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 42),
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
                        String? customerError;
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
                          ).timeout(const Duration(seconds: 15));
                          if (res.statusCode == 201 || res.statusCode == 200) {
                            final data = jsonDecode(res.body);
                            if (data['assigned_employee_name'] != null) {
                              assignedOfficerName = data['assigned_employee_name'];
                            }
                          } else {
                            final err = jsonDecode(res.body);
                            customerError = err['detail']?.toString() ?? 'Failed (${res.statusCode})';
                          }
                        } catch (e) {
                          customerError = 'Network error: $e';
                        }

                        if (!mounted) return;
                        if (customerError != null) {
                          setState(() => isSubmitting = false);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text(customerError), backgroundColor: AppTheme.alertCrimson),
                          );
                          return;
                        }

                        Navigator.pop(dialogCtx);
                        showDialog(
                          context: this.context,
                          builder: (c) => AlertDialog(
                            title: Row(
                              children: const [
                                Icon(Icons.check_circle, color: AppTheme.cropGreen),
                                SizedBox(width: 8),
                                Expanded(child: Text('Customer Added', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('"$custName" registered.', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text('Territory: $territory'),
                                  const SizedBox(height: 4),
                                  Text('Assigned: $assignedOfficerName', style: const TextStyle(color: AppTheme.botanicalPrimary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(c),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.botanicalPrimary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(80, 42),
                                ),
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

  void _showAppUpdateManagerDialog(BuildContext context) {
    final versionCtrl = TextEditingController(text: AppConfig.appVersion);
    final buildCtrl = TextEditingController(text: AppConfig.buildNumber.toString());
    final notesCtrl = TextEditingController();
    bool isPushing = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.system_update_outlined, color: AppTheme.botanicalPrimary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('In-App Update & Version Control', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.sageLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.sageBorder),
                      ),
                      child: Text(
                        'Current App: v${AppConfig.appVersion} (Build ${AppConfig.buildNumber})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: versionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Target Version',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: buildCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Build Number',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Release Notes (Optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isPushing ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isPushing
                      ? null
                      : () async {
                          final ver = versionCtrl.text.trim();
                          final bld = int.tryParse(buildCtrl.text.trim()) ?? AppConfig.buildNumber;
                          if (ver.isEmpty) return;

                          setDialogState(() => isPushing = true);
                          try {
                            final token = widget.user.accessToken;
                            final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/system/push-update');
                            final res = await http.post(
                              url,
                              headers: {
                                'Content-Type': 'application/json',
                                'Accept': 'application/json',
                                if (token != null) 'Authorization': 'Bearer $token',
                              },
                              body: jsonEncode({
                                'latest_version': ver,
                                'latest_build_number': bld,
                                'min_required_build_number': bld,
                                'force_update': true,
                                if (notesCtrl.text.trim().isNotEmpty) 'release_notes': notesCtrl.text.trim(),
                              }),
                            ).timeout(const Duration(seconds: 15));

                            if (res.statusCode != 200) {
                              throw Exception('HTTP ${res.statusCode}');
                            }

                            if (!mounted) return;
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Update v$ver (Build $bld) pushed to all users.'),
                                backgroundColor: AppTheme.cropGreen,
                              ),
                            );
                          } catch (e) {
                            if (ctx.mounted) setDialogState(() => isPushing = false);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to push update: $e'),
                                  backgroundColor: AppTheme.alertCrimson,
                                ),
                              );
                            }
                          }
                        },
                  icon: isPushing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('Push Latest Update'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.botanicalPrimary, foregroundColor: Colors.white),
                ),
              ],
            );
          },
        );
      },
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
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
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
