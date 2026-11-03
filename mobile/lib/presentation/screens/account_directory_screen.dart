import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class AccountDirectoryScreen extends StatefulWidget {
  final UserModel currentUser;

  const AccountDirectoryScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<AccountDirectoryScreen> createState() => _AccountDirectoryScreenState();
}

class _AccountDirectoryScreenState extends State<AccountDirectoryScreen> {
  List<CreatedAccountModel> _accounts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final Set<String> _revealedPasswords = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = widget.currentUser.accessToken;
      final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/users/created-accounts');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        final parsed = list.map((item) => CreatedAccountModel.fromJson(item as Map<String, dynamic>)).toList();
        if (!mounted) return;
        setState(() {
          _accounts = parsed;
          _isLoading = false;
        });
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Failed to load accounts (${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _shareAccountCredentials(CreatedAccountModel account) {
    final portal = account.isManager ? 'Admin / Manager Portal' : 'Field Employee Portal';
    final password = account.loginPassword ?? 'Contact Admin for reset';
    final shareText = '''
PhytoDoctor App Access Credentials
Portal: $portal
Role: ${account.role}
Name: ${account.fullName}
Username: ${account.username}
Email: ${account.email}
Password: $password
Phone: ${account.phone ?? 'N/A'}
Server: ${AuthService.defaultBaseUrl}
''';

    Clipboard.setData(ClipboardData(text: shareText.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Credentials for ${account.fullName} copied to clipboard!'),
        backgroundColor: AppTheme.cropGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showChangeCredentialsDialog(CreatedAccountModel account) {
    final nameCtrl = TextEditingController(text: account.fullName);
    final userCtrl = TextEditingController(text: account.username);
    final emailCtrl = TextEditingController(text: account.email);
    final phoneCtrl = TextEditingController(text: account.phone ?? '');
    final desigCtrl = TextEditingController(text: account.designation ?? '');
    final pwdCtrl = TextEditingController();
    bool obscurePassword = true;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.mintBadge,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.vpn_key, color: AppTheme.botanicalPrimary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Change Credentials',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Updating login details for ${account.fullName} (${account.role})',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.alternate_email, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: desigCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Designation / Region',
                          prefixIcon: Icon(Icons.work, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 6),
                      const Text(
                        'Set New Password (Leave blank to keep unchanged)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.botanicalPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: pwdCtrl,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off, size: 18),
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
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
                          if (nameCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name, username, and email are required.')),
                            );
                            return;
                          }

                          if (pwdCtrl.text.isNotEmpty && pwdCtrl.text.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password must be at least 6 characters.')),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final token = widget.currentUser.accessToken;
                            final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/users/${account.id}/credentials');
                            final Map<String, dynamic> body = {
                              'full_name': nameCtrl.text.trim(),
                              'username': userCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                              'designation': desigCtrl.text.trim(),
                              if (pwdCtrl.text.isNotEmpty) 'password': pwdCtrl.text,
                            };
                            final res = await http.put(
                              url,
                              headers: {
                                'Content-Type': 'application/json',
                                'Accept': 'application/json',
                                if (token != null) 'Authorization': 'Bearer $token',
                              },
                              body: jsonEncode(body),
                            ).timeout(const Duration(seconds: 10));

                            if (res.statusCode != 200) {
                              final err = jsonDecode(res.body);
                              throw Exception(err['detail'] ?? 'Failed to update credentials (${res.statusCode})');
                            }

                            if (!mounted) return;
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Credentials for ${userCtrl.text} updated successfully!'),
                                backgroundColor: AppTheme.cropGreen,
                              ),
                            );
                            _loadAccounts();
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
                                backgroundColor: AppTheme.alertCrimson,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.botanicalPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Credentials'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCEO = widget.currentUser.isOwner;

    final filteredAccounts = _accounts.where((acc) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return acc.fullName.toLowerCase().contains(q) ||
          acc.username.toLowerCase().contains(q) ||
          acc.email.toLowerCase().contains(q) ||
          acc.role.toLowerCase().contains(q) ||
          (acc.createdByName?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: Text(
          isCEO ? 'Staff & Admin Accounts Directory' : 'Supervised Employee Accounts',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAccounts,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scope Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isCEO ? AppTheme.adminSlateLight : AppTheme.cropGreenLight,
              child: Row(
                children: [
                  Icon(
                    isCEO ? Icons.verified_user : Icons.supervised_user_circle,
                    size: 18,
                    color: isCEO ? AppTheme.adminSlate : AppTheme.botanicalPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCEO
                          ? 'CEO Executive Access: Full visibility of all accounts, which admin created them, creation dates, and credentials.'
                          : 'Admin Console: Viewing & managing credentials for employees created by you.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCEO ? AppTheme.adminSlate : AppTheme.botanicalPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by employee/admin name, username, or role...',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.sageBorder),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),

            // Accounts List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 36, color: AppTheme.alertCrimson),
                                const SizedBox(height: 10),
                                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 14),
                                ElevatedButton(
                                  onPressed: _loadAccounts,
                                  child: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredAccounts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text(
                                    _searchQuery.isNotEmpty ? 'No accounts match "$_searchQuery"' : 'No accounts created yet.',
                                    style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredAccounts.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final acc = filteredAccounts[index];
                                final isPasswordRevealed = _revealedPasswords.contains(acc.id);
                                final isManager = acc.isManager;

                                return Card(
                                  elevation: 0,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                                    side: const BorderSide(color: AppTheme.sageBorder),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Name & Role Badge
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: isManager ? AppTheme.adminSlateLight : AppTheme.mintBadge,
                                              child: Icon(
                                                isManager ? Icons.security : Icons.person,
                                                color: isManager ? AppTheme.adminSlate : AppTheme.botanicalPrimary,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    acc.fullName,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppTheme.textMain,
                                                    ),
                                                  ),
                                                  if (acc.designation != null && acc.designation!.isNotEmpty)
                                                    Text(
                                                      acc.designation!,
                                                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isManager ? AppTheme.adminSlateLight : AppTheme.cropGreenLight,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: isManager
                                                      ? AppTheme.adminSlate.withOpacity(0.3)
                                                      : AppTheme.cropGreen.withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                isManager ? 'ADMIN' : 'EMPLOYEE',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: isManager ? AppTheme.adminSlate : AppTheme.cropGreen,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),
                                        const Divider(height: 1),
                                        const SizedBox(height: 10),

                                        // Provenance info: Creator and Date
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.warmOffWhite,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.person_pin, size: 14, color: AppTheme.textMuted),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Created By: ',
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      acc.createdByName ?? 'System Administrator',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 11, color: AppTheme.botanicalPrimary, fontWeight: FontWeight.w700),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.calendar_today, size: 14, color: AppTheme.textMuted),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Created On: ',
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      '${acc.createdAt.day.toString().padLeft(2, '0')}/${acc.createdAt.month.toString().padLeft(2, '0')}/${acc.createdAt.year} at ${acc.createdAt.hour.toString().padLeft(2, '0')}:${acc.createdAt.minute.toString().padLeft(2, '0')}',
                                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 10),

                                        // Login Credentials Box
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.sageBorder),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text(
                                                    'Login Credentials',
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      InkWell(
                                                        onTap: () {
                                                          setState(() {
                                                            if (isPasswordRevealed) {
                                                              _revealedPasswords.remove(acc.id);
                                                            } else {
                                                              _revealedPasswords.add(acc.id);
                                                            }
                                                          });
                                                        },
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              isPasswordRevealed ? Icons.visibility_off : Icons.visibility,
                                                              size: 14,
                                                              color: AppTheme.botanicalPrimary,
                                                            ),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              isPasswordRevealed ? 'Hide' : 'Reveal',
                                                              style: const TextStyle(fontSize: 11, color: AppTheme.botanicalPrimary, fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      InkWell(
                                                        onTap: () => _shareAccountCredentials(acc),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: const [
                                                            Icon(Icons.share, size: 14, color: AppTheme.botanicalPrimary),
                                                            SizedBox(width: 3),
                                                            Text(
                                                              'Share',
                                                              style: TextStyle(fontSize: 11, color: AppTheme.botanicalPrimary, fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Username: ${acc.username}',
                                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                                              ),
                                              Text(
                                                'Email: ${acc.email}',
                                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.textMuted),
                                              ),
                                              Text(
                                                'Password: ${isPasswordRevealed ? (acc.loginPassword ?? "••••••••") : "••••••••"}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontFamily: 'monospace',
                                                  fontWeight: FontWeight.bold,
                                                  color: isPasswordRevealed ? AppTheme.alertCrimson : AppTheme.textMain,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 12),

                                        // Action Button: Change Credentials
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () => _showChangeCredentialsDialog(acc),
                                            icon: const Icon(Icons.edit_note, size: 16, color: AppTheme.botanicalPrimary),
                                            label: const Text(
                                              'Change Credentials',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.botanicalPrimary),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: AppTheme.botanicalPrimary),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
