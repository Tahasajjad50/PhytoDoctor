import 'dart:async';
import 'package:flutter/foundation.dart';
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
      await NativePlatformService.requestNotificationPermission();
      _initialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Init notice: $e');
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
}
