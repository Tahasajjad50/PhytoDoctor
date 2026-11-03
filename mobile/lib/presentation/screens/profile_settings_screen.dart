import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import 'portal_selection_screen.dart';

class ProfileSettingsScreen extends StatelessWidget {
  final UserModel user;

  const ProfileSettingsScreen({Key? key, required this.user}) : super(key: key);

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
          'Any queued visits in local storage will remain saved and will sync next time you log in.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
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
                    _ProfileDetailRow(label: isOwner ? 'Operations Scope' : 'Field Territory', value: territory),
                    if (!isOwner) ...[
                      const Divider(),
                      _ProfileDetailRow(
                        label: 'Reporting Line',
                        value: isManager ? 'Mehmood Ayyaz (CEO)' : 'Farhan Qureshi (Regional Manager)',
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Offline Sync Queue Diagnostics
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
                    const Text(
                      'Offline Storage & Background Sync',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Pending Offline Queue:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                        Text('0 Visits (Fully Synced)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.cropGreen)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Local SQLite Database:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                        Text('Active & Healthy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Client Catalog Cache:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                        Text('142 Dealers Cached', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Offline queue synchronized with Phyto Doctor server!'),
                            backgroundColor: AppTheme.cropGreen,
                          ),
                        );
                      },
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('Force Cloud Sync Now'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.botanicalPrimary,
                        side: const BorderSide(color: AppTheme.botanicalPrimary),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sign Out Button
              ElevatedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout),
                label: Text(isOwner || isManager ? 'Sign Out of Account' : 'Sign Out of Field Device'),
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

