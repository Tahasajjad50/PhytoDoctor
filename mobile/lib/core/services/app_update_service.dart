import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart' show appNavigatorKey;
import '../config/app_config.dart';
import '../models/app_version_model.dart';
import '../theme/app_theme.dart';
import 'auth_service.dart';
import 'native_platform_service.dart';
import 'notification_service.dart';

class AppUpdateService {
  static bool _isDialogOpen = false;
  static bool _notifiedUpdate = false;
  static bool _isDownloading = false;
  static AppVersionModel? _latestVersionInfo;
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
        final info = AppVersionModel.fromJson(data);
        _latestVersionInfo = info;
        return info;
      }
    } catch (_) {
      // Offline or network error: allow offline usage if cached, but fail-open gracefully
    }
    return null;
  }

  /// Called when the user taps the "PhytoDoctor Update" Android notification.
  /// Immediately starts downloading the latest APK and launches the installer.
  static Future<void> handleUpdateNotificationTap() async {
    if (_isDownloading) return;
    final info = _latestVersionInfo ?? await AppUpdateService().checkVersion();
    if (info == null || info.downloadUrl.isEmpty) return;

    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await downloadAndInstallUpdate(ctx, info);
    } else {
      // Fallback if navigator context is not ready yet
      final uri = Uri.parse(info.downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Downloads the APK with live progress UI + notification bar progress, then triggers Android package installer.
  static Future<void> downloadAndInstallUpdate(
    BuildContext context,
    AppVersionModel info,
  ) async {
    if (_isDownloading) return;
    _isDownloading = true;

    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('Connecting to update server...');
    final errorNotifier = ValueNotifier<String?>(null);
    bool dialogVisible = false;

    if (context.mounted) {
      dialogVisible = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (progressCtx) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.downloading_rounded, color: AppTheme.botanicalPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Updating to v${info.latestVersion}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: ValueListenableBuilder<String?>(
                valueListenable: errorNotifier,
                builder: (_, errorMsg, __) {
                  if (errorMsg != null) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          errorMsg,
                          style: const TextStyle(fontSize: 13, color: AppTheme.alertCrimson),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                dialogVisible = false;
                                Navigator.of(progressCtx).pop();
                              },
                              child: const Text('Close'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                final uri = Uri.parse(info.downloadUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.botanicalPrimary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Open Browser'),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ValueListenableBuilder<double>(
                        valueListenable: progressNotifier,
                        builder: (_, value, __) {
                          final pct = (value * 100).clamp(0, 100).toStringAsFixed(0);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LinearProgressIndicator(
                                value: value > 0 ? value : null,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                                backgroundColor: AppTheme.sageLight,
                                color: AppTheme.botanicalPrimary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '$pct%',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.botanicalPrimary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<String>(
                        valueListenable: statusNotifier,
                        builder: (_, status, __) => Text(
                          status,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ).then((_) => dialogVisible = false);
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      Uri currentUri = Uri.parse(info.downloadUrl);
      HttpClientResponse? response;
      for (int hop = 0; hop < 10; hop++) {
        final req = await client.getUrl(currentUri);
        req.followRedirects = false;
        req.headers.set(HttpHeaders.userAgentHeader, 'PhytoDoctor-Android/${AppConfig.appVersion}');
        final res = await req.close();
        if (res.isRedirect || (res.statusCode >= 300 && res.statusCode < 400)) {
          final loc = res.headers.value(HttpHeaders.locationHeader);
          await res.drain<void>();
          if (loc == null || loc.isEmpty) break;
          currentUri = currentUri.resolve(loc);
          continue;
        }
        response = res;
        break;
      }

      if (response == null || response.statusCode != 200) {
        throw Exception('Download failed (HTTP ${response?.statusCode ?? "unknown"})');
      }

      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/PhytoDoctor-update.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }
      final sink = apkFile.openWrite();

      final totalBytes = response.contentLength;
      int receivedBytes = 0;
      int lastNotifiedPct = -1;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final fraction = receivedBytes / totalBytes;
          progressNotifier.value = fraction;
          final mbDone = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
          statusNotifier.value = 'Downloading APK ($mbDone / $mbTotal MB)...';
          final pct = (fraction * 100).round();
          if (pct != lastNotifiedPct && (pct % 5 == 0 || pct == 100)) {
            lastNotifiedPct = pct;
            NotificationService().showProgressNotification(
              title: 'Downloading PhytoDoctor v${info.latestVersion}',
              body: '$mbDone MB / $mbTotal MB ($pct%)',
              progress: pct,
              maxProgress: 100,
              ongoing: pct < 100,
            );
          }
        } else {
          final mbDone = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          statusNotifier.value = 'Downloading APK ($mbDone MB)...';
        }
      }

      await sink.flush();
      await sink.close();

      if (!await apkFile.exists() || await apkFile.length() < 100000) {
        throw Exception('Downloaded APK is incomplete.');
      }

      progressNotifier.value = 1.0;
      statusNotifier.value = 'Download complete. Launching Android installer...';
      await NotificationService().showProgressNotification(
        title: 'PhytoDoctor v${info.latestVersion} Ready',
        body: 'Download complete. Starting installer...',
        progress: 100,
        maxProgress: 100,
        ongoing: false,
      );

      final installRes = await NativePlatformService.installApk(apkFile.path);
      final needsPermission = installRes['needsPermission'] == true;
      if (needsPermission) {
        errorNotifier.value =
            'Please enable "Allow from this source" in Android Settings. Installation will start automatically once enabled.';
      } else if (dialogVisible && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      errorNotifier.value = 'Could not download/install automatically: $e';
      await NotificationService().showProgressNotification(
        title: 'PhytoDoctor Update Failed',
        body: 'Tap Update Now inside the app to retry.',
        ongoing: false,
      );
    } finally {
      client.close(force: true);
      _isDownloading = false;
    }
  }

  static bool isUpdateRequired(AppVersionModel info) {
    if (!info.forceUpdate) return false;
    if (AppConfig.buildNumber < info.minRequiredBuildNumber) return true;
    if (AppConfig.buildNumber < info.latestBuildNumber) return true;
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

  /// Checks version and presents an update popup if the installed version is older.
  static Future<bool> checkAndPromptUpdate(BuildContext context) async {
    if (_isDialogOpen) return true;
    final service = AppUpdateService();
    final info = await service.checkVersion();

    if (info != null && isUpdateRequired(info)) {
      if (!_notifiedUpdate) {
        _notifiedUpdate = true;
        NotificationService().showMessageNotification(
          title: 'PhytoDoctor Update v${info.latestVersion}',
          body: 'New version v${info.latestVersion} available. Tap to update.',
          payload: 'app_update',
          id: 999999,
        );
      }
      if (!context.mounted) return true;
      _isDialogOpen = true;
      try {
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
                    'Installed: v${AppConfig.appVersion} (B${AppConfig.buildNumber})\nLatest: v${info.latestVersion} (B${info.latestBuildNumber})',
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
                            await downloadAndInstallUpdate(dialogCtx, info);
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
                ],
              ),
            ),
          );
        },
      );
      } finally {
        _isDialogOpen = false;
      }
      return true;
    }
    return false;
  }
}
