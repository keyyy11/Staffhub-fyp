import 'package:flutter/material.dart';

import '../services/settings_controller.dart';
import 'app_strings.dart';

/// Translate [key] using the current locale from [SettingsController].
String tr(String key, [Map<String, String>? args]) {
  return AppStrings.t(SettingsController.instance.langCode, key, args);
}

/// Adds locale-change listener so widgets rebuild when language changes.
mixin L10nMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    SettingsController.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    SettingsController.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  /// Instance helper — same as top-level [tr].
  String tr(String key, [Map<String, String>? args]) {
    return AppStrings.t(SettingsController.instance.langCode, key, args);
  }
}
