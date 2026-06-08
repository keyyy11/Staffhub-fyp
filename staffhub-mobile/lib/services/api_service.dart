import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static const Duration _timeout = Duration(seconds: 15);

  /// Parses JSON error/success bodies even when HTTP status is 4xx; avoids decode throws on HTML 404.
  static Map<String, dynamic> _parseApiJson(http.Response response) {
    final raw = response.body.trim();
    if (raw.isEmpty) {
      return {
        'success': false,
        'message': 'Empty response (HTTP ${response.statusCode}). Ensure staffhub-api is running with the latest code.',
      };
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'success': false, 'message': 'Unexpected response from server'};
    } catch (_) {
      final code = response.statusCode;
      final hint404 = code == 404
          ? ' API path not found (404). Restart staffhub-api with the latest code, '
              'and ensure the base URL includes /api (e.g. http://10.0.2.2:3000/api). '
              'On a physical phone use: flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:3000'
          : '';
      return {
        'success': false,
        'message': 'Non-JSON response (HTTP $code).$hint404 '
            'Restart the API or open DevTools → Response to inspect.',
      };
    }
  }

  static Future<Map<String, dynamic>> clockIn(String staffId, double lat, double lng) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/attendance/clock-in'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'staffId': staffId,
            'lat': lat,
            'lng': lng,
          }),
        )
        .timeout(_timeout);
    return _parseApiJson(response);
  }

  static Future<Map<String, dynamic>> clockOut(String staffId, double lat, double lng) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/attendance/clock-out'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'staffId': staffId,
            'lat': lat,
            'lng': lng,
          }),
        )
        .timeout(_timeout);
    return _parseApiJson(response);
  }

  static Future<Map<String, dynamic>> getWorkplaceInfo({String? staffId}) async {
    var url = '$baseUrl/attendance/workplace';
    if (staffId != null && staffId.isNotEmpty) {
      url += '?staffId=${Uri.encodeComponent(staffId)}';
    }
    final response = await http.get(Uri.parse(url)).timeout(_timeout);
    return _parseApiJson(response);
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

  static Future<Map<String, dynamic>> getWorkSchedule({int? year, int? month}) async {
    final q = <String>[];
    if (year != null) q.add('year=$year');
    if (month != null) q.add('month=$month');
    final query = q.isEmpty ? '' : '?${q.join('&')}';
    final response = await http.get(Uri.parse('$baseUrl/staff/work-schedule$query'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Staff: merged company + supervisor schedule (requires login).
  /// [year]/[month] — optional; returns [calendarMonth] for that month when set.
  static Future<Map<String, dynamic>> getMyWorkSchedule({int? year, int? month}) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');
    final q = <String>[];
    if (year != null) q.add('year=$year');
    if (month != null) q.add('month=$month');
    final query = q.isEmpty ? '' : '?${q.join('&')}';
    final response = await http.get(
      Uri.parse('$baseUrl/staff/my-work-schedule$query'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _supervisorRequest(String method, String path, {Map<String, dynamic>? body}) async {
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
    } else if (method == 'PUT') {
      response = await http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
    } else if (method == 'POST' && body != null) {
      response = await http.post(uri, headers: headers, body: jsonEncode(body));
    } else {
      throw Exception('Unsupported method');
    }
    return _parseApiJson(response);
  }

  static Future<Map<String, dynamic>> getSupervisorTeam() async => _supervisorRequest('GET', '/supervisor/team');

  /// Staff + supervisors company-wide (admin excluded). Supervisor home / directory.
  static Future<Map<String, dynamic>> getSupervisorOrgStaff() async => _supervisorRequest('GET', '/supervisor/org-staff');

  static Future<Map<String, dynamic>> getSupervisorOrgLeaveRequests() async =>
      _supervisorRequest('GET', '/supervisor/org-leave-requests');

  static Future<Map<String, dynamic>> getSupervisorOrgOvertimeRequests() async =>
      _supervisorRequest('GET', '/supervisor/org-overtime-requests');

  static Future<Map<String, dynamic>> getSupervisorConfig() async => _supervisorRequest('GET', '/supervisor/config');

  static Future<Map<String, dynamic>> getSupervisorAttendanceReport({String? startDate, String? endDate, String? staffId}) async {
    var path = '/supervisor/attendance-report?';
    if (startDate != null) path += 'startDate=$startDate&';
    if (endDate != null) path += 'endDate=$endDate&';
    if (staffId != null) path += 'staffId=${Uri.encodeComponent(staffId)}';
    return _supervisorRequest('GET', path);
  }

  static Future<Map<String, dynamic>> getSupervisorLeaveRequests({String? status}) async {
    var path = '/supervisor/leave-requests';
    if (status != null) path += '?status=${Uri.encodeComponent(status)}';
    return _supervisorRequest('GET', path);
  }

  /// Supervisor: approve/reject leave for direct-report staff (team only).
  static Future<Map<String, dynamic>> supervisorDecideLeave(
    String id,
    String status, {
    String? comment,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (comment != null && comment.isNotEmpty) body['adminComment'] = comment;
    return _supervisorRequest('PUT', '/supervisor/leave-requests/${Uri.encodeComponent(id)}', body: body);
  }

  static Future<Map<String, dynamic>> getSupervisorNotifications() async => _supervisorRequest('GET', '/supervisor/notifications');

  static Future<Map<String, dynamic>> markSupervisorNotificationRead(String id) async =>
      _supervisorRequest('PUT', '/supervisor/notifications/$id/read', body: {});

  static Future<Map<String, dynamic>> markAllSupervisorNotificationsRead() async =>
      _supervisorRequest('PUT', '/supervisor/notifications/read-all', body: {});

  static Future<Map<String, dynamic>> getSupervisorStaffSchedule(String staffId) async =>
      _supervisorRequest('GET', '/supervisor/staff/${Uri.encodeComponent(staffId)}/schedule');

  static Future<Map<String, dynamic>> putSupervisorStaffSchedule(
    String staffId, {
    List<Map<String, dynamic>>? days,
    List<Map<String, dynamic>>? dateEntries,
    String notes = '',
  }) async {
    final body = <String, dynamic>{'notes': notes};
    if (days != null) body['days'] = days;
    if (dateEntries != null) body['dateEntries'] = dateEntries;
    return _supervisorRequest('PUT', '/supervisor/staff/${Uri.encodeComponent(staffId)}/schedule', body: body);
  }

  /// [staffId] optional — empty sends [autoStaffId] for SUP### on server.
  static Future<Map<String, dynamic>> registerSupervisor(
    String? staffId,
    String name,
    String email,
    String password,
    String supervisorSecret,
  ) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'supervisorSecret': supervisorSecret,
    };
    if (staffId == null || staffId.trim().isEmpty) {
      body['autoStaffId'] = true;
    } else {
      body['staffId'] = staffId.trim();
    }
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/register-supervisor'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _parseApiJson(response);
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
    String reason, {
    String? mcLetter,
    String? mcLetterFileName,
  }) async {
    final body = <String, dynamic>{
      'staffId': staffId,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      'reason': reason,
    };
    if (mcLetter != null && mcLetter.isNotEmpty) {
      body['mcLetter'] = mcLetter;
      if (mcLetterFileName != null && mcLetterFileName.isNotEmpty) {
        body['mcLetterFileName'] = mcLetterFileName;
      }
    }
    final response = await http.post(
      Uri.parse('$baseUrl/leave/apply'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getLeaveMcLetter(String requestId, {String? staffId}) async {
    var url = '$baseUrl/leave/mc/${Uri.encodeComponent(requestId)}';
    if (staffId != null && staffId.isNotEmpty) {
      url += '?staffId=${Uri.encodeComponent(staffId)}';
    }
    final response = await http.get(Uri.parse(url)).timeout(_timeout);
    return _parseApiJson(response);
  }

  static Future<Map<String, dynamic>> getAdminLeaveMcLetter(String requestId) async {
    return _adminRequest('GET', '/admin/leave-requests/${Uri.encodeComponent(requestId)}/mc');
  }

  static Future<Map<String, dynamic>> getSupervisorLeaveMcLetter(String requestId) async {
    return _supervisorRequest('GET', '/supervisor/leave-requests/${Uri.encodeComponent(requestId)}/mc');
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

  /// [staffId] optional — empty sends [autoStaffId] for ADM### on server.
  static Future<Map<String, dynamic>> registerAdmin(
    String? staffId,
    String name,
    String email,
    String password,
    String adminSecret,
  ) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'adminSecret': adminSecret,
    };
    if (staffId == null || staffId.trim().isEmpty) {
      body['autoStaffId'] = true;
    } else {
      body['staffId'] = staffId.trim();
    }
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/register-admin'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _parseApiJson(response);
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

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/forgot-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(_timeout);
    return _parseApiJson(response);
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/reset-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim(),
            'code': code.trim(),
            'newPassword': newPassword,
          }),
        )
        .timeout(_timeout);
    return _parseApiJson(response);
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/change-password'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          }),
        )
        .timeout(_timeout);
    return _parseApiJson(response);
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
      response = await http.get(uri, headers: headers).timeout(_timeout);
    } else if (method == 'PUT' && body != null) {
      response = await http.put(uri, headers: headers, body: jsonEncode(body)).timeout(_timeout);
    } else if (method == 'POST' && body != null) {
      response = await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(_timeout);
    } else if (method == 'DELETE') {
      response = await http.delete(uri, headers: headers).timeout(_timeout);
    } else {
      throw Exception('Unsupported method');
    }
    return _parseApiJson(response);
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

  static Future<Map<String, dynamic>> getAdminBranches() async {
    return _adminRequest('GET', '/admin/branches');
  }

  static Future<Map<String, dynamic>> createAdminBranch({
    required String branchCode,
    required String name,
    String address = '',
    required double lat,
    required double lng,
    int radiusMeters = 60,
    bool isActive = true,
  }) async {
    return _adminRequest('POST', '/admin/branches', body: {
      'branchCode': branchCode,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'radiusMeters': radiusMeters,
      'isActive': isActive,
    });
  }

  static Future<Map<String, dynamic>> updateAdminBranch(
    String branchCode, {
    String? name,
    String? address,
    double? lat,
    double? lng,
    int? radiusMeters,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (address != null) body['address'] = address;
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;
    if (radiusMeters != null) body['radiusMeters'] = radiusMeters;
    if (isActive != null) body['isActive'] = isActive;
    final path = '/admin/branches/${Uri.encodeComponent(branchCode)}';
    return _adminRequest('PUT', path, body: body);
  }

  static Future<Map<String, dynamic>> deleteAdminBranch(String branchCode) async {
    final path = '/admin/branches/${Uri.encodeComponent(branchCode)}';
    return _adminRequest('DELETE', path);
  }

  /// [staffId] optional — leave empty or null to auto-generate (STF001, STF002, … on server).
  static Future<Map<String, dynamic>> registerStaffByAdmin(
    String? staffId,
    String name,
    String email,
    String password,
  ) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
    };
    if (staffId == null || staffId.trim().isEmpty) {
      body['autoStaffId'] = true;
    } else {
      body['staffId'] = staffId.trim();
    }
    return _adminRequest('POST', '/admin/register-staff', body: body);
  }

  static Future<Map<String, dynamic>> updateStaffSalary(String staffId, double salary) async {
    return _adminRequest('PUT', '/admin/staff/$staffId/salary', body: {'salary': salary});
  }

  /// Admin: update staff/supervisor profile (`PUT /admin/staff/:staffId`).
  static Future<Map<String, dynamic>> adminUpdateStaff(
    String staffId, {
    required String name,
    required String email,
    required String phone,
    required String department,
    required String position,
    String? newPassword,
    String? branchCode,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'department': department,
      'position': position,
    };
    if (newPassword != null && newPassword.isNotEmpty) {
      body['newPassword'] = newPassword;
    }
    if (branchCode != null) {
      body['branchCode'] = branchCode;
    }
    final path = '/admin/staff/${Uri.encodeComponent(staffId)}';
    return _adminRequest('PUT', path, body: body);
  }

  /// Assign or clear supervisor for a staff account (`supervisorStaffId` empty string clears).
  static Future<Map<String, dynamic>> adminAssignSupervisor(String staffId, String supervisorStaffId) async {
    final path = '/admin/staff/${Uri.encodeComponent(staffId)}/supervisor';
    return _adminRequest('PUT', path, body: {'supervisorStaffId': supervisorStaffId});
  }

  /// Admin: weekly timetable (working days, times, rest days) for any staff/supervisor.
  static Future<Map<String, dynamic>> getAdminStaffSchedule(String staffId) async {
    return _adminRequest('GET', '/admin/staff/${Uri.encodeComponent(staffId)}/schedule');
  }

  static Future<Map<String, dynamic>> putAdminStaffSchedule(
    String staffId, {
    List<Map<String, dynamic>>? days,
    List<Map<String, dynamic>>? dateEntries,
    String notes = '',
  }) async {
    final body = <String, dynamic>{'notes': notes};
    if (days != null) body['days'] = days;
    if (dateEntries != null) body['dateEntries'] = dateEntries;
    return _adminRequest(
      'PUT',
      '/admin/staff/${Uri.encodeComponent(staffId)}/schedule',
      body: body,
    );
  }

  /// Admin only: `PUT /admin/.../promote-supervisor` (requires admin JWT).
  /// [newStaffId] optional — set to `'auto'` for next SUP### ID, or a custom ID; omit to keep current ID.
  static Future<Map<String, dynamic>> promoteStaffToSupervisor(
    String staffId, {
    String? newStaffId,
  }) async {
    final path = '/admin/staff/${Uri.encodeComponent(staffId)}/promote-supervisor';
    final body = <String, dynamic>{};
    if (newStaffId != null && newStaffId.trim().isNotEmpty) {
      body['newStaffId'] = newStaffId.trim();
    }
    return _adminRequest('PUT', path, body: body);
  }

  static Future<Map<String, dynamic>> getAdminConfig() async {
    return _adminRequest('GET', '/admin/config');
  }

  static Future<Map<String, dynamic>> getAdminLeaveRequests({String? status}) async {
    var path = '/admin/leave-requests';
    if (status != null) path += '?status=${Uri.encodeComponent(status)}';
    return _adminRequest('GET', path);
  }

  static Future<Map<String, dynamic>> updateLeaveRequestStatus(
    String id,
    String status, {
    String? adminComment,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (adminComment != null && adminComment.isNotEmpty) {
      body['adminComment'] = adminComment;
    }
    return _adminRequest('PUT', '/admin/leave-requests/$id', body: body);
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

  /// Staff: apply for overtime (requires JWT, role staff).
  static Future<Map<String, dynamic>> applyOvertime({
    required DateTime otDate,
    required double hours,
    String reason = '',
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.post(
      Uri.parse('$baseUrl/staff/overtime/apply'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'otDate': otDate.toIso8601String().split('T')[0],
        'hours': hours,
        'reason': reason,
      }),
    );
    return _parseApiJson(response);
  }

  static Future<Map<String, dynamic>> getMyOvertimeRequests() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');
    final response = await http.get(
      Uri.parse('$baseUrl/staff/overtime/my'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _parseApiJson(response);
  }

  static Future<Map<String, dynamic>> getSupervisorOvertimeRequests({String? status}) async {
    var path = '/supervisor/overtime-requests';
    if (status != null) path += '?status=${Uri.encodeComponent(status)}';
    return _supervisorRequest('GET', path);
  }

  static Future<Map<String, dynamic>> supervisorDecideOvertime(
    String id,
    String status, {
    String? comment,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (comment != null && comment.isNotEmpty) body['comment'] = comment;
    return _supervisorRequest('PUT', '/supervisor/overtime-requests/${Uri.encodeComponent(id)}', body: body);
  }

  static Future<Map<String, dynamic>> getAdminOvertimeRequests({String? status, String? staffId}) async {
    final q = <String>[];
    if (status != null) q.add('status=${Uri.encodeComponent(status)}');
    if (staffId != null && staffId.isNotEmpty) q.add('staffId=${Uri.encodeComponent(staffId)}');
    final query = q.isEmpty ? '' : '?${q.join('&')}';
    return _adminRequest('GET', '/admin/overtime-requests$query');
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

  /// Public self-registration (`POST /auth/register`). [staffId] optional — empty sends [autoStaffId] for STF###.
  static Future<Map<String, dynamic>> register(
    String? staffId,
    String name,
    String email,
    String password,
  ) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
    };
    if (staffId == null || staffId.trim().isEmpty) {
      body['autoStaffId'] = true;
    } else {
      body['staffId'] = staffId.trim();
    }
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _parseApiJson(response);
  }
}
