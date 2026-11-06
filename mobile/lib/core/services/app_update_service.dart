import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/app_version_model.dart';
import '../theme/app_theme.dart';
import 'auth_service.dart';

class AppUpdateService {
  final http.Client _client;
  final String _baseUrl;

  AppUpdateService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AuthService.defaultBaseUrl;

  Future<AppVersionModel?> checkVersion() async {
    try {
      final url = Uri.parse('$_baseUrl/api/v1/system/version');
      final res = await _client.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return AppVersionModel.fromJson(data);
      }
    } catch (_) {
      // Offline or network error: allow offline usage if cached, but fail-open gracefully
    }
    return null;
  }

  static bool isUpdateRequired(AppVersionModel info) {
    if (!info.forceUpdate) return false;
    if (AppConfig.buildNumber < info.minRequiredBuildNumber) return true;
    if (_isVersionLower(AppConfig.appVersion, info.latestVersion)) return true;
    return false;
  }

  static bool _isVersionLower(String current, String latest) {
    try {
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      while (cParts.length < 3) cParts.add(0);
      while (lParts.length < 3) lParts.add(0);
      for (int i = 0; i < 3; i++) {
        if (cParts[i] < lParts[i]) return true;
        if (cParts[i] > lParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Checks version and immediately presents a blocking, un-dismissible popup if update is required.
  /// Returns `true` if update is required and dialog is displayed.
  static Future<bool> checkAndPromptUpdate(BuildContext context) async {
    final service = AppUpdateService();
    final info = await service.checkVersion();

    if (info != null && isUpdateRequired(info)) {
      if (!context.mounted) return true;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) {
          return PopScope(
            canPop: false, // Prevents Android back button bypass
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.botanicalPrimary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update,
                        color: AppTheme.botanicalPrimary,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    info.title.isNotEmpty ? info.title : 'App Update Required',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your installed app (v${AppConfig.appVersion}, build ${AppConfig.buildNumber}) is out of date. To maintain database security and field sync, update to v${info.latestVersion} to proceed.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (info.releaseNotes.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.sageLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.sageBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "What's New in This Version:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.botanicalPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            info.releaseNotes,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMain,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            try {
                              SystemNavigator.pop();
                              exit(0);
                            } catch (_) {
                              exit(0);
                            }
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Close App'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.adminSlate,
                            side: const BorderSide(color: AppTheme.sageBorder, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(info.downloadUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.system_update_alt, size: 18),
                          label: const Text('Update Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.botanicalPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tap "Update Now" to download the latest APK in your browser. Tap "Close App" to exit.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return true;
    }
    return false;
  }
}
