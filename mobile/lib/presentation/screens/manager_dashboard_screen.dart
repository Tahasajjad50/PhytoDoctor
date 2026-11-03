import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'account_directory_screen.dart';
import 'chat_list_screen.dart';
import 'portal_selection_screen.dart';
import 'profile_settings_screen.dart';
import 'visit_detail_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final UserModel user;

  const ManagerDashboardScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final List<Map<String, dynamic>> _teamMembers = [];
  final List<Map<String, dynamic>> _pendingAudits = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPendingVisits();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadPendingVisits());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPendingVisits() async {
    try {
      final token = widget.user.accessToken;
      final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/visits?status=PENDING&limit=50');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> items = data is Map ? (data['items'] ?? []) : (data is List ? data : []);
        final parsed = items.map((e) => Map<String, dynamic>.from(e)).toList();
        if (!mounted) return;
        setState(() {
          _pendingAudits.clear();
          _pendingAudits.addAll(parsed);
        });
      }
    } catch (_) {
      // keep existing state on transient network issues
    }
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map application.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching maps: $e')),
      );
    }
  }

  Future<void> _verifyVisit(int index, bool approved) async {
    final item = _pendingAudits[index];
    final visitId = item['id'];
    try {
      final token = widget.user.accessToken;
      final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/visits/$visitId/verify');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'decision': approved ? 'VERIFIED' : 'REJECTED',
          'notes': approved ? 'Verified by supervisor' : 'Flagged by supervisor',
        }),
      ).timeout(const Duration(seconds: 6));
    } catch (_) {
      // ignore
    }

    if (!mounted) return;
    setState(() {
      _pendingAudits.removeAt(index);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved
              ? 'Visit verified & approved for ${item['client_name']}'
              : 'Visit flagged / rejected for ${item['client_name']}'),
          backgroundColor: approved ? AppTheme.cropGreen : AppTheme.alertCrimson,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: const Text('Verification Queue & Field Audit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Chatrooms & Announcements',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatListScreen(currentUser: widget.user),
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
                  builder: (context) => ProfileSettingsScreen(user: widget.user),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.alertCrimson),
            tooltip: 'Sign Out',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const PortalSelectionScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Manager Header Banner (Clickable to open profile)
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileSettingsScreen(user: widget.user),
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
                              widget.user.fullName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim().isNotEmpty
                                  ? widget.user.fullName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim()
                                  : widget.user.username,
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
                              border: Border.all(color: AppTheme.adminSlate.withOpacity(0.3)),
                            ),
                            child: const Text(
                              'REGIONAL MANAGER',
                              style: TextStyle(
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
                          const Expanded(
                            child: Text(
                              'Supervising: Punjab Field Team',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ),
                          const SizedBox(width: 8),
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

              const SizedBox(height: 14),

              // Add Customer Card (Admin Exclusive)
              Card(
                elevation: 0,
                color: AppTheme.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                  side: const BorderSide(color: AppTheme.sageBorder),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.mintBadge,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add, color: AppTheme.botanicalPrimary, size: 20),
                  ),
                  title: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Register farm or dealer client & assign to agronomist', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                  onTap: () => _showAddCustomerDialog(context),
                ),
              ),

              const SizedBox(height: 10),

              // Supervised Employee Accounts Card (Admin can see & change credentials of employees they created)
              Card(
                elevation: 0,
                color: AppTheme.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                  side: const BorderSide(color: AppTheme.sageBorder),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.adminSlateLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.manage_accounts, color: AppTheme.adminSlate, size: 20),
                  ),
                  title: const Text('Supervised Employee Accounts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('View & change credentials for employees created by you', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountDirectoryScreen(currentUser: widget.user),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // Pending Visit Verification Queue (Highest Priority for Manager)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Pending Field Visit Verifications',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.earthAmberLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_pendingAudits.length} Awaiting',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.earthAmber),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_pendingAudits.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                    border: Border.all(color: AppTheme.sageBorder),
                  ),
                  child: const Center(
                    child: Text('All field visits verified! No pending reviews.'),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pendingAudits.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final audit = _pendingAudits[index];
                    final lat = (audit['latitude'] as num).toDouble();
                    final lng = (audit['longitude'] as num).toDouble();
                    return Container(
                      padding: const EdgeInsets.all(14),
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
                                audit['client_name'] as String,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                              ),
                              Text(
                                'By: ${audit['officer']}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.botanicalPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${audit['purpose']} • ${audit['timestamp']}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.cropGreenLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, size: 14, color: AppTheme.cropGreen),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    audit['distance_to_shop'] as String,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.cropGreen),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Realtime Coordinates (Clickable to Google Maps)
                          InkWell(
                            onTap: () => _openGoogleMaps(lat, lng),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.warmOffWhite,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.sageBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 18, color: AppTheme.alertCrimson),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E (±${audit['accuracy']})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.botanicalPrimary,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                        const Text(
                                          'Real-time GPS • Click coordinates to open in Google Maps',
                                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.open_in_new, size: 14, color: AppTheme.textMuted),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Dedicated "Check Location now" button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openGoogleMaps(lat, lng),
                              icon: const Icon(Icons.map, size: 15, color: AppTheme.botanicalPrimary),
                              label: const Text(
                                'Check Location now',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.botanicalPrimary,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.botanicalPrimary),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VisitDetailScreen(visit: audit),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 38),
                                    padding: EdgeInsets.zero,
                                    side: const BorderSide(color: AppTheme.sageBorder),
                                  ),
                                  child: const Text('Inspect Photo', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _verifyVisit(index, false),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 38),
                                    foregroundColor: AppTheme.alertCrimson,
                                    side: const BorderSide(color: AppTheme.alertCrimson),
                                  ),
                                  child: const Text('Flag / Reject', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _verifyVisit(index, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.cropGreen,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 38),
                                  ),
                                  child: const Text('Approve', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 22),

              // Supervised Field Agronomists with Live Location Tracking
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Supervised Field Team',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.cropGreenLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Live Tracking Active',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.cropGreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_teamMembers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                    border: Border.all(color: AppTheme.sageBorder),
                  ),
                  child: const Center(
                    child: Text(
                      'No field agronomists assigned under this manager yet.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ),
                )
              else
                ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _teamMembers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final officer = _teamMembers[index];
                  final officerLat = (officer['latitude'] as num).toDouble();
                  final officerLng = (officer['longitude'] as num).toDouble();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  officer['name'] as String,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                                ),
                                const SizedBox(height: 2),
                                Text(officer['code'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  officer['today_visits'] as String,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.botanicalPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  officer['status'] as String,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.cropGreen),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Live location details
                        InkWell(
                          onTap: () => _openGoogleMaps(officerLat, officerLng),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.warmOffWhite,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.sageBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.my_location, size: 14, color: AppTheme.cropGreen),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${officer['address']} (${officerLat.toStringAsFixed(4)}°, ${officerLng.toStringAsFixed(4)}°)',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.botanicalPrimary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      Text(
                                        officer['last_ping'] as String,
                                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _openGoogleMaps(officerLat, officerLng),
                                  icon: const Icon(Icons.navigation, size: 12),
                                  label: const Text('Check Location now', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 30),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    foregroundColor: AppTheme.botanicalPrimary,
                                    side: const BorderSide(color: AppTheme.botanicalPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
                      'Admin Authority: Register customer. Customer will appear in the territory of the nearest assigned field agronomist.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Customer / Farm Name *',
                        hintText: 'e.g. Haji Tariq Agro Farm',
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
                              if (widget.user.accessToken != null) 'Authorization': 'Bearer ${widget.user.accessToken}',
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
