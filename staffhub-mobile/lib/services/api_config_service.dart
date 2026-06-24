import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// Runtime API URL — change in Settings without rebuilding APK.
class ApiConfigService extends ChangeNotifier {
  ApiConfigService._();
  static final ApiConfigService instance = ApiConfigService._();

  static const _kApiUrl = 'api_base_url';

  String? _customBaseUrl;

  String get baseUrl =>
      (_customBaseUrl != null && _customBaseUrl!.isNotEmpty)
          ? _customBaseUrl!
          : AppConfig.defaultApiBaseUrl;

  /// Raw saved value for display in settings (host or full URL).
  String get displayValue => _customBaseUrl ?? '';

  bool get hasCustomUrl => _customBaseUrl != null && _customBaseUrl!.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _customBaseUrl = prefs.getString(_kApiUrl);
    notifyListeners();
  }

  /// Accepts IP, host:port, or full URL (http/https). Normalizes to .../api
  static String normalizeServerInput(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';

    if (!s.contains('://')) {
      if (s.contains(':')) {
        return _ensureEndsWithApi('http://$s');
      }
      return _ensureEndsWithApi('http://$s:3000');
    }

    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) {
      throw FormatException('Invalid server address');
    }

    final port = uri.hasPort
        ? uri.port
        : (uri.scheme == 'https' ? 443 : 3000);

    var path = uri.path;
    if (path.isEmpty || path == '/') {
      path = '/api';
    } else {
      path = _ensureEndsWithApi('http://x$path').replaceFirst('http://x', '');
    }

    if (uri.scheme == 'https' && port == 443) {
      return 'https://${uri.host}$path';
    }
    return '${uri.scheme}://${uri.host}:$port$path';
  }

  static String _ensureEndsWithApi(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (!u.endsWith('/api')) u = '$u/api';
    return u;
  }

  Future<void> saveFromInput(String input) async {
    final normalized = normalizeServerInput(input);
    _customBaseUrl = normalized.isEmpty ? null : normalized;
    final prefs = await SharedPreferences.getInstance();
    if (_customBaseUrl == null) {
      await prefs.remove(_kApiUrl);
    } else {
      await prefs.setString(_kApiUrl, _customBaseUrl!);
    }
    notifyListeners();
  }

  Future<void> clearCustom() async {
    _customBaseUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kApiUrl);
    notifyListeners();
  }
}
