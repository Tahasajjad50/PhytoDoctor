import 'package:flutter/foundation.dart';

enum Environment { dev, staging, prod }

class AppConfig {
  static const String appName = 'Phyto Doctor';
  static const String appVersion = '1.0.0+1';

  // Environment-specific configuration with compile-time overrides
  // e.g. flutter run --dart-define=API_URL=https://api.phytodoctor.pk
  // Default dev URL points to local PC Wi-Fi IP (192.168.1.15:8000) so both physical
  // mobile phones and the emulator can reach the backend simultaneously.
  static const String _defaultDevUrl = 'http://192.168.1.15:8000';
  static const String _defaultProdUrl = 'https://api.phytodoctor.pk';

  static String get apiBaseUrl {
    const definedUrl = String.fromEnvironment('API_URL');
    if (definedUrl.isNotEmpty) {
      return definedUrl;
    }
    return kReleaseMode ? _defaultProdUrl : _defaultDevUrl;
  }

  static Environment get environment {
    const envStr = String.fromEnvironment('ENV', defaultValue: 'dev');
    switch (envStr.toLowerCase()) {
      case 'prod':
      case 'production':
        return Environment.prod;
      case 'staging':
        return Environment.staging;
      default:
        return Environment.dev;
    }
  }

  // Toggle for offline UI testing when backend server is unreachable
  static bool useMockDataWhenOffline = true;
}
