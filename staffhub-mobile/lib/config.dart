import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// API URL configuration
///
/// **Why "Connection error"?** Usually the app cannot reach the Node API:
/// 1. Backend not running — start `staffhub-api` (e.g. `node src/index.js` or `npm start`) on port 3000.
/// 2. Wrong host — `localhost` on a **phone** or **Android emulator** does not mean your PC.
///    - Android **emulator**: default below uses `10.0.2.2` (special alias to your dev machine).
///    - **Physical phone** (Android/iOS): set your PC LAN IP, e.g. run with
///      `flutter run --dart-define=API_HOST=192.168.1.100`
///    - **iOS Simulator**: `localhost` is OK.
/// 3. Firewall blocking port 3000 on the PC.
class AppConfig {
  /// Full base override: `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000`
  /// (`/api` is appended automatically if missing). Use this on a **physical phone** when 10.0.2.2 is wrong.
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

  /// Base URL for REST API (must end with `/api` — routes are `/api/admin/...`, not `/admin/...`).
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _ensureEndsWithApi(_apiBaseUrlOverride);
    }
    if (_apiHostOverride.isNotEmpty) {
      return 'http://$_apiHostOverride:3000/api';
    }
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Emulator: 10.0.2.2 = host loopback. Real device: use --dart-define=API_HOST=... or API_BASE_URL=...
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  /// Keep in sync with `web/index.html`, AndroidManifest, and AppDelegate if you change the key.
  static const String googleMapsApiKey = 'AIzaSyCnQJLeCz_q2P0ExoNMxP_Qq-na2avqUus';
}
