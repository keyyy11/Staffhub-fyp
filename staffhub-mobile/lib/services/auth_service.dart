import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/l10n.dart';
import 'api_service.dart';

class LoginResult {
  final bool success;
  final String? errorMessage;
  LoginResult({required this.success, this.errorMessage});
}

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _profileKey = 'user_profile';
  static const _demoKey = 'demo_mode';

  static Future<LoginResult> login(String email, String password) async {
    try {
      final response = await ApiService.login(email, password);
      if (response['success'] == true && response['data'] != null) {
        final token = response['data']['token'] as String;
        final user = response['data']['user'] as Map<String, dynamic>;
        await _saveAuth(token, user);
        return LoginResult(success: true, errorMessage: null);
      }
      return LoginResult(
        success: false,
        errorMessage: response['message'] as String? ?? tr('login_failed'),
      );
    } catch (e) {
      return LoginResult(
        success: false,
        errorMessage: _networkErrorHint(e),
      );
    }
  }

  static String _networkErrorHint(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('TimeoutException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection refused')) {
      return tr('cannot_reach_api_dev');
    }
    return tr('connection_error_ensure_api');
  }

  static Future<LoginResult> forgotPassword(String email) async {
    try {
      final response = await ApiService.forgotPassword(email);
      if (response['success'] == true) {
        return LoginResult(
          success: true,
          errorMessage: response['message'] as String?,
        );
      }
      return LoginResult(
        success: false,
        errorMessage: response['message'] as String? ?? tr('reset_email_failed'),
      );
    } catch (e) {
      return LoginResult(success: false, errorMessage: _networkErrorHint(e));
    }
  }

  static Future<LoginResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await ApiService.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      if (response['success'] == true) {
        return LoginResult(
          success: true,
          errorMessage: response['message'] as String?,
        );
      }
      return LoginResult(
        success: false,
        errorMessage: response['message'] as String? ?? tr('password_reset_failed'),
      );
    } catch (e) {
      return LoginResult(success: false, errorMessage: _networkErrorHint(e));
    }
  }

  static Future<LoginResult> registerSupervisor(
    String? staffId, String name, String email, String password, String supervisorSecret,
  ) async {
    try {
      final response = await ApiService.registerSupervisor(staffId, name, email, password, supervisorSecret);
      if (response['success'] == true && response['data'] != null) {
        final token = response['data']['token'] as String;
        final user = response['data']['user'] as Map<String, dynamic>;
        await _saveAuth(token, user);
        return LoginResult(success: true, errorMessage: null);
      }
      return LoginResult(
        success: false,
        errorMessage: response['message'] as String? ?? tr('supervisor_registration_failed'),
      );
    } catch (e) {
      return LoginResult(success: false, errorMessage: _networkErrorHint(e));
    }
  }

  static Future<LoginResult> registerAdmin(
    String? staffId, String name, String email, String password, String adminSecret,
  ) async {
    try {
      final response = await ApiService.registerAdmin(staffId, name, email, password, adminSecret);
      if (response['success'] == true && response['data'] != null) {
        final token = response['data']['token'] as String;
        final user = response['data']['user'] as Map<String, dynamic>;
        await _saveAuth(token, user);
        return LoginResult(success: true, errorMessage: null);
      }
      return LoginResult(
        success: false,
        errorMessage: response['message'] as String? ?? tr('admin_registration_failed'),
      );
    } catch (e) {
      final msg = e.toString().contains('TimeoutException') || e.toString().contains('SocketException')
          ? tr('cannot_reach_api')
          : tr('connection_error_ensure_api');
      return LoginResult(success: false, errorMessage: msg);
    }
  }

  /// Returns (success, errorMessage). errorMessage is null on success.
  static Future<LoginResult> register(
    String? staffId,
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await ApiService.register(staffId, name, email, password);
      if (response['success'] == true && response['data'] != null) {
        final token = response['data']['token'] as String;
        final user = response['data']['user'] as Map<String, dynamic>;
        await _saveAuth(token, user);
        return LoginResult(success: true, errorMessage: null);
      }
      return LoginResult(
        success: false,
        errorMessage: response['message'] as String? ?? tr('registration_failed'),
      );
    } catch (e) {
      return LoginResult(
        success: false,
        errorMessage: _networkErrorHint(e),
      );
    }
  }

  static Future<void> _saveAuth(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_profileKey);
    await prefs.remove(_demoKey);
  }

  static Future<void> saveProfileLocally(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile));
  }

  static Future<Map<String, dynamic>?> getProfileLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_profileKey);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateStoredUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_demoKey) == true) return true;
    return prefs.containsKey(_tokenKey);
  }

  static Future<bool> isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_demoKey) == true;
  }

  /// Demo mode — browse UI without API
  static Future<void> setDemoMode(String staffId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoKey, true);
    await prefs.setString(_userKey, jsonEncode({
      'staffId': staffId,
      'name': 'Demo User',
      'email': 'demo@staffhub.com',
    }));
  }

  static Future<void> clearDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_demoKey);
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    try {
      return jsonDecode(userJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}
