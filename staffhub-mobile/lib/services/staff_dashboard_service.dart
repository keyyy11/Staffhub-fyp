import 'api_service.dart';
import 'auth_service.dart';

class StaffDashboardStats {
  const StaffDashboardStats({
    required this.totalAttendance,
    required this.lateAttendance,
    required this.leaveTaken,
    required this.overtimeHours,
    required this.attendanceRate,
    this.periodLabel,
  });

  final int totalAttendance;
  final int lateAttendance;
  final num leaveTaken;
  final num overtimeHours;
  final int attendanceRate;
  final String? periodLabel;

  factory StaffDashboardStats.fromApi(Map<String, dynamic> d) {
    return StaffDashboardStats(
      totalAttendance: (d['totalAttendance'] as num?)?.toInt() ?? 0,
      lateAttendance: (d['lateAttendance'] as num?)?.toInt() ?? 0,
      leaveTaken: d['leaveTaken'] as num? ?? 0,
      overtimeHours: d['overtimeHours'] as num? ?? 0,
      attendanceRate: (d['attendanceRate'] as num?)?.toInt() ?? 100,
      periodLabel: d['periodLabel'] as String?,
    );
  }

  static StaffDashboardStats demo() => const StaffDashboardStats(
        totalAttendance: 25,
        lateAttendance: 2,
        leaveTaken: 1,
        overtimeHours: 12,
        attendanceRate: 96,
        periodLabel: 'Demo',
      );

  static StaffDashboardStats empty() {
    final now = DateTime.now();
    return StaffDashboardStats(
      totalAttendance: 0,
      lateAttendance: 0,
      leaveTaken: 0,
      overtimeHours: 0,
      attendanceRate: 100,
      periodLabel: _monthLabel(now.year, now.month),
    );
  }
}

String _monthLabel(int year, int month) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${names[month - 1]} $year';
}

bool _inCurrentMonth(DateTime d, DateTime now) =>
    d.year == now.year && d.month == now.month;

bool _isClockInLate(DateTime clockIn, {int hour = 9, int minute = 0}) {
  final expected = DateTime(clockIn.year, clockIn.month, clockIn.day, hour, minute);
  return clockIn.isAfter(expected);
}

class StaffDashboardService {
  static Future<StaffDashboardStats> load(String staffId) async {
    if (staffId.isEmpty) return StaffDashboardStats.empty();

    if (await AuthService.isDemoMode()) {
      return StaffDashboardStats.demo();
    }

    try {
      final res = await ApiService.getStaffDashboardStats()
          .timeout(const Duration(seconds: 10));
      if (res['success'] == true && res['data'] != null) {
        return StaffDashboardStats.fromApi(
          Map<String, dynamic>.from(res['data'] as Map),
        );
      }
    } catch (_) {}

    return _computeFromExistingApis(staffId);
  }

  static Future<StaffDashboardStats> _computeFromExistingApis(String staffId) async {
    final now = DateTime.now();
    final periodLabel = _monthLabel(now.year, now.month);

    int total = 0;
    int late = 0;

    try {
      final attRes = await ApiService.getMyAttendance(staffId, limit: 90)
          .timeout(const Duration(seconds: 12));
      if (attRes['success'] == true && attRes['data'] is List) {
        for (final raw in attRes['data'] as List) {
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw);
          final clockInRaw = m['clockIn'];
          if (clockInRaw == null) continue;
          final clockIn = DateTime.tryParse(clockInRaw.toString());
          if (clockIn == null) continue;
          final dateRaw = m['date'] ?? clockInRaw;
          final date = DateTime.tryParse(dateRaw.toString()) ?? clockIn;
          if (!_inCurrentMonth(date, now)) continue;
          total += 1;
          if (_isClockInLate(clockIn)) late += 1;
        }
      }
    } catch (_) {}

    num leaveTaken = 0;
    try {
      final leaveRes = await ApiService.getMyLeaveRequests(staffId)
          .timeout(const Duration(seconds: 12));
      if (leaveRes['success'] == true && leaveRes['data'] is List) {
        for (final raw in leaveRes['data'] as List) {
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw);
          if (m['status'] != 'approved') continue;
          final start = DateTime.tryParse((m['startDate'] ?? '').toString());
          if (start == null || !_inCurrentMonth(start, now)) continue;
          leaveTaken += m['totalDays'] as num? ?? 0;
        }
      }
    } catch (_) {}

    num overtimeHours = 0;
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        final otRes = await ApiService.getMyOvertimeRequests()
            .timeout(const Duration(seconds: 12));
        if (otRes['success'] == true && otRes['data'] is List) {
          for (final raw in otRes['data'] as List) {
            if (raw is! Map) continue;
            final m = Map<String, dynamic>.from(raw);
            if (m['status'] != 'approved') continue;
            final otDate = DateTime.tryParse((m['otDate'] ?? '').toString());
            if (otDate == null || !_inCurrentMonth(otDate, now)) continue;
            overtimeHours += m['hours'] as num? ?? 0;
          }
        }
      }
    } catch (_) {}

    final onTime = total - late;
    final rate = total > 0 ? ((onTime / total) * 100).round() : 100;

    return StaffDashboardStats(
      totalAttendance: total,
      lateAttendance: late,
      leaveTaken: leaveTaken,
      overtimeHours: overtimeHours,
      attendanceRate: rate,
      periodLabel: periodLabel,
    );
  }
}
