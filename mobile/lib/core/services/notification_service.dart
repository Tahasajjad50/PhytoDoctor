import 'dart:async';
import 'package:flutter/foundation.dart';
import 'app_update_service.dart';
import 'native_platform_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;

  /// Requests notification permission on Android 13+ (POST_NOTIFICATIONS)
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      NativePlatformService.setNotificationTapHandler(_handleNotificationPayload);
      await NativePlatformService.requestNotificationPermission();
      _initialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Init notice: $e');
    }
  }

  /// Checks if the app was launched by tapping a notification and handles it
  Future<void> checkInitialLaunchPayload() async {
    try {
      final payload = await NativePlatformService.getInitialNotificationPayload();
      if (payload != null && payload.isNotEmpty) {
        _handleNotificationPayload(payload);
      }
    } catch (e) {
      debugPrint('[NotificationService] Initial payload error: $e');
    }
  }

  void _handleNotificationPayload(String payload) {
    if (payload == 'app_update') {
      AppUpdateService.handleUpdateNotificationTap();
    }
  }

  /// Displays an Android system notification in the notification bar
  Future<void> showMessageNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
      await NativePlatformService.showNotification(
        title: title,
        body: body,
        payload: payload,
        id: id ?? (DateTime.now().millisecondsSinceEpoch % 100000),
      );
    } catch (e) {
      debugPrint('[NotificationService] Notification display error: $e');
    }
  }

  /// Shows or updates a download progress notification in the Android notification bar
  Future<void> showProgressNotification({
    required String title,
    required String body,
    int id = 999998,
    int progress = 0,
    int maxProgress = 100,
    bool ongoing = false,
  }) async {
    try {
      await NativePlatformService.showProgressNotification(
        title: title,
        body: body,
        id: id,
        progress: progress,
        maxProgress: maxProgress,
        ongoing: ongoing,
      );
    } catch (e) {
      debugPrint('[NotificationService] Progress notification error: $e');
    }
  }
}
