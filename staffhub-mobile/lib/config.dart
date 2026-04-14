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
  /// Optional override: `flutter run --dart-define=API_HOST=192.168.x.x` (no `http://`, no port).
  static const String _apiHostOverride = String.fromEnvironment('API_HOST', defaultValue: '');

  /// Base URL for REST API (includes `/api`).
  static String get apiBaseUrl {
    if (_apiHostOverride.isNotEmpty) {
      return 'http://$_apiHostOverride:3000/api';
    }
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Emulator: 10.0.2.2 = host loopback. Real device: use --dart-define=API_HOST=...
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  /// Keep in sync with `web/index.html`, AndroidManifest, and AppDelegate if you change the key.
  static const String googleMapsApiKey = 'AIzaSyCnQJLeCz_q2P0ExoNMxP_Qq-na2avqUus';
}
