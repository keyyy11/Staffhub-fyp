import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static Future<Map<String, dynamic>> clockIn(String staffId, double lat, double lng) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance/clock-in'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'staffId': staffId,
        'lat': lat,
        'lng': lng,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> clockOut(String staffId, double lat, double lng) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance/clock-out'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'staffId': staffId,
        'lat': lat,
        'lng': lng,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getWorkplaceInfo() async {
    final response = await http.get(Uri.parse('$baseUrl/attendance/workplace'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getTodayAttendance(String staffId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/attendance/today/$staffId'),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> autoClockOut(String staffId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance/auto-clock-out'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'staffId': staffId}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getMyAttendance(String staffId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/attendance/my/$staffId?limit=30'),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getWorkSchedule() async {
    final response = await http.get(Uri.parse('$baseUrl/staff/work-schedule'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getPayslip(
    String staffId, {
    int? year,
    int? month,
  }) async {
    final q = <String>[];
    if (year != null) q.add('year=$year');
    if (month != null) q.add('month=$month');
    final query = q.isEmpty ? '' : '?${q.join('&')}';
    final response = await http.get(
      Uri.parse('$baseUrl/staff/payslip/$staffId$query'),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getLeaveBalance(String staffId) async {
    final year = DateTime.now().year;
    final response = await http.get(
      Uri.parse('$baseUrl/leave/balance/$staffId?year=$year'),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> applyLeave(
    String staffId,
    String leaveType,
    DateTime startDate,
    DateTime endDate,
    String reason,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/leave/apply'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'staffId': staffId,
        'leaveType': leaveType,
        'startDate': startDate.toIso8601String().split('T')[0],
        'endDate': endDate.toIso8601String().split('T')[0],
        'reason': reason,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getProfile(String staffId) async {
    final response = await http.get(Uri.parse('$baseUrl/profile/$staffId'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProfile(
    String staffId, {
    String? name,
    String? phone,
    String? department,
    String? position,
    String? profileImage,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (department != null) body['department'] = department;
    if (position != null) body['position'] = position;
    if (profileImage != null) body['profileImage'] = profileImage;

    final response = await http.put(
      Uri.parse('$baseUrl/profile/$staffId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getMyLeaveRequests(String staffId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/leave/requests/$staffId?limit=20'),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static const _timeout = Duration(seconds: 15);

  static Future<Map<String, dynamic>> registerAdmin(
    String staffId, String name, String email, String password, String adminSecret,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/register-admin'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'staffId': staffId, 'name': name, 'email': email, 'password': password,
            'adminSecret': adminSecret,
          }),
        )
        .timeout(_timeout);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _adminRequest(String method, String path, {Map<String, dynamic>? body}) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse('$baseUrl$path');
    http.Response response;
    if (method == 'GET') {
      response = await http.get(uri, headers: headers);
    } else if (method == 'PUT' && body != null) {
      response = await http.put(uri, headers: headers, body: jsonEncode(body));
    } else if (method == 'POST' && body != null) {
      response = await http.post(uri, headers: headers, body: jsonEncode(body));
    } else {
      throw Exception('Unsupported method');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getAttendanceReport({String? startDate, String? endDate, String? staffId}) async {
    var path = '/admin/attendance-report?';
    if (startDate != null) path += 'startDate=$startDate&';
    if (endDate != null) path += 'endDate=$endDate&';
    if (staffId != null) path += 'staffId=$staffId';
    return _adminRequest('GET', path);
  }

  static Future<Map<String, dynamic>> getStaffList() async {
    return _adminRequest('GET', '/admin/staff-list');
  }

  static Future<Map<String, dynamic>> registerStaffByAdmin(
    String staffId, String name, String email, String password,
  ) async {
    return _adminRequest('POST', '/admin/register-staff', body: {
      'staffId': staffId,
      'name': name,
      'email': email,
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> updateStaffSalary(String staffId, double salary) async {
    return _adminRequest('PUT', '/admin/staff/$staffId/salary', body: {'salary': salary});
  }

  static Future<Map<String, dynamic>> getAdminConfig() async {
    return _adminRequest('GET', '/admin/config');
  }

  static Future<Map<String, dynamic>> getAdminLeaveRequests({String? status}) async {
    var path = '/admin/leave-requests';
    if (status != null) path += '?status=${Uri.encodeComponent(status)}';
    return _adminRequest('GET', path);
  }

  static Future<Map<String, dynamic>> updateLeaveRequestStatus(String id, String status) async {
    return _adminRequest('PUT', '/admin/leave-requests/$id', body: {'status': status});
  }

  static Future<Map<String, dynamic>> getAdminPayslipRecords({String? staffId, int? year, int? month}) async {
    final q = <String>[];
    if (staffId != null) q.add('staffId=${Uri.encodeComponent(staffId)}');
    if (year != null) q.add('year=$year');
    if (month != null) q.add('month=$month');
    final query = q.isEmpty ? '' : '?${q.join('&')}';
    return _adminRequest('GET', '/admin/payslip-records$query');
  }

  static Future<Map<String, dynamic>> getAdminProfile() async {
    return _adminRequest('GET', '/admin/me');
  }

  static Future<Map<String, dynamic>> updateAdminProfile({
    String? name,
    String? phone,
    String? department,
    String? position,
    String? profileImage,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (department != null) body['department'] = department;
    if (position != null) body['position'] = position;
    if (profileImage != null) body['profileImage'] = profileImage;
    return _adminRequest('PUT', '/admin/me', body: body);
  }

  static Future<Map<String, dynamic>> getStaffDisciplineMetrics(String staffId, {int days = 90}) async {
    final path = '/admin/staff/${Uri.encodeComponent(staffId)}/discipline-metrics?days=$days';
    return _adminRequest('GET', path);
  }

  static Future<Map<String, dynamic>> listAdminWarnings({String? staffId}) async {
    var path = '/admin/warnings';
    if (staffId != null) path += '?staffId=${Uri.encodeComponent(staffId)}';
    return _adminRequest('GET', path);
  }

  static Future<Map<String, dynamic>> createAdminWarning({
    required String staffId,
    required String category,
    required String notes,
  }) async {
    return _adminRequest('POST', '/admin/warnings', body: {
      'staffId': staffId,
      'category': category,
      'notes': notes,
    });
  }

  static Future<Map<String, dynamic>> getMyWarnings() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.get(
      Uri.parse('$baseUrl/staff/warnings'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> upsertAdminPayslipRecord({
    required String staffId,
    required int year,
    required int month,
    required double netPay,
    double? grossPay,
    String? remarks,
  }) async {
    return _adminRequest('POST', '/admin/payslip-record', body: {
      'staffId': staffId,
      'year': year,
      'month': month,
      'netPay': netPay,
      if (grossPay != null) 'grossPay': grossPay,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
  }

  static Future<Map<String, dynamic>> register(
    String staffId,
    String name,
    String email,
    String password,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'staffId': staffId,
            'name': name,
            'email': email,
            'password': password,
          }),
        )
        .timeout(_timeout);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
