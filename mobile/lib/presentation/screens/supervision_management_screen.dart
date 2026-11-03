import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class SupervisionManagementScreen extends StatefulWidget {
  final UserModel currentUser;

  const SupervisionManagementScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<SupervisionManagementScreen> createState() => _SupervisionManagementScreenState();
}

class _SupervisionManagementScreenState extends State<SupervisionManagementScreen> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _supervisors = [];
  bool _isOwner = false;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSupervisionData();
  }

  Future<void> _loadSupervisionData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = widget.currentUser.accessToken;
      final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/users/supervision/list');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        setState(() {
          _employees = List<Map<String, dynamic>>.from(data['employees'] ?? []);
          _supervisors = List<Map<String, dynamic>>.from(data['available_supervisors'] ?? []);
          _isOwner = data['is_owner'] ?? false;
          _isLoading = false;
        });
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['detail'] ?? 'Failed to load supervision list (${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _showTransferDialog(Map<String, dynamic> emp) async {
    String? selectedManagerId = emp['manager_id'];
    final notesController = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _isOwner ? 'Assign or Force-Transfer' : 'Transfer Employee Mentorship',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                          ),
                        ),
                        if (_isOwner)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.earthAmberLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CEO OVERRIDE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.earthAmber),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isOwner
                          ? 'CEO Mehmood Ayyaz has direct authority to reassign ${emp['full_name']} to any admin or manager.'
                          : 'You can transfer reporting and supervision of ${emp['full_name']} to another authorized administrator.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),

                    // Employee Profile Snippet
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warmOffWhite,
                        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                        border: Border.all(color: AppTheme.sageBorder),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.botanicalPrimary.withOpacity(0.12),
                            child: const Icon(Icons.person, color: AppTheme.botanicalPrimary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  emp['full_name'] ?? emp['username'],
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                Text(
                                  'Current: ${emp['manager_name'] ?? 'Unassigned (No Supervisor)'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: emp['manager_name'] != null ? AppTheme.botanicalPrimary : AppTheme.earthAmber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    const Text(
                      'Select New Supervisor / Reporting Admin',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                    ),
                    const SizedBox(height: 8),

                    // Supervisor Selection List
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.sageBorder),
                        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          // Unassigned Option (CEO only)
                          if (_isOwner)
                            RadioListTile<String?>(
                              title: const Text('Unassigned (Direct Executive Oversight)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Remove assigned regional manager', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              value: null,
                              groupValue: selectedManagerId,
                              activeColor: AppTheme.botanicalPrimary,
                              onChanged: (val) {
                                setSheetState(() => selectedManagerId = val);
                              },
                            ),
                          ..._supervisors.map((sup) {
                            final isCurrent = sup['id'] == emp['manager_id'];
                            return RadioListTile<String?>(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sup['full_name'],
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: sup['role'] == 'OWNER' ? AppTheme.earthAmberLight : AppTheme.adminSlateLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      sup['role'] == 'OWNER' ? 'CEO' : 'ADMIN',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: sup['role'] == 'OWNER' ? AppTheme.earthAmber : AppTheme.adminSlate,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${sup['designation'] ?? sup['username']}${isCurrent ? ' • [Currently Assigned]' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isCurrent ? AppTheme.botanicalPrimary : AppTheme.textMuted,
                                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              value: sup['id'],
                              groupValue: selectedManagerId,
                              activeColor: AppTheme.botanicalPrimary,
                              onChanged: (val) {
                                setSheetState(() => selectedManagerId = val);
                              },
                            );
                          }).toList(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Transfer Reason / Operational Notes (Optional)',
                        hintText: 'e.g., Regional territory re-assignment',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() => isSubmitting = true);
                              try {
                                final token = widget.currentUser.accessToken;
                                final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/users/supervision/transfer');
                                final res = await http.post(
                                  url,
                                  headers: {
                                    'Content-Type': 'application/json',
                                    'Accept': 'application/json',
                                    if (token != null) 'Authorization': 'Bearer $token',
                                  },
                                  body: jsonEncode({
                                    'employee_id': emp['id'],
                                    'new_manager_id': selectedManagerId,
                                    'notes': notesController.text.trim(),
                                  }),
                                );

                                if (res.statusCode == 200) {
                                  Navigator.pop(sheetCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Reporting hierarchy updated for ${emp['full_name']}'),
                                      backgroundColor: AppTheme.cropGreen,
                                    ),
                                  );
                                  _loadSupervisionData();
                                } else {
                                  final err = jsonDecode(res.body);
                                  throw Exception(err['detail'] ?? 'Transfer failed');
                                }
                              } catch (e) {
                                setSheetState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
                                    backgroundColor: AppTheme.alertCrimson,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.botanicalPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Confirm Supervisor Transfer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _employees.where((e) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (e['full_name'] ?? '').toString().toLowerCase();
      final user = (e['username'] ?? '').toString().toLowerCase();
      final mgr = (e['manager_name'] ?? '').toString().toLowerCase();
      return name.contains(q) || user.contains(q) || mgr.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: const Text('Employee Supervision & Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadSupervisionData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search & Information Header
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.surfaceCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isOwner ? Icons.admin_panel_settings : Icons.supervisor_account,
                        color: _isOwner ? AppTheme.earthAmber : AppTheme.botanicalPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isOwner
                              ? 'Executive Hierarchy Oversight (CEO Mehmood Ayyaz)'
                              : 'Staff Mentorship & Supervisor Reporting',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textMain),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isOwner
                        ? 'Full authority: Forcefully transfer any field employee to any regional manager or admin.'
                        : 'Admins have access to employees they created or supervise, and can transfer reporting to another admin.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by employee name, username, or supervisor...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                        borderSide: const BorderSide(color: AppTheme.sageBorder),
                      ),
                      filled: true,
                      fillColor: AppTheme.warmOffWhite,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.botanicalPrimary))
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: AppTheme.alertCrimson),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.alertCrimson)),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: _loadSupervisionData,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.botanicalPrimary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 54, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text('No employees found matching filter', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadSupervisionData,
                              color: AppTheme.botanicalPrimary,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: filtered.length,
                                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                                itemBuilder: (ctx, i) {
                                  final emp = filtered[i];
                                  final hasManager = emp['manager_name'] != null;
                                  final canTransfer = emp['can_transfer'] == true;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceCard,
                                      borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                                      border: Border.all(color: AppTheme.sageBorder),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Top Row: Name and Role
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: AppTheme.botanicalPrimary.withOpacity(0.12),
                                              child: Text(
                                                (emp['full_name'] as String? ?? 'E').substring(0, 1).toUpperCase(),
                                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.botanicalPrimary),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    emp['full_name'] ?? emp['username'],
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                                                  ),
                                                  Text(
                                                    '${emp['designation'] ?? 'Field Agronomist'} • @${emp['username']}',
                                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: emp['is_active'] == true ? AppTheme.cropGreenLight : AppTheme.alertCrimsonLight,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                emp['is_active'] == true ? 'ACTIVE' : 'INACTIVE',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: emp['is_active'] == true ? AppTheme.cropGreen : AppTheme.alertCrimson,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Supervisor Assigned Box
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: hasManager ? AppTheme.sageLight : AppTheme.earthAmberLight.withOpacity(0.4),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: hasManager ? AppTheme.sageBorder : AppTheme.earthAmber.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                hasManager ? Icons.verified_user : Icons.warning_amber_rounded,
                                                size: 16,
                                                color: hasManager ? AppTheme.botanicalPrimary : AppTheme.earthAmber,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      hasManager ? 'Assigned Supervisor / Reporting Admin:' : 'Supervision Status:',
                                                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                                                    ),
                                                    Text(
                                                      hasManager
                                                          ? '${emp['manager_name']} (@${emp['manager_username']})'
                                                          : 'Unassigned (No Supervisor)',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: hasManager ? AppTheme.botanicalPrimary : AppTheme.earthAmber,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 8),

                                        // Created By Tag & Actions
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Creator: ${emp['created_by_name'] ?? 'System'}',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (canTransfer)
                                              TextButton.icon(
                                                onPressed: () => _showTransferDialog(emp),
                                                icon: const Icon(Icons.swap_horiz, size: 16, color: AppTheme.botanicalPrimary),
                                                label: Text(
                                                  _isOwner ? 'Assign / Transfer' : 'Transfer Mentorship',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.botanicalPrimary),
                                                ),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
