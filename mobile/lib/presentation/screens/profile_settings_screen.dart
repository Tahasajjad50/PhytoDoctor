import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/sync/offline_sync_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/real_visit_repository.dart';
import 'portal_selection_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final UserModel user;

  const ProfileSettingsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final OfflineSyncManager _syncManager = OfflineSyncManager();
  bool _isSyncing = false;

  UserModel get user => widget.user;

  @override
  void initState() {
    super.initState();
    _syncManager.refreshCounts();
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
          side: const BorderSide(color: AppTheme.sageBorder),
        ),
        title: const Text('Confirm Sign Out', style: TextStyle(color: AppTheme.textMain)),
        content: const Text(
          'Sign out of your account?',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              AuthService().logout();
              await SecureStorageService().clearAll();
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const PortalSelectionScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertCrimson,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 42),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = user.role == 'OWNER';
    final isManager = user.role == 'MANAGER';
    final isMehmood = user.username.toLowerCase() == 'mehmoodayyaz' || user.email.toLowerCase().contains('mehmood');
    final roleTitle = isOwner
        ? (isMehmood ? 'OWNER & CEO' : 'EXECUTIVE OWNER')
        : (isManager ? 'REGIONAL MANAGER / ADMIN' : 'FIELD AGRONOMIST');
    final idCode = isOwner
        ? 'PHYTO-EXEC-01'
        : (isManager
            ? 'PHYTO-MGR-${user.id.length >= 4 ? user.id.substring(0, 4).toUpperCase() : "01"}'
            : 'PHYTO-AGRI-${user.id.length >= 4 ? user.id.substring(0, 4).toUpperCase() : "01"}');
    final territory = isOwner
        ? 'National Corporate Headquarters (Punjab & Sindh)'
        : (isManager ? 'Punjab Field Division' : (user.designation?.isNotEmpty == true ? user.designation! : 'Punjab Central / Multan Zone'));
    final designation = user.designation?.isNotEmpty == true
        ? user.designation!
        : (isOwner ? 'Chief Executive Officer' : (isManager ? 'Regional Field Manager' : 'Field Agronomist'));

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: Text(isOwner
            ? 'Executive Profile & Settings'
            : (isManager ? 'Manager Profile & Settings' : 'Officer Profile & System Settings')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Identity Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                  border: Border.all(color: AppTheme.sageBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isOwner ? AppTheme.adminSlate : AppTheme.botanicalPrimary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Icon(
                              isOwner ? Icons.verified_user : (isManager ? Icons.security : Icons.person),
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim().isNotEmpty
                                    ? user.fullName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim()
                                    : user.username,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textMain,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Code: $idCode',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _ProfileDetailRow(label: 'Assigned Role', value: roleTitle),
                    const Divider(),
                    _ProfileDetailRow(label: 'Designation', value: designation),
                    const Divider(),
                    _ProfileDetailRow(label: 'Registered Email', value: user.email),
                    if (user.phone != null && user.phone!.isNotEmpty) ...[
                      const Divider(),
                      _ProfileDetailRow(label: 'Contact Phone', value: user.phone!),
                    ],
                    const Divider(),
                    _ProfileDetailRow(label: isOwner ? 'Scope' : 'Territory', value: territory),
                    if (!isOwner) ...[
                      const Divider(),
                      _ProfileDetailRow(
                        label: 'Role',
                        value: user.role,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Offline Sync Queue Diagnostics
              ListenableBuilder(
                listenable: _syncManager,
                builder: (context, _) {
                  final pending = _syncManager.pendingCount;
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                      border: Border.all(color: AppTheme.sageBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Offline Storage & Sync',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text('Offline Queue:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                pending == 0 ? '0 Pending (Synced)' : '$pending Pending',
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: pending == 0 ? AppTheme.cropGreen : AppTheme.earthAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Flexible(
                              child: Text('Local Storage:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
                            ),
                            SizedBox(width: 8),
                            Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
                          ],
                        ),
                        if (pending > 0 || _isSyncing) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _isSyncing
                                ? null
                                : () async {
                                    setState(() => _isSyncing = true);
                                    try {
                                      final token = user.accessToken ?? '';
                                      final count = await _syncManager.syncNow(
                                        repository: RealVisitRepository(),
                                        token: token,
                                        forceRetryAll: true,
                                      );
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        SnackBar(
                                          content: Text(count > 0 ? 'Synced $count visit(s).' : 'Sync complete.'),
                                          backgroundColor: AppTheme.cropGreen,
                                        ),
                                      );
                                    } finally {
                                      if (mounted) setState(() => _isSyncing = false);
                                    }
                                  },
                            icon: _isSyncing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.sync, size: 18),
                            label: Text(_isSyncing ? 'Syncing...' : 'Sync Pending Visits'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.botanicalPrimary,
                              side: const BorderSide(color: AppTheme.botanicalPrimary),
                              minimumSize: const Size(double.infinity, 44),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Sign Out Button
              ElevatedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertCrimson,
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileDetailRow({Key? key, required this.label, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain),
            ),
          ),
        ],
      ),
    );
  }
}

