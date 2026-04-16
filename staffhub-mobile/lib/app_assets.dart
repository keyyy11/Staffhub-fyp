/// Central asset paths for Staff Hub branding.
abstract final class AppAssets {
  AppAssets._();

  /// Path must not start with `assets/` — on Flutter Web the engine prepends `assets/`,
  /// which would otherwise produce a broken `assets/assets/...` URL.
  static const String staffhubLogo = 'images/logo.png';
}
