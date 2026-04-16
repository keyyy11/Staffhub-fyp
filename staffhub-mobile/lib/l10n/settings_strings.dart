/// Teks skrin Tetapan (BM / EN).
class SettingsStrings {
  static const _en = <String, String>{
    'settings_title': 'Settings',
    'language': 'Language',
    'lang_ms': 'Bahasa Melayu',
    'lang_en': 'English',
    'appearance': 'Appearance',
    'theme': 'Theme',
    'theme_dark': 'Dark',
    'theme_light': 'Light',
    'theme_system': 'System',
    'security': 'Security',
    'change_password': 'Change password',
    'current_password': 'Current password',
    'new_password': 'New password',
    'confirm_password': 'Confirm new password',
    'save_password': 'Update password',
    'password_updated': 'Password updated',
    'password_mismatch': 'New passwords do not match',
    'notifications': 'Notifications',
    'notifications_hint': 'In-app alerts use your account. Push notifications can be enabled in a future update.',
    'about': 'About',
    'version': 'Staff Hub mobile',
    'demo_password': 'Not available in demo mode',
    'fill_all': 'Fill all password fields',
  };

  static const _ms = <String, String>{
    'settings_title': 'Tetapan',
    'language': 'Bahasa',
    'lang_ms': 'Bahasa Melayu',
    'lang_en': 'English',
    'appearance': 'Penampilan',
    'theme': 'Tema',
    'theme_dark': 'Gelap',
    'theme_light': 'Terang',
    'theme_system': 'Ikut sistem',
    'security': 'Keselamatan',
    'change_password': 'Tukar kata laluan',
    'current_password': 'Kata laluan semasa',
    'new_password': 'Kata laluan baharu',
    'confirm_password': 'Sahkan kata laluan baharu',
    'save_password': 'Kemas kini kata laluan',
    'password_updated': 'Kata laluan dikemas kini',
    'password_mismatch': 'Kata laluan baharu tidak sepadan',
    'notifications': 'Pemberitahuan',
    'notifications_hint': 'Makluman dalam aplikasi menggunakan akaun anda. Pemberitahan push boleh ditambah kemudian.',
    'about': 'Perihal',
    'version': 'Staff Hub (mudah alih)',
    'demo_password': 'Tidak tersedia dalam mod demo',
    'fill_all': 'Isi semua medan kata laluan',
  };

  static String t(String lang, String key) {
    final m = lang == 'en' ? _en : _ms;
    return m[key] ?? _en[key] ?? key;
  }
}
