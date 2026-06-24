import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// API URL configuration
///
/// **Production (recommended):** deploy `staffhub-api` to Render/Railway, then build with:
/// `flutter build apk --dart-define=PRODUCTION_API_URL=https://your-api.onrender.com/api`
///
/// **Local dev:** start `staffhub-api` on port 3000.
/// - Android emulator: `10.0.2.2`
/// - Physical phone: `flutter run --dart-define=API_HOST=192.168.x.x`
class AppConfig {
  /// Cloud API (no local IP needed). Set when building release APK/IPA.
  static const String _productionApiUrl = String.fromEnvironment('PRODUCTION_API_URL', defaultValue: '');

  /// Full base override: `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000`
  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Optional override: `flutter run --dart-define=API_HOST=192.168.x.x` (no `http://`, no port).
  static const String _apiHostOverride = String.fromEnvironment('API_HOST', defaultValue: '');

  static String _ensureEndsWithApi(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (!u.endsWith('/api')) {
      u = '$u/api';
    }
    return u;
  }

  /// Base URL from compile-time config (used when no custom URL in Settings).
  static String get defaultApiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _ensureEndsWithApi(_apiBaseUrlOverride);
    }
    if (_productionApiUrl.isNotEmpty) {
      return _ensureEndsWithApi(_productionApiUrl);
    }
    if (_apiHostOverride.isNotEmpty) {
      return 'http://$_apiHostOverride:3000/api';
    }
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  /// Active API base — prefers URL saved in app Settings.
  static String get apiBaseUrl => defaultApiBaseUrl;

  /// Keep in sync with `web/index.html`, AndroidManifest, and AppDelegate if you change the key.
  static const String googleMapsApiKey = 'AIzaSyCnQJLeCz_q2P0ExoNMxP_Qq-na2avqUus';
}
