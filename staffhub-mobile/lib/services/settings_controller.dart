import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema, bahasa & pilihan tetapan app (singleton).
class SettingsController extends ChangeNotifier {
  SettingsController._();
  static final SettingsController instance = SettingsController._();

  static const _kTheme = 'settings_theme_mode';
  static const _kLocale = 'settings_locale';

  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('ms');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get langCode => _locale.languageCode;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString(_kTheme);
    if (t == 'light') {
      _themeMode = ThemeMode.light;
    } else if (t == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.dark;
    }
    final l = p.getString(_kLocale);
    _locale = l == 'en' ? const Locale('en') : const Locale('ms');
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final p = await SharedPreferences.getInstance();
    final s = mode == ThemeMode.light ? 'light' : mode == ThemeMode.system ? 'system' : 'dark';
    await p.setString(_kTheme, s);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocale, locale.languageCode);
    notifyListeners();
  }
}
