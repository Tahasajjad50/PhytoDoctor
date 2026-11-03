import 'native_platform_service.dart';

class NativeShareService {
  static Future<bool> share({
    required String text,
    String? subject,
    String title = 'Share Credentials via',
  }) {
    return NativePlatformService.share(
      text: text,
      subject: subject,
      title: title,
    );
  }
}
