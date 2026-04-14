/// API URL configuration
///
/// - Web / Chrome: http://localhost:3000
/// - Android Emulator: http://10.0.2.2:3000
/// - iOS Simulator: http://localhost:3000
/// - Physical device: use computer IP (e.g. http://192.168.1.100:3000)
class AppConfig {
  static const String apiBaseUrl = 'http://localhost:3000/api';

  /// Keep in sync with `web/index.html`, AndroidManifest, and AppDelegate if you change the key.
  static const String googleMapsApiKey = 'AIzaSyCnQJLeCz_q2P0ExoNMxP_Qq-na2avqUus';
}
