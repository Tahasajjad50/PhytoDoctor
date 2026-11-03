import 'package:flutter/foundation.dart';

enum Environment { dev, staging, prod }

class AppConfig {
  static const String appName = 'Phyto Doctor';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;

  // Environment-specific configuration with compile-time overrides
  // e.g. flutter run --dart-define=API_URL=https://api.phytodoctor.pk
  // Production Render Cloud API URL:
  static const String _defaultCloudUrl = 'https://phytodoctor-api.onrender.com';
  static const String _defaultDevUrl = 'https://phytodoctor-api.onrender.com';
  static const String _defaultProdUrl = 'https://phytodoctor-api.onrender.com';

  static String get apiBaseUrl {
    const definedUrl = String.fromEnvironment('API_URL');
    if (definedUrl.isNotEmpty) {
      return definedUrl;
    }
    return _defaultCloudUrl;
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
