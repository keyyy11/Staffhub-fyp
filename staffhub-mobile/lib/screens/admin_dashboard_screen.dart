import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/staffhub_logo.dart';
import '../widgets/staff_schedule_editor_dialog.dart';
import '../widgets/mc_letter_viewer.dart';
import '../widgets/attendance_clock_panel.dart';
import '../widgets/admin_workforce_analytics.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'admin_register_screen.dart';
import 'admin_profile_screen.dart';
import 'settings_screen.dart';
import 'admin_discipline_screen.dart';
import 'admin_access_logs_screen.dart';
import 'admin_overtime_screen.dart';
import 'admin_branches_screen.dart';
import 'admin_staff_edit_screen.dart';
import 'staff_performance_screen.dart';

String _roleLabel(dynamic role) {
  final r = role as String?;
  if (r == 'supervisor') return tr('role_supervisor');
  return tr('role_staff');
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with L10nMixin {
  List<String> get _sectionTitles => [
    tr('home'),
    tr('staff_directory'),
    tr('attendance'),
    tr('leave_requests'),
    tr('payslip'),
    tr('staff_pay'),
    tr('promote_supervisor'),
    tr('register_staff'),
  ];

  int _selectedIndex = 0;
  /// Loading state for promote action (staffId while API runs).
  String? _promotingStaffId;
  final _payslipNetController = TextEditingController();
  final _payslipGrossController = TextEditingController();
  final _payslipRemarksController = TextEditingController();
  String? _payslipSelectedStaffId;
  int _payslipYear = DateTime.now().year;
  int _payslipMonth = DateTime.now().month;
  bool _payslipSaving = false;
  List<Map<String, dynamic>> _attendanceReport = [];
  Map<String, dynamic>? _attendanceStats;
  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _payslipRecords = [];
  String? _leaveStatusFilter; // null = all
  String? _expectedTime;
  bool _isLoading = false;
  bool _leaveLoading = false;
  String? _errorMessage;
  /// Admin home: last 7 days attendance snapshot + leave + OT (loaded together).
  List<Map<String, dynamic>> _homeAttendance = [];
  Map<String, dynamic>? _homeAttendanceStats;
  List<Map<String, dynamic>> _homeLeave = [];
  List<Map<String, dynamic>> _homeOvertime = [];
  bool _homeLoading = false;
  List<Map<String, dynamic>> _homePerformanceStaff = [];
  bool _homePerformanceLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHome();
    _loadAttendance();
    _loadStaff();
    _loadLeaveRequests();
    _loadPayslipRecords();
  }

  @override
  void dispose() {
    _payslipNetController.dispose();
    _payslipGrossController.dispose();
    _payslipRemarksController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getAttendanceReport(),
        ApiService.getAdminConfig(),
      ]);
      final result = results[0];
      final configResult = results[1];
      if (result['success'] == true && result['data'] != null && mounted) {
        final data = result['data'] as Map<String, dynamic>;
        String? expected;
        if (configResult['success'] == true && configResult['data'] != null) {
          expected = configResult['data']['expectedClockIn'] as String?;
        }
        setState(() {
          _attendanceReport = List<Map<String, dynamic>>.from(data['report'] as List);
          _attendanceStats = data['stats'] as Map<String, dynamic>?;
          _expectedTime = expected ?? '09:00';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = tr('failed_load_admin'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStaff() async {
    try {
      final result = await ApiService.getStaffList();
      if (result['success'] == true && result['data'] != null && mounted) {
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(result['data'] as List);
          _payslipSelectedStaffId ??=
              _staffList.isNotEmpty ? _staffList.first['staffId'] as String? : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLeaveRequests() async {
    setState(() => _leaveLoading = true);
    try {
      final result = await ApiService.getAdminLeaveRequests(
        status: _leaveStatusFilter,
      );
      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _leaveRequests = List<Map<String, dynamic>>.from(result['data'] as List);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('failed_load_leave'))),
        );
      }
    } finally {
      if (mounted) setState(() => _leaveLoading = false);
    }
  }

  Future<void> _loadPayslipRecords() async {
    try {
      final result = await ApiService.getAdminPayslipRecords();
      if (result['success'] == true && result['data'] != null && mounted) {
        setState(() => _payslipRecords = List<Map<String, dynamic>>.from(result['data'] as List));
      }
    } catch (_) {}
  }

  String _isoDateOnly(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadHome() async {
    setState(() {
      _homeLoading = true;
      _homePerformanceLoading = true;
    });
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 30));
      final sd = _isoDateOnly(start);
      final ed = _isoDateOnly(end);
      final results = await Future.wait([
        ApiService.getAttendanceReport(startDate: sd, endDate: ed),
        ApiService.getAdminLeaveRequests(),
        ApiService.getAdminOvertimeRequests(),
        ApiService.getAdminPerformanceOverview(days: 30),
      ]);
      if (!mounted) return;
      final att = results[0];
      final leave = results[1];
      final ot = results[2];
      final perf = results[3];
      setState(() {
        if (att['success'] == true && att['data'] != null) {
          final data = att['data'] as Map<String, dynamic>;
          _homeAttendance = List<Map<String, dynamic>>.from(data['report'] as List);
          _homeAttendanceStats = data['stats'] as Map<String, dynamic>?;
        } else {
          _homeAttendance = [];
          _homeAttendanceStats = null;
        }
        if (leave['success'] == true && leave['data'] != null) {
          _homeLeave = List<Map<String, dynamic>>.from(leave['data'] as List);
        } else {
          _homeLeave = [];
        }
        if (ot['success'] == true && ot['data'] != null) {
          _homeOvertime = List<Map<String, dynamic>>.from(ot['data'] as List);
        } else {
          _homeOvertime = [];
        }
        if (perf['success'] == true && perf['data'] != null) {
          final pdata = perf['data'] as Map<String, dynamic>;
          _homePerformanceStaff = List<Map<String, dynamic>>.from(pdata['staff'] as List? ?? []);
        } else {
          _homePerformanceStaff = [];
        }
        _homeLoading = false;
        _homePerformanceLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _homeLoading = false;
          _homePerformanceLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    final date = DateTime.parse(d.toString());
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Shows the staff member's real name when available (from report or staff list), not only staffId.
  String _staffDisplayName(String? staffId, String? staffNameFromApi) {
    final id = staffId ?? '';
    final raw = staffNameFromApi?.trim();
    if (raw != null && raw.isNotEmpty && raw != id) {
      return raw;
    }
    for (final s in _staffList) {
      if ((s['staffId'] as String?) == id) {
        final n = (s['name'] as String?)?.trim();
        if (n != null && n.isNotEmpty) {
          return n;
        }
      }
    }
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    return id.isEmpty ? '-' : id;
  }

  void _selectSection(int index) {
    setState(() => _selectedIndex = index);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmPromoteStaffToSupervisor(Map<String, dynamic> member) async {
    final sid = member['staffId'] as String? ?? '';
    final name = member['name'] as String? ?? sid;
    final newIdController = TextEditingController();
    final autoSup = <bool>[false];
    final dialogResult = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: context.appColors.card,
            title: Text(tr('promote_to_supervisor_q'), style: TextStyle(color: context.appColors.textPrimary)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tr('promote_become_desc', {'name': name, 'sid': sid})}\n\n'
                    '${tr('promote_dialog_desc', {'id': sid})}',
                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: autoSup[0],
                    onChanged: (v) => setDialogState(() {
                      autoSup[0] = v ?? false;
                      if (autoSup[0]) newIdController.clear();
                    }),
                    title: Text(
                      tr('auto_generate_sup_id'),
                      style: TextStyle(color: context.appColors.textPrimary, fontSize: 14),
                    ),
                    subtitle: Text(
                      tr('replaces_current_id'),
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                    ),
                    activeColor: context.appColors.accentBlue,
                  ),
                  if (!autoSup[0]) ...[
                    SizedBox(height: 8),
                    Text(
                      tr('new_supervisor_id'),
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: 6),
                    TextField(
                      controller: newIdController,
                      style: TextStyle(color: context.appColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: tr('leave_empty_keep_id'),
                        hintStyle: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(tr('cancel'))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, {'ok': true}),
                style: ElevatedButton.styleFrom(backgroundColor: context.appColors.primaryBlue),
                child: Text(tr('promote')),
              ),
            ],
          );
        },
      ),
    );
    if (dialogResult == null || dialogResult['ok'] != true || !mounted) {
      newIdController.dispose();
      return;
    }
    final useAutoSup = autoSup[0];
    final manualId = newIdController.text.trim();
    newIdController.dispose();
    setState(() => _promotingStaffId = sid);
    try {
      final result = await ApiService.promoteStaffToSupervisor(
        sid,
        newStaffId: useAutoSup ? 'auto' : (manualId.isEmpty ? null : manualId),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? tr('promoted_supervisor'))),
        );
        await _loadStaff();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? tr('failed'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('network_error', {'message': e.toString()}))),
        );
      }
    } finally {
      if (mounted) setState(() => _promotingStaffId = null);
    }
  }

  Future<void> _openAdminScheduleEditor(Map<String, dynamic> member) async {
    final staffId = member['staffId'] as String? ?? '';
    final name = member['name'] as String? ?? staffId;
    final role = member['role'] as String?;
    if (role == 'admin') return;
    List<Map<String, dynamic>> days = [];
    List<Map<String, dynamic>> dateEntries = [];
    String notes = '';
    try {
      final custom = await ApiService.getAdminStaffSchedule(staffId);
      if (custom['success'] == true && custom['data'] != null) {
        final data = custom['data'] as Map<String, dynamic>;
        notes = (data['notes'] as String?) ?? '';
        final raw = data['days'];
        if (raw is List && raw.isNotEmpty) {
          days = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        final de = data['dateEntries'];
        if (de is List && de.isNotEmpty) {
          dateEntries = de.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    if (days.isEmpty) {
      try {
        final w = await ApiService.getWorkSchedule();
        final weekly = (w['data']?['weeklySchedule'] as List?) ?? [];
        for (final raw in weekly) {
          final r = raw as Map<String, dynamic>;
          days.add({
            'day': r['day'],
            'isWorkingDay': r['isWorkingDay'] == true,
            'workStart': r['workStart'] ?? '09:00',
            'workEnd': r['workEnd'] ?? '18:00',
            'shiftType': r['shiftType'],
          });
        }
      } catch (_) {}
    }
    if (days.isEmpty) {
      days = defaultWeekSchedule();
    }
    if (!mounted) return;
    final saved = await showDialog<bool?>(
      context: context,
      builder: (ctx) => StaffScheduleEditorDialog(
        staffName: name,
        initialDays: days,
        initialDateEntries: dateEntries.isNotEmpty ? dateEntries : null,
        initialNotes: notes,
        onSave: (clean, notesText) async {
          final res = await ApiService.putAdminStaffSchedule(
            staffId,
            dateEntries: clean,
            notes: notesText,
          );
          return res['success'] == true;
        },
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('schedule_saved'))));
    } else if (saved == false) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('schedule_save_failed'))));
    }
  }

  Widget _buildHomeTab() {
    final pendingLeave = _homeLeave.where((l) => l['status'] == 'pending').length;
    final pendingOt = _homeOvertime.where((o) => o['status'] == 'pending').length;
    final attSlice = _homeAttendance.take(10).toList();
    final leavePending = _homeLeave.where((l) => l['status'] == 'pending').take(6).toList();
    final leaveRecentDone = _homeLeave.where((l) => l['status'] != 'pending').take(5).toList();
    final otPending = _homeOvertime.where((o) => o['status'] == 'pending').take(6).toList();
    final otRecentDone = _homeOvertime.where((o) => o['status'] != 'pending').take(6).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.appColors.surface, context.appColors.background],
          stops: [0.0, 0.2],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadHome(), _loadStaff()]);
        },
        color: context.appColors.accentBlue,
        child: _homeLoading && _homeAttendance.isEmpty && _homeLeave.isEmpty && _homeOvertime.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator(color: context.appColors.accentBlue)),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    tr('my_attendance'),
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    tr('clock_geofence_hint'),
                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                  ),
                  SizedBox(height: 12),
                  const AttendanceClockPanel(showSectionTitle: false),
                  SizedBox(height: 24),
                  Text(
                    tr('attendance_dashboard'),
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    tr('attendance_dashboard_sub', {'days': '30'}),
                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _HomeStatCard(
                          icon: Icons.fact_check_rounded,
                          label: tr('total_attendance'),
                          value: '${_homeAttendanceStats?['total'] ?? _homeAttendance.length}',
                          color: context.appColors.accentBlue,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _HomeStatCard(
                          icon: Icons.schedule_rounded,
                          label: tr('late_attendance'),
                          value: '${_homeAttendanceStats?['late'] ?? 0}',
                          color: Colors.amber.shade200,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _HomeStatCard(
                          icon: Icons.event_note_rounded,
                          label: tr('leave_count'),
                          value: '${_homeLeave.length}',
                          color: Colors.greenAccent.shade100,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _HomeStatCard(
                          icon: Icons.more_time_rounded,
                          label: tr('overtime_count'),
                          value: '${_homeOvertime.length}',
                          color: Colors.deepPurple.shade200,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  AdminWorkforceAnalytics(
                    attendanceStats: _homeAttendanceStats,
                    performanceStaff: _homePerformanceStaff,
                    loadingPerformance: _homePerformanceLoading,
                    periodDays: 30,
                  ),
                  SizedBox(height: 8),
                  Text(
                    tr('operations_overview'),
                    style: TextStyle(
                      color: context.appColors.textSecondary.withValues(alpha: 0.95),
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _HomeStatCard(
                          icon: Icons.pending_actions_rounded,
                          label: tr('leave_pending_count'),
                          value: '$pendingLeave',
                          color: Colors.amber.shade200,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _HomeStatCard(
                          icon: Icons.hourglass_top_rounded,
                          label: tr('ot_pending_count'),
                          value: '$pendingOt',
                          color: context.appColors.accentBlue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _selectSection(2),
                        child: Text(tr('full_attendance')),
                      ),
                      TextButton(
                        onPressed: () => _selectSection(3),
                        child: Text(tr('leave_requests')),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminOvertimeScreen()),
                          );
                        },
                        child: Text(tr('all_overtime')),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    tr('attendance_activity_period', {'days': '30'}),
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  if (attSlice.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(tr('no_attendance_period'), style: TextStyle(color: context.appColors.textSecondary)),
                    )
                  else
                    ...attSlice.map((r) => _HomeAttendanceRow(
                          staffName: _staffDisplayName(r['staffId'] as String?, r['staffName'] as String?),
                          staffId: r['staffId'] as String? ?? '',
                          dateText: _formatDate(r['date']),
                          timeLine: tr('attendance_in_out', {
                            'inTime': (r['clockInTime'] ?? '-').toString(),
                            'outTime': (r['clockOutTime'] ?? '-').toString(),
                          }),
                          late: (r['status'] as String?) == 'late',
                        )),
                  SizedBox(height: 20),
                  Text(
                    tr('leave_requests_supervisors'),
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    tr('pending_shows_supervisor'),
                    style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.9), fontSize: 12),
                  ),
                  SizedBox(height: 10),
                  if (leavePending.isEmpty && leaveRecentDone.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(tr('no_leave_requests_admin'), style: TextStyle(color: context.appColors.textSecondary)),
                    )
                  else ...[
                    if (leavePending.isNotEmpty) ...[
                      Text(tr('awaiting_approval'), style: TextStyle(color: context.appColors.accentBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6),
                      ...leavePending.map((l) => _HomeLeaveCard(
                            staffName: l['staffName'] as String? ?? l['staffId'] as String? ?? '',
                            type: _leaveTypeLabel(l['leaveType'] as String?),
                            range: '${_formatDate(l['startDate'])} – ${_formatDate(l['endDate'])}',
                            status: 'pending',
                            supervisorName: (l['supervisorName'] as String?)?.trim(),
                            decidedByName: null,
                            decidedByRole: null,
                          )),
                    ],
                    if (leaveRecentDone.isNotEmpty) ...[
                      SizedBox(height: 12),
                      Text(tr('recent_decisions'), style: TextStyle(color: context.appColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6),
                      ...leaveRecentDone.map((l) => _HomeLeaveCard(
                            staffName: l['staffName'] as String? ?? l['staffId'] as String? ?? '',
                            type: _leaveTypeLabel(l['leaveType'] as String?),
                            range: '${_formatDate(l['startDate'])} – ${_formatDate(l['endDate'])}',
                            status: l['status'] as String? ?? '',
                            supervisorName: null,
                            decidedByName: (l['decidedByName'] as String?)?.trim(),
                            decidedByRole: l['decidedByRole'] as String?,
                          )),
                    ],
                  ],
                  SizedBox(height: 20),
                  Text(
                    tr('overtime_section'),
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    tr('pending_shows_supervisor_ot'),
                    style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.9), fontSize: 12),
                  ),
                  SizedBox(height: 10),
                  if (otPending.isEmpty && otRecentDone.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(tr('no_overtime_requests'), style: TextStyle(color: context.appColors.textSecondary)),
                    )
                  else ...[
                    if (otPending.isNotEmpty) ...[
                      Text(tr('awaiting_supervisor'), style: TextStyle(color: context.appColors.accentBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6),
                      ...otPending.map((o) => _HomeOtCard(
                            staffName: o['staffName'] as String? ?? o['staffId'] as String? ?? '',
                            otDate: _formatDate(o['otDate']),
                            hours: o['hours']?.toString() ?? '-',
                            status: 'pending',
                            supervisorLabel: (o['supervisorNameAtSubmit'] as String?)?.trim(),
                            approverName: null,
                          )),
                    ],
                    if (otRecentDone.isNotEmpty) ...[
                      SizedBox(height: 12),
                      Text(tr('recent_approvals_rejections'), style: TextStyle(color: context.appColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6),
                      ...otRecentDone.map((o) => _HomeOtCard(
                            staffName: o['staffName'] as String? ?? o['staffId'] as String? ?? '',
                            otDate: _formatDate(o['otDate']),
                            hours: o['hours']?.toString() ?? '-',
                            status: o['status'] as String? ?? '',
                            supervisorLabel: null,
                            approverName: (o['approverName'] as String?)?.trim(),
                          )),
                    ],
                  ],
                  SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildStaffDirectoryTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.appColors.surface, context.appColors.background],
          stops: [0.0, 0.2],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadStaff,
        color: context.appColors.accentBlue,
        child: _staffList.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(height: 48),
                  Icon(Icons.groups_outlined, size: 56, color: context.appColors.textSecondary.withValues(alpha: 0.6)),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      tr('no_staff_yet'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 15),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      tr('create_accounts_hint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.85), fontSize: 13),
                    ),
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _selectedIndex = 7),
                      icon: Icon(Icons.person_add_alt_1_rounded, size: 20),
                      label: Text(tr('add_staff')),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.appColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _staffList.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              tr('all_staff_supervisors', {'count': _staffList.length.toString()}),
                              style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.95), fontSize: 13),
                            ),
                          ),
                          SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => setState(() => _selectedIndex = 7),
                            icon: Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: Text(tr('add_staff')),
                            style: FilledButton.styleFrom(
                              backgroundColor: context.appColors.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final s = _staffList[i - 1];
                  final name = s['name'] as String? ?? '-';
                  final sid = s['staffId'] as String? ?? '';
                  final email = s['email'] as String? ?? '';
                  final role = s['role'] as String?;
                  final reportsTo = (s['supervisorStaffId'] as String?)?.trim() ?? '';
                  final isSupervisor = role == 'supervisor';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.appColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.45)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isSupervisor ? Icons.supervisor_account_rounded : Icons.person_outline_rounded,
                              color: context.appColors.accentBlue,
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: context.appColors.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(sid, style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
                                  if (email.isNotEmpty)
                                    Text(email, style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(
                                _roleLabel(role),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSupervisor ? Colors.deepPurpleAccent.shade100 : context.appColors.textPrimary,
                                ),
                              ),
                              backgroundColor: isSupervisor
                                  ? Colors.deepPurple.withValues(alpha: 0.25)
                                  : context.appColors.surface,
                              side: BorderSide(color: context.appColors.borderBlue.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        if (!isSupervisor && reportsTo.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            tr('reports_to_supervisor', {'id': reportsTo}),
                            style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                          ),
                        ],
                        SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StaffPerformanceScreen(
                                        staffId: s['staffId'] as String? ?? '',
                                        staffName: s['name'] as String? ?? '',
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.insights_outlined, size: 18, color: context.appColors.accentBlue),
                                label: Text(tr('view_performance'), style: TextStyle(color: context.appColors.accentBlue)),
                              ),
                              TextButton.icon(
                                onPressed: () => _openAdminScheduleEditor(s),
                                icon: Icon(Icons.schedule_rounded, size: 18, color: context.appColors.accentBlue),
                                label: Text(tr('weekly_schedule'), style: TextStyle(color: context.appColors.accentBlue)),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final updated = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminStaffEditScreen(
                                        staff: Map<String, dynamic>.from(s),
                                        allStaff: _staffList,
                                      ),
                                    ),
                                  );
                                  if (updated == true && mounted) await _loadStaff();
                                },
                                icon: Icon(Icons.edit_outlined, size: 18, color: context.appColors.accentBlue),
                                label: Text(tr('edit'), style: TextStyle(color: context.appColors.accentBlue)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _drawerNavTile({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _selectedIndex == index;
    return ListTile(
      selected: selected,
      selectedColor: context.appColors.accentBlue,
      selectedTileColor: context.appColors.primaryBlue.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(
        icon,
        color: selected ? context.appColors.accentBlue : context.appColors.textSecondary,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? context.appColors.accentBlue : context.appColors.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: () => _selectSection(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      drawer: Drawer(
        backgroundColor: context.appColors.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StaffHubLogo(height: 62),
                    SizedBox(height: 14),
                    Text(
                      tr('admin_hub'),
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      tr('staff_hub_management'),
                      style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.9), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: context.appColors.borderBlue, height: 1),
              ),
              SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  children: [
                    _drawerNavTile(index: 0, icon: Icons.home_rounded, label: tr('home')),
                    _drawerNavTile(index: 1, icon: Icons.groups_rounded, label: tr('staff_directory')),
                    _drawerNavTile(index: 2, icon: Icons.access_time_rounded, label: tr('attendance')),
                    _drawerNavTile(index: 3, icon: Icons.event_note_rounded, label: tr('leave_requests')),
                    _drawerNavTile(index: 4, icon: Icons.receipt_long_rounded, label: tr('payslip')),
                    _drawerNavTile(index: 5, icon: Icons.payments_rounded, label: tr('staff_pay')),
                    _drawerNavTile(index: 6, icon: Icons.supervisor_account_outlined, label: tr('promote_supervisor')),
                    _drawerNavTile(index: 7, icon: Icons.person_add_alt_1_rounded, label: tr('register_staff')),
                  ],
                ),
              ),
              Divider(color: context.appColors.borderBlue, height: 1),
              ListTile(
                leading: Icon(Icons.settings_outlined, color: context.appColors.accentBlue),
                title: Text(tr('settings'), style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.person_outline, color: context.appColors.accentBlue),
                title: Text(tr('admin_profile'), style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.location_on_outlined, color: context.appColors.accentBlue),
                title: Text(tr('branches'), style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminBranchesScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.gavel_rounded, color: context.appColors.accentBlue),
                title: Text(tr('discipline_warnings'), style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminDisciplineScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.more_time_rounded, color: context.appColors.accentBlue),
                title: Text(tr('overtime_audit'), style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminOvertimeScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.person_add_alt_outlined, color: context.appColors.accentBlue),
                title: Text(tr('add_admin_account'), style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminRegisterScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.history_rounded, color: context.appColors.accentBlue),
                title: Text(tr('access_logs_title'), style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminAccessLogsScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.redAccent),
                title: Text(tr('logout'), style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(context).pop();
                  _logout();
                },
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(
          _sectionTitles[_selectedIndex],
          style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: context.appColors.surface,
        foregroundColor: context.appColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: context.appColors.accentBlue),
            tooltip: tr('settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: context.appColors.accentBlue),
            tooltip: tr('refresh_data'),
            onPressed: () {
              _loadHome();
              _loadAttendance();
              _loadStaff();
              _loadLeaveRequests();
              _loadPayslipRecords();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildStaffDirectoryTab(),
          _buildAttendanceTab(),
          _buildLeaveRequestsTab(),
          _buildAdminPayslipTab(),
          _buildSalaryTab(),
          _buildPromoteSupervisorTab(),
          _buildRegisterStaffTab(),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: context.appColors.accentBlue));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: context.appColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.appColors.surface, context.appColors.background],
          stops: [0.0, 0.2],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadAttendance,
        color: context.appColors.accentBlue,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_attendanceStats != null)
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.appColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appColors.borderBlue.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem(tr('total'), _attendanceStats!['total']?.toString() ?? '0', context.appColors.accentBlue),
                    _statItem(tr('on_time'), _attendanceStats!['onTime']?.toString() ?? '0', Colors.green),
                    _statItem(tr('late'), _attendanceStats!['late']?.toString() ?? '0', Colors.amber),
                  ],
                ),
              ),
            Text(tr('expected_clock_in_time', {'time': _expectedTime ?? '09:00'}), style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
            SizedBox(height: 8),
            ..._attendanceReport.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ((r['status'] as String?) == 'late' ? Colors.amber : Colors.green).withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    (r['status'] as String?) == 'late' ? Icons.warning_amber : Icons.check_circle,
                    color: (r['status'] as String?) == 'late' ? Colors.amber : Colors.green,
                    size: 32,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _staffDisplayName(r['staffId'] as String?, r['staffName'] as String?),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.appColors.textPrimary),
                        ),
                        Text(
                          '${r['staffId']} • ${_formatDate(r['date'])}',
                          style: TextStyle(fontSize: 12, color: context.appColors.textSecondary),
                        ),
                        Text(tr('clock_in_out_pipe', {'inTime': (r['clockInTime'] ?? '-').toString(), 'outTime': (r['clockOutTime'] ?? '-').toString()}), style: TextStyle(fontSize: 12, color: context.appColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ((r['status'] as String?) == 'late' ? Colors.amber : Colors.green).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (r['status'] as String?) == 'late' ? tr('late_status') : tr('on_time_status'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (r['status'] as String?) == 'late' ? Colors.amber : Colors.green),
                    ),
                  ),
                ],
              ),
            )),
            if (_attendanceReport.isEmpty)
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text(tr('no_attendance_records_admin'), style: TextStyle(color: context.appColors.textSecondary))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: context.appColors.textSecondary)),
      ],
    );
  }

  String _leaveTypeLabel(String? t) {
    switch (t) {
      case 'medical':
        return tr('leave_type_medical');
      case 'annual':
        return tr('leave_type_annual');
      case 'unpaid':
        return tr('leave_type_unpaid');
      case 'other':
        return tr('leave_type_other');
      default:
        return t ?? '-';
    }
  }

  String _statusLabel(String? st) {
    switch (st) {
      case 'approved':
        return tr('approved');
      case 'rejected':
        return tr('rejected');
      case 'pending':
        return tr('pending');
      default:
        return st ?? tr('pending');
    }
  }

  Future<void> _approveLeave(String id, bool approve) async {
    try {
      final result = await ApiService.updateLeaveRequestStatus(id, approve ? 'approved' : 'rejected');
      if (!mounted) return;
      if (result['success'] == true) {
        await _loadLeaveRequests();
        await _loadStaff();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? tr('failed'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('connection_error'))));
      }
    }
  }

  Widget _buildLeaveRequestsTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.appColors.surface, context.appColors.background],
          stops: [0.0, 0.2],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(tr('all')),
                  selected: _leaveStatusFilter == null,
                  onSelected: (_) {
                    setState(() => _leaveStatusFilter = null);
                    _loadLeaveRequests();
                  },
                  selectedColor: context.appColors.primaryBlue,
                  labelStyle: TextStyle(color: _leaveStatusFilter == null ? Colors.white : context.appColors.textSecondary),
                ),
                ChoiceChip(
                  label: Text(tr('pending')),
                  selected: _leaveStatusFilter == 'pending',
                  onSelected: (_) {
                    setState(() => _leaveStatusFilter = 'pending');
                    _loadLeaveRequests();
                  },
                  selectedColor: context.appColors.primaryBlue,
                  labelStyle: TextStyle(color: _leaveStatusFilter == 'pending' ? Colors.white : context.appColors.textSecondary),
                ),
                ChoiceChip(
                  label: Text(tr('approved')),
                  selected: _leaveStatusFilter == 'approved',
                  onSelected: (_) {
                    setState(() => _leaveStatusFilter = 'approved');
                    _loadLeaveRequests();
                  },
                  selectedColor: context.appColors.primaryBlue,
                  labelStyle: TextStyle(color: _leaveStatusFilter == 'approved' ? Colors.white : context.appColors.textSecondary),
                ),
                ChoiceChip(
                  label: Text(tr('rejected')),
                  selected: _leaveStatusFilter == 'rejected',
                  onSelected: (_) {
                    setState(() => _leaveStatusFilter = 'rejected');
                    _loadLeaveRequests();
                  },
                  selectedColor: context.appColors.primaryBlue,
                  labelStyle: TextStyle(color: _leaveStatusFilter == 'rejected' ? Colors.white : context.appColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: _leaveLoading
                ? Center(child: CircularProgressIndicator(color: context.appColors.accentBlue))
                : RefreshIndicator(
                    onRefresh: _loadLeaveRequests,
                    color: context.appColors.accentBlue,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _leaveRequests.length,
                      itemBuilder: (context, i) {
                        final r = _leaveRequests[i];
                        final id = r['_id']?.toString() ?? '';
                        final pending = (r['status'] as String?) == 'pending';
                        final st = r['status'] as String? ?? '';
                        Color stColor = context.appColors.textSecondary;
                        if (st == 'approved') stColor = Colors.green;
                        if (st == 'rejected') stColor = Colors.redAccent;
                        if (st == 'pending') stColor = Colors.amber;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.appColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.appColors.borderBlue.withOpacity(0.45)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _staffDisplayName(r['staffId'] as String?, r['staffName'] as String?),
                                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.appColors.textPrimary),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: stColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(_statusLabel(st).toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stColor)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(tr('working_days_label', {'type': _leaveTypeLabel(r['leaveType'] as String?), 'days': (r['totalDays'] ?? '-').toString()}), style: TextStyle(color: context.appColors.textSecondary, fontSize: 14)),
                              Text(
                                '${_formatDate(r['startDate'])} → ${_formatDate(r['endDate'])}',
                                style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                              ),
                              if ((r['reason'] as String?)?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(tr('reason_colon', {'reason': r['reason'] as String}), style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
                                ),
                              if (r['hasMcLetter'] == true && id.isNotEmpty) ...[
                                SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => showMcLetterDialog(context, requestId: id, asAdmin: true),
                                  icon: Icon(Icons.description_outlined, size: 18, color: context.appColors.accentBlue),
                                  label: Text(tr('view_mc_letter'), style: TextStyle(color: context.appColors.accentBlue)),
                                ),
                              ],
                              if (pending && id.isNotEmpty) ...[
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _approveLeave(id, false),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                                        child: Text(tr('reject')),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _approveLeave(id, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                                        child: Text(tr('approve')),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAdminPayslip() async {
    final sid = _payslipSelectedStaffId;
    if (sid == null || sid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('select_staff'))));
      return;
    }
    final net = double.tryParse(_payslipNetController.text.trim());
    if (net == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('enter_net_pay'))));
      return;
    }
    setState(() => _payslipSaving = true);
    try {
      final gross = double.tryParse(_payslipGrossController.text.trim());
      final result = await ApiService.upsertAdminPayslipRecord(
        staffId: sid,
        year: _payslipYear,
        month: _payslipMonth,
        netPay: net,
        grossPay: gross,
        remarks: _payslipRemarksController.text.trim().isEmpty ? null : _payslipRemarksController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _payslipSaving = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] as String? ?? tr('payslip_saved'))));
        _payslipNetController.clear();
        _payslipGrossController.clear();
        _payslipRemarksController.clear();
        await _loadPayslipRecords();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] as String? ?? tr('failed'))));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _payslipSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('connection_error'))));
      }
    }
  }

  Widget _buildAdminPayslipTab() {
    if (_staffList.isEmpty) {
      return Center(child: Text(tr('no_staff_register_first'), style: TextStyle(color: context.appColors.textSecondary)));
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.appColors.surface, context.appColors.background],
          stops: [0.0, 0.2],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadStaff();
                await _loadPayslipRecords();
              },
              color: context.appColors.accentBlue,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    tr('payslip_entry_desc'),
                    style: TextStyle(color: context.appColors.textSecondary.withOpacity(0.95), fontSize: 13),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.appColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.appColors.borderBlue.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _payslipSelectedStaffId,
                          dropdownColor: context.appColors.card,
                          decoration: InputDecoration(
                            labelText: tr('staff'),
                            labelStyle: TextStyle(color: context.appColors.textSecondary),
                            border: OutlineInputBorder(),
                          ),
                          style: TextStyle(color: context.appColors.textPrimary, fontSize: 16),
                          items: _staffList.map((s) {
                            final id = s['staffId'] as String? ?? '';
                            final name = s['name'] as String? ?? '';
                            final role = _roleLabel(s['role']);
                            return DropdownMenuItem(value: id, child: Text('$name ($id) · $role'));
                          }).toList(),
                          onChanged: (v) => setState(() => _payslipSelectedStaffId = v),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _payslipMonth,
                                dropdownColor: context.appColors.card,
                                decoration: InputDecoration(labelText: tr('month'), border: OutlineInputBorder()),
                                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                                onChanged: (v) => setState(() => _payslipMonth = v ?? 1),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _payslipYear,
                                dropdownColor: context.appColors.card,
                                decoration: InputDecoration(labelText: tr('year'), border: OutlineInputBorder()),
                                items: List.generate(5, (i) {
                                  final y = DateTime.now().year - 2 + i;
                                  return DropdownMenuItem(value: y, child: Text('$y'));
                                }),
                                onChanged: (v) => setState(() => _payslipYear = v ?? DateTime.now().year),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _payslipNetController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: context.appColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: tr('net_pay_rm'),
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _payslipGrossController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: context.appColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: tr('gross_salary_rm'),
                            helperText: tr('gross_salary_helper'),
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _payslipRemarksController,
                          maxLines: 2,
                          style: TextStyle(color: context.appColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: tr('hr_notes'),
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _payslipSaving ? null : _saveAdminPayslip,
                            style: ElevatedButton.styleFrom(backgroundColor: context.appColors.primaryBlue),
                            child: _payslipSaving
                                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(tr('save_payslip')),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(tr('recent_records'), style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  ..._payslipRecords.take(20).map((p) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.appColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.appColors.borderBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${p['staffId']} · ${p['month']}/${p['year']}',
                              style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
                            ),
                          ),
                          Text(
                            'RM ${(p['netPay'] as num?)?.toStringAsFixed(2) ?? '-'}',
                            style: TextStyle(color: context.appColors.accentBlue, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_payslipRecords.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(tr('no_payslip_records'), style: TextStyle(color: context.appColors.textSecondary)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.appColors.surface, context.appColors.background],
          stops: [0.0, 0.2],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadStaff,
        color: context.appColors.accentBlue,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                tr('staff_pay_desc'),
                style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.95), fontSize: 13),
              ),
            ),
            ..._staffList.map((s) => _StaffSalaryCard(
                  staff: s,
                  onSalaryUpdated: _loadStaff,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoteSupervisorTab() {
    final staffOnly = _staffList.where((s) => (s['role'] as String?) != 'supervisor').toList();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.appColors.surface, context.appColors.background],
          stops: [0.0, 0.2],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadStaff,
        color: context.appColors.accentBlue,
        child: staffOnly.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(height: 32),
                  Icon(Icons.supervisor_account_outlined, size: 56, color: context.appColors.textSecondary.withValues(alpha: 0.6)),
                  SizedBox(height: 16),
                  Text(
                    _staffList.isEmpty
                        ? tr('no_accounts_promote')
                        : tr('all_supervisors_already'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: staffOnly.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        tr('promote_admin_hint'),
                        style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.95), fontSize: 13),
                      ),
                    );
                  }
                  final s = staffOnly[i - 1];
                  final sid = s['staffId'] as String? ?? '';
                  final name = s['name'] as String? ?? sid;
                  final email = s['email'] as String? ?? '';
                  final busy = _promotingStaffId == sid;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.appColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.person_outline_rounded, color: context.appColors.accentBlue, size: 36),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(color: context.appColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                              Text(sid, style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
                              if (email.isNotEmpty)
                                Text(email, style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: busy ? null : () => _confirmPromoteStaffToSupervisor(s),
                          style: FilledButton.styleFrom(
                            backgroundColor: context.appColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          icon: busy
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(Icons.arrow_upward_rounded, size: 18),
                          label: Text(busy ? tr('wait') : tr('promote')),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildRegisterStaffTab() {
    return _AdminRegisterStaffForm(onStaffCreated: () {
      _loadStaff();
      _loadHome();
    });
  }
}

class _HomeStatCard extends StatelessWidget {
  const _HomeStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          SizedBox(height: 8),
          Text(value, style: TextStyle(color: context.appColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: context.appColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _HomeAttendanceRow extends StatelessWidget {
  const _HomeAttendanceRow({
    required this.staffName,
    required this.staffId,
    required this.dateText,
    required this.timeLine,
    required this.late,
  });

  final String staffName;
  final String staffId;
  final String dateText;
  final String timeLine;
  final bool late;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (late ? Colors.amber : Colors.green).withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(late ? Icons.schedule_rounded : Icons.check_circle_outline_rounded, color: late ? Colors.amber : Colors.green, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staffName, style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.w600)),
                Text('$staffId · $dateText', style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
                Text(timeLine, style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (late ? Colors.amber : Colors.green).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              late ? tr('late_status') : tr('on_time_status'),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: late ? Colors.amber : Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}

String _localizedStatus(String status) {
  switch (status) {
    case 'approved':
      return tr('approved');
    case 'rejected':
      return tr('rejected');
    case 'pending':
      return tr('pending');
    default:
      return status;
  }
}

class _HomeLeaveCard extends StatelessWidget {
  const _HomeLeaveCard({
    required this.staffName,
    required this.type,
    required this.range,
    required this.status,
    this.supervisorName,
    this.decidedByName,
    this.decidedByRole,
  });

  final String staffName;
  final String type;
  final String range;
  final String status;
  final String? supervisorName;
  final String? decidedByName;
  final String? decidedByRole;

  @override
  Widget build(BuildContext context) {
    final pending = status == 'pending';
    final roleLabel = decidedByRole == 'supervisor'
        ? tr('role_supervisor_paren')
        : decidedByRole == 'admin'
            ? tr('role_admin_paren')
            : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(staffName, style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: pending ? Colors.amber.withValues(alpha: 0.2) : Colors.blueGrey.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pending ? tr('pending').toUpperCase() : _localizedStatus(status).toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pending ? Colors.amber : context.appColors.textSecondary),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text('$type · $range', style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
          if (pending && supervisorName != null && supervisorName!.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(tr('reporting_supervisor', {'name': supervisorName!}), style: TextStyle(color: context.appColors.accentBlue, fontSize: 12)),
          ],
          if (!pending && decidedByName != null && decidedByName!.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(
              tr('decision_by', {'name': decidedByName!, 'role': roleLabel}),
              style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeOtCard extends StatelessWidget {
  const _HomeOtCard({
    required this.staffName,
    required this.otDate,
    required this.hours,
    required this.status,
    this.supervisorLabel,
    this.approverName,
  });

  final String staffName;
  final String otDate;
  final String hours;
  final String status;
  final String? supervisorLabel;
  final String? approverName;

  @override
  Widget build(BuildContext context) {
    final pending = status == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(staffName, style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: pending ? Colors.amber.withValues(alpha: 0.2) : Colors.blueGrey.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pending ? tr('pending').toUpperCase() : _localizedStatus(status).toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pending ? Colors.amber : context.appColors.textSecondary),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(tr('ot_date_hours', {'date': otDate, 'hours': hours}), style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
          if (pending && supervisorLabel != null && supervisorLabel!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(tr('awaiting_supervisor_name', {'name': supervisorLabel!}), style: TextStyle(color: context.appColors.accentBlue, fontSize: 12)),
            ),
          if (!pending && approverName != null && approverName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(tr('approved_by_name', {'name': approverName!}), style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _AdminRegisterStaffForm extends StatefulWidget {
  final VoidCallback onStaffCreated;

  const _AdminRegisterStaffForm({required this.onStaffCreated});

  @override
  State<_AdminRegisterStaffForm> createState() => _AdminRegisterStaffFormState();
}

class _AdminRegisterStaffFormState extends State<_AdminRegisterStaffForm> with L10nMixin {
  final _staffIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _staffIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final staffId = _staffIdController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _message = tr('fill_name_email_password');
        _success = false;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _message = tr('password_min_length');
        _success = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final result = await ApiService.registerStaffByAdmin(
        staffId.isEmpty ? null : staffId,
        name,
        email,
        password,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>?;
        final assignedId = data?['staffId'] as String?;
        setState(() {
          _isLoading = false;
          _success = true;
          _message = assignedId != null && assignedId.isNotEmpty
              ? tr('staff_registered_id', {'id': assignedId})
              : (result['message'] as String? ?? tr('staff_registered_success'));
        });
        _staffIdController.clear();
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        widget.onStaffCreated();
      } else {
        setState(() {
          _isLoading = false;
          _success = false;
          _message = result['message'] as String? ?? tr('register_failed');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _success = false;
          _message = tr('connection_error_ensure_api');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.appColors.surface, context.appColors.background],
          stops: [0.0, 0.2],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('register_staff_hint'),
              style: TextStyle(color: context.appColors.textSecondary.withOpacity(0.95), fontSize: 14),
            ),
            SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.appColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.appColors.borderBlue.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _success ? Colors.green.shade900.withOpacity(0.3) : Colors.red.shade900.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _success ? Colors.green.shade700 : Colors.red.shade700),
                      ),
                      child: Text(_message!, style: TextStyle(color: _success ? Colors.greenAccent : Colors.redAccent)),
                    ),
                  ],
                  TextField(
                    controller: _staffIdController,
                    style: TextStyle(color: context.appColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: tr('staff_id_optional'),
                      hintText: tr('staff_id_hint'),
                      prefixIcon: Icon(Icons.badge_outlined, color: context.appColors.accentBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  SizedBox(height: 14),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: context.appColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: tr('full_name'),
                      prefixIcon: Icon(Icons.person_outline, color: context.appColors.accentBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  SizedBox(height: 14),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: TextStyle(color: context.appColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: tr('email'),
                      prefixIcon: Icon(Icons.email_outlined, color: context.appColors.accentBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: context.appColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: tr('temporary_password'),
                      helperText: tr('password_min_length'),
                      prefixIcon: Icon(Icons.lock_outline, color: context.appColors.accentBlue),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(tr('register_staff')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffSalaryCard extends StatefulWidget {
  final Map<String, dynamic> staff;
  final VoidCallback onSalaryUpdated;

  const _StaffSalaryCard({required this.staff, required this.onSalaryUpdated});

  @override
  State<_StaffSalaryCard> createState() => _StaffSalaryCardState();
}

class _StaffSalaryCardState extends State<_StaffSalaryCard> with L10nMixin {
  final _salaryController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _salaryController.text = (widget.staff['salary'] ?? 0).toString();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _saveSalary() async {
    final salary = double.tryParse(_salaryController.text) ?? 0;
    setState(() => _isSaving = true);
    try {
      final result = await ApiService.updateStaffSalary(widget.staff['staffId'] as String, salary);
      if (result['success'] == true && mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        widget.onSalaryUpdated();
      }
    } catch (_) {}
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.borderBlue.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person, color: context.appColors.accentBlue, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.staff['name'] ?? '-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.appColors.textPrimary)),
                    Text(widget.staff['staffId'] ?? '-', style: TextStyle(fontSize: 13, color: context.appColors.textSecondary)),
                    SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(
                          _roleLabel(widget.staff['role']),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appColors.textPrimary),
                        ),
                        backgroundColor: context.appColors.surface,
                        side: BorderSide(color: context.appColors.borderBlue.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    if (widget.staff['department'] != null && (widget.staff['department'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(widget.staff['department'], style: TextStyle(fontSize: 12, color: context.appColors.textSecondary)),
                      ),
                  ],
                ),
              ),
              if (!_isEditing)
                Text(
                  'RM ${(widget.staff['salary'] ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.appColors.accentBlue),
                ),
            ],
          ),
          if (_isEditing) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _salaryController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: context.appColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: tr('monthly_salary_rm'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: context.appColors.surface,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveSalary,
                  style: ElevatedButton.styleFrom(backgroundColor: context.appColors.primaryBlue),
                  child: _isSaving ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(tr('save')),
                ),
              ],
            ),
          ] else ...[
            SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: Icon(Icons.edit, size: 18, color: context.appColors.accentBlue),
              label: Text(tr('edit_salary'), style: TextStyle(color: context.appColors.accentBlue)),
            ),
          ],
        ],
      ),
    );
  }
}
