import 'package:flutter/services.dart';

class NativePlatformService {
  static const _channel = MethodChannel('com.phytodoctor.fieldapp/native');

  /// Automatically requests Camera and Location runtime permissions from the Android OS
  static Future<bool> requestPermissions() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestPermissions');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if Camera and Location permissions are currently granted
  static Future<Map<String, bool>> checkPermissions() async {
    try {
      final res = await _channel.invokeMapMethod<String, bool>('checkPermissions');
      return res ?? {'camera': false, 'location': false};
    } catch (_) {
      return {'camera': false, 'location': false};
    }
  }

  /// Obtains live GNSS GPS location directly from Android hardware sensor
  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getCurrentLocation');
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Opens the native device hardware camera to capture a real photo
  /// Returns the absolute local file path of the captured photo, or null if cancelled
  static Future<String?> capturePhoto() async {
    try {
      final res = await _channel.invokeMethod<String>('capturePhoto');
      return res;
    } catch (e) {
      // If camera permission was missing, attempt auto-request and retry once
      final requested = await requestPermissions();
      if (requested) {
        try {
          return await _channel.invokeMethod<String>('capturePhoto');
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  /// Invokes the native Android/OS share sheet (WhatsApp, Gmail, SMS, etc.)
  static Future<bool> share({
    required String text,
    String? subject,
    String title = 'Share Credentials via',
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('shareText', {
        'text': text,
        'subject': subject,
        'title': title,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Invokes the native Android/OS share sheet for files (Excel reports, PDFs, etc.)
  static Future<bool> shareFile({
    required String filePath,
    String mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    String? subject,
    String title = 'Share Audit Report',
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('shareFile', {
        'filePath': filePath,
        'mimeType': mimeType,
        'subject': subject,
        'title': title,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Displays an Android system notification bar notification
  static Future<bool> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('showNotification', {
        'title': title,
        'body': body,
        'payload': payload ?? '',
        if (id != null) 'id': id,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests notification permission on Android 13+ (POST_NOTIFICATIONS)
  static Future<bool> requestNotificationPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestNotificationPermission');
      return res ?? true;
    } catch (_) {
      return false;
    }
  }
}

