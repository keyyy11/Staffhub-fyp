import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/staffhub_logo.dart';
import '../widgets/staff_schedule_editor_dialog.dart';
import '../widgets/mc_letter_viewer.dart';
import '../widgets/attendance_clock_panel.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'admin_register_screen.dart';
import 'admin_profile_screen.dart';
import 'settings_screen.dart';
import 'admin_discipline_screen.dart';
import 'admin_overtime_screen.dart';
import 'admin_branches_screen.dart';
import 'admin_staff_edit_screen.dart';

String _roleLabel(dynamic role) {
  final r = role as String?;
  if (r == 'supervisor') return 'Supervisor';
  return 'Staff';
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _sectionTitles = [
    'Home',
    'Staff directory',
    'Attendance',
    'Leave requests',
    'Payslip',
    'Staff pay',
    'Promote to supervisor',
    'Register staff',
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
      if (mounted) setState(() => _errorMessage = 'Failed to load. Ensure you are logged in as admin.');
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
          const SnackBar(content: Text('Failed to load leave requests')),
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
    setState(() => _homeLoading = true);
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 7));
      final sd = _isoDateOnly(start);
      final ed = _isoDateOnly(end);
      final results = await Future.wait([
        ApiService.getAttendanceReport(startDate: sd, endDate: ed),
        ApiService.getAdminLeaveRequests(),
        ApiService.getAdminOvertimeRequests(),
      ]);
      if (!mounted) return;
      final att = results[0];
      final leave = results[1];
      final ot = results[2];
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
        _homeLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _homeLoading = false);
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
            title: Text('Promote to supervisor?', style: TextStyle(color: context.appColors.textPrimary)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$name ($sid) will become a supervisor. Same email and password.\n\n'
                    'Choose whether to keep ID $sid, set a custom supervisor ID, or auto-generate the next SUP### ID. '
                    'If you change the ID, all existing records move to the new ID and the old ID is no longer used.',
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
                      'Auto-generate supervisor ID (SUP…)',
                      style: TextStyle(color: context.appColors.textPrimary, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Replaces current ID in attendance, leave, OT, etc.',
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                    ),
                    activeColor: context.appColors.accentBlue,
                  ),
                  if (!autoSup[0]) ...[
                    SizedBox(height: 8),
                    Text(
                      'New supervisor ID (optional)',
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: 6),
                    TextField(
                      controller: newIdController,
                      style: TextStyle(color: context.appColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Leave empty to keep current ID',
                        hintStyle: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, {'ok': true}),
                style: ElevatedButton.styleFrom(backgroundColor: context.appColors.primaryBlue),
                child: Text('Promote'),
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
          SnackBar(content: Text(result['message'] as String? ?? 'Promoted to supervisor')),
        );
        await _loadStaff();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? 'Failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule saved')));
    } else if (saved == false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save schedule')));
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
                    'My attendance',
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Clock in/out at your assigned branch using GPS geofence.',
                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                  ),
                  SizedBox(height: 12),
                  const AttendanceClockPanel(showSectionTitle: false),
                  SizedBox(height: 24),
                  Text(
                    'Operations overview',
                    style: TextStyle(
                      color: context.appColors.textSecondary.withValues(alpha: 0.95),
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _HomeStatCard(
                          icon: Icons.event_note_rounded,
                          label: 'Leave pending',
                          value: '$pendingLeave',
                          color: Colors.amber.shade200,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _HomeStatCard(
                          icon: Icons.more_time_rounded,
                          label: 'OT pending',
                          value: '$pendingOt',
                          color: context.appColors.accentBlue,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _HomeStatCard(
                          icon: Icons.fact_check_rounded,
                          label: 'Attendance records',
                          value: '${_homeAttendanceStats?['total'] ?? _homeAttendance.length}',
                          color: Colors.greenAccent.shade100,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _selectSection(2),
                        child: Text('Full attendance'),
                      ),
                      TextButton(
                        onPressed: () => _selectSection(3),
                        child: Text('Leave requests'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminOvertimeScreen()),
                          );
                        },
                        child: Text('All overtime'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Attendance activity (last 7 days)',
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
                      child: Text('No attendance records in this period.', style: TextStyle(color: context.appColors.textSecondary)),
                    )
                  else
                    ...attSlice.map((r) => _HomeAttendanceRow(
                          staffName: _staffDisplayName(r['staffId'] as String?, r['staffName'] as String?),
                          staffId: r['staffId'] as String? ?? '',
                          dateText: _formatDate(r['date']),
                          timeLine: 'In ${r['clockInTime'] ?? '-'} · Out ${r['clockOutTime'] ?? '-'}',
                          late: (r['status'] as String?) == 'late',
                        )),
                  SizedBox(height: 20),
                  Text(
                    'Leave requests & supervisors',
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pending: shows reporting supervisor. Completed: who approved.',
                    style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.9), fontSize: 12),
                  ),
                  SizedBox(height: 10),
                  if (leavePending.isEmpty && leaveRecentDone.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No leave requests.', style: TextStyle(color: context.appColors.textSecondary)),
                    )
                  else ...[
                    if (leavePending.isNotEmpty) ...[
                      Text('Awaiting approval', style: TextStyle(color: context.appColors.accentBlue, fontSize: 13, fontWeight: FontWeight.w600)),
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
                      Text('Recent decisions', style: TextStyle(color: context.appColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
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
                    'Overtime (OT)',
                    style: TextStyle(
                      color: context.appColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pending: reported supervisor. Completed: approver name.',
                    style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.9), fontSize: 12),
                  ),
                  SizedBox(height: 10),
                  if (otPending.isEmpty && otRecentDone.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No overtime requests.', style: TextStyle(color: context.appColors.textSecondary)),
                    )
                  else ...[
                    if (otPending.isNotEmpty) ...[
                      Text('Awaiting supervisor', style: TextStyle(color: context.appColors.accentBlue, fontSize: 13, fontWeight: FontWeight.w600)),
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
                      Text('Recent approvals / rejections', style: TextStyle(color: context.appColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
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
                      'No staff or supervisors yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 15),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Create accounts from Register staff — same email/password they use to log in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.85), fontSize: 13),
                    ),
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _selectedIndex = 7),
                      icon: Icon(Icons.person_add_alt_1_rounded, size: 20),
                      label: Text('Add staff'),
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
                              'All staff and supervisors (${_staffList.length}). Names, roles, and reporting lines.',
                              style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.95), fontSize: 13),
                            ),
                          ),
                          SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => setState(() => _selectedIndex = 7),
                            icon: Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: Text('Add staff'),
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
                            'Reports to supervisor ID: $reportsTo',
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
                                onPressed: () => _openAdminScheduleEditor(s),
                                icon: Icon(Icons.schedule_rounded, size: 18, color: context.appColors.accentBlue),
                                label: Text('Weekly schedule', style: TextStyle(color: context.appColors.accentBlue)),
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
                                label: Text('Edit', style: TextStyle(color: context.appColors.accentBlue)),
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
                      'Admin Hub',
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Staff Hub management',
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
                    _drawerNavTile(index: 0, icon: Icons.home_rounded, label: 'Home'),
                    _drawerNavTile(index: 1, icon: Icons.groups_rounded, label: 'Staff directory'),
                    _drawerNavTile(index: 2, icon: Icons.access_time_rounded, label: 'Attendance'),
                    _drawerNavTile(index: 3, icon: Icons.event_note_rounded, label: 'Leave requests'),
                    _drawerNavTile(index: 4, icon: Icons.receipt_long_rounded, label: 'Payslip'),
                    _drawerNavTile(index: 5, icon: Icons.payments_rounded, label: 'Staff pay'),
                    _drawerNavTile(index: 6, icon: Icons.supervisor_account_outlined, label: 'Promote to supervisor'),
                    _drawerNavTile(index: 7, icon: Icons.person_add_alt_1_rounded, label: 'Register staff'),
                  ],
                ),
              ),
              Divider(color: context.appColors.borderBlue, height: 1),
              ListTile(
                leading: Icon(Icons.settings_outlined, color: context.appColors.accentBlue),
                title: Text('Settings', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.person_outline, color: context.appColors.accentBlue),
                title: Text('Admin profile', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.location_on_outlined, color: context.appColors.accentBlue),
                title: Text('Cawangan / Branches', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminBranchesScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.gavel_rounded, color: context.appColors.accentBlue),
                title: Text('Discipline & warnings', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminDisciplineScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.more_time_rounded, color: context.appColors.accentBlue),
                title: Text('Overtime (audit)', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminOvertimeScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.person_add_alt_outlined, color: context.appColors.accentBlue),
                title: Text('Add admin account', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminRegisterScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.redAccent),
                title: Text('Log out', style: TextStyle(color: Colors.redAccent)),
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
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: context.appColors.accentBlue),
            tooltip: 'Refresh data',
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
                    _statItem('Total', _attendanceStats!['total']?.toString() ?? '0', context.appColors.accentBlue),
                    _statItem('On Time', _attendanceStats!['onTime']?.toString() ?? '0', Colors.green),
                    _statItem('Late', _attendanceStats!['late']?.toString() ?? '0', Colors.amber),
                  ],
                ),
              ),
            Text('Expected clock-in: ${_expectedTime ?? '09:00'}', style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
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
                        Text('Clock In: ${r['clockInTime'] ?? '-'} | Out: ${r['clockOutTime'] ?? '-'}', style: TextStyle(fontSize: 12, color: context.appColors.textSecondary)),
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
                      (r['status'] as String?) == 'late' ? 'LATE' : 'ON TIME',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (r['status'] as String?) == 'late' ? Colors.amber : Colors.green),
                    ),
                  ),
                ],
              ),
            )),
            if (_attendanceReport.isEmpty)
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No attendance records', style: TextStyle(color: context.appColors.textSecondary))),
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
        return 'Medical';
      case 'annual':
        return 'Annual';
      case 'unpaid':
        return 'Unpaid';
      case 'other':
        return 'Other';
      default:
        return t ?? '-';
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
          SnackBar(content: Text(result['message'] as String? ?? 'Failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error')));
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
                  label: Text('All'),
                  selected: _leaveStatusFilter == null,
                  onSelected: (_) {
                    setState(() => _leaveStatusFilter = null);
                    _loadLeaveRequests();
                  },
                  selectedColor: context.appColors.primaryBlue,
                  labelStyle: TextStyle(color: _leaveStatusFilter == null ? Colors.white : context.appColors.textSecondary),
                ),
                ChoiceChip(
                  label: Text('Pending'),
                  selected: _leaveStatusFilter == 'pending',
                  onSelected: (_) {
                    setState(() => _leaveStatusFilter = 'pending');
                    _loadLeaveRequests();
                  },
                  selectedColor: context.appColors.primaryBlue,
                  labelStyle: TextStyle(color: _leaveStatusFilter == 'pending' ? Colors.white : context.appColors.textSecondary),
                ),
                ChoiceChip(
                  label: Text('Approved'),
                  selected: _leaveStatusFilter == 'approved',
                  onSelected: (_) {
                    setState(() => _leaveStatusFilter = 'approved');
                    _loadLeaveRequests();
                  },
                  selectedColor: context.appColors.primaryBlue,
                  labelStyle: TextStyle(color: _leaveStatusFilter == 'approved' ? Colors.white : context.appColors.textSecondary),
                ),
                ChoiceChip(
                  label: Text('Rejected'),
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
                                    child: Text(st.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stColor)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text('${_leaveTypeLabel(r['leaveType'] as String?)} · ${r['totalDays'] ?? '-'} working days', style: TextStyle(color: context.appColors.textSecondary, fontSize: 14)),
                              Text(
                                '${_formatDate(r['startDate'])} → ${_formatDate(r['endDate'])}',
                                style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                              ),
                              if ((r['reason'] as String?)?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text('Reason: ${r['reason']}', style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
                                ),
                              if (r['hasMcLetter'] == true && id.isNotEmpty) ...[
                                SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => showMcLetterDialog(context, requestId: id, asAdmin: true),
                                  icon: Icon(Icons.description_outlined, size: 18, color: context.appColors.accentBlue),
                                  label: Text('View MC letter', style: TextStyle(color: context.appColors.accentBlue)),
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
                                        child: Text('Reject'),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _approveLeave(id, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                                        child: Text('Approve'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select staff')));
      return;
    }
    final net = double.tryParse(_payslipNetController.text.trim());
    if (net == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter net pay (number)')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] as String? ?? 'Saved')));
        _payslipNetController.clear();
        _payslipGrossController.clear();
        _payslipRemarksController.clear();
        await _loadPayslipRecords();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] as String? ?? 'Failed')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _payslipSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error')));
      }
    }
  }

  Widget _buildAdminPayslipTab() {
    if (_staffList.isEmpty) {
      return Center(child: Text('No staff in list. Register a staff account first.', style: TextStyle(color: context.appColors.textSecondary)));
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
                    'Enter payslip details for staff. They will see net pay and notes on their Payslip screen.',
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
                            labelText: 'Staff',
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
                                decoration: InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                                onChanged: (v) => setState(() => _payslipMonth = v ?? 1),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _payslipYear,
                                dropdownColor: context.appColors.card,
                                decoration: InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
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
                            labelText: 'Net pay (RM) *',
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
                            labelText: 'Gross salary (RM) — optional',
                            helperText: 'Leave empty to use staff monthly salary',
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
                            labelText: 'HR notes',
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
                                : Text('Save payslip'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Text('Recent records', style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
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
                      child: Text('No payslip records yet.', style: TextStyle(color: context.appColors.textSecondary)),
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
                'Set monthly salary for staff and supervisors. To change a staff member into a supervisor, use the Promote to supervisor section.',
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
                        ? 'No accounts yet. Register staff first.'
                        : 'Everyone is already a supervisor. Register new staff if you need to promote someone.',
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
                        'Admin only: choose a staff member to promote. In the dialog you can keep their ID, set a custom supervisor ID, or auto-generate SUP###. Records move to the new ID if changed.',
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
                          label: Text(busy ? 'Wait…' : 'Promote'),
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
              late ? 'LATE' : 'ON TIME',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: late ? Colors.amber : Colors.green),
            ),
          ),
        ],
      ),
    );
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
        ? 'Supervisor'
        : decidedByRole == 'admin'
            ? 'Admin'
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
                  pending ? 'PENDING' : status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pending ? Colors.amber : context.appColors.textSecondary),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text('$type · $range', style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
          if (pending && supervisorName != null && supervisorName!.isNotEmpty) ...[
            SizedBox(height: 6),
            Text('Reporting supervisor: $supervisorName', style: TextStyle(color: context.appColors.accentBlue, fontSize: 12)),
          ],
          if (!pending && decidedByName != null && decidedByName!.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(
              'Decision: $decidedByName${roleLabel.isNotEmpty ? ' ($roleLabel)' : ''}',
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
                  pending ? 'PENDING' : status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pending ? Colors.amber : context.appColors.textSecondary),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text('OT $otDate · $hours h', style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
          if (pending && supervisorLabel != null && supervisorLabel!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Awaiting supervisor: $supervisorLabel', style: TextStyle(color: context.appColors.accentBlue, fontSize: 12)),
            ),
          if (!pending && approverName != null && approverName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Approved by: $approverName', style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
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

class _AdminRegisterStaffFormState extends State<_AdminRegisterStaffForm> {
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
        _message = 'Please fill name, email, and password';
        _success = false;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _message = 'Password must be at least 6 characters';
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
              ? 'Staff registered. Assigned Staff ID: $assignedId'
              : (result['message'] as String? ?? 'Staff registered successfully');
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
          _message = result['message'] as String? ?? 'Registration failed';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _success = false;
          _message = 'Connection error. Ensure API is running.';
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
              'Create a new staff account. They can sign in with the email and password you set.',
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
                      labelText: 'Staff ID (optional)',
                      hintText: 'Leave empty to auto-generate (STF001, …)',
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
                      labelText: 'Full name',
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
                      labelText: 'Email',
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
                      labelText: 'Temporary password',
                      helperText: 'Minimum 6 characters',
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
                          : Text('Register staff'),
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

class _StaffSalaryCardState extends State<_StaffSalaryCard> {
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
                      labelText: 'Monthly Salary (RM)',
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
                  child: _isSaving ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Save'),
                ),
              ],
            ),
          ] else ...[
            SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: Icon(Icons.edit, size: 18, color: context.appColors.accentBlue),
              label: Text('Edit Salary', style: TextStyle(color: context.appColors.accentBlue)),
            ),
          ],
        ],
      ),
    );
  }
}
