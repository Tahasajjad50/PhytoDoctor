import 'package:flutter/services.dart';

class NativeShareService {
  static const _channel = MethodChannel('com.phytodoctor.fieldapp/share');

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
}

