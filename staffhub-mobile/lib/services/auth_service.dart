import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Returns (success, errorMessage). errorMessage is null on success.
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
        errorMessage: response['message'] as String? ?? 'Login failed',
      );
    } catch (e) {
      return LoginResult(
        success: false,
        errorMessage: 'Connection error. Please ensure API is running.',
      );
    }
  }

  static Future<LoginResult> registerAdmin(
    String staffId, String name, String email, String password, String adminSecret,
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
        errorMessage: response['message'] as String? ?? 'Admin registration failed',
      );
    } catch (e) {
      final msg = e.toString().contains('TimeoutException') || e.toString().contains('SocketException')
          ? 'Cannot reach API. Ensure the backend is running (e.g. node index.js) and URL in config.dart is correct.'
          : 'Connection error. Please ensure API is running.';
      return LoginResult(success: false, errorMessage: msg);
    }
  }

  /// Returns (success, errorMessage). errorMessage is null on success.
  static Future<LoginResult> register(
    String staffId,
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
        errorMessage: response['message'] as String? ?? 'Registration failed',
      );
    } catch (e) {
      return LoginResult(
        success: false,
        errorMessage: 'Connection error. Please ensure API is running.',
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
