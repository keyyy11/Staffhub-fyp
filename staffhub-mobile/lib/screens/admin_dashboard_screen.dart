import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/staffhub_logo.dart';
import '../widgets/staff_schedule_editor_dialog.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'admin_register_screen.dart';
import 'admin_profile_screen.dart';
import 'settings_screen.dart';
import 'admin_discipline_screen.dart';
import 'admin_overtime_screen.dart';
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
            backgroundColor: AppTheme.cardDark,
            title: const Text('Promote to supervisor?', style: TextStyle(color: AppTheme.textPrimary)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$name ($sid) will become a supervisor. Same email and password.\n\n'
                    'Choose whether to keep ID $sid, set a custom supervisor ID, or auto-generate the next SUP### ID. '
                    'If you change the ID, all existing records move to the new ID and the old ID is no longer used.',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: autoSup[0],
                    onChanged: (v) => setDialogState(() {
                      autoSup[0] = v ?? false;
                      if (autoSup[0]) newIdController.clear();
                    }),
                    title: const Text(
                      'Auto-generate supervisor ID (SUP…)',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Replaces current ID in attendance, leave, OT, etc.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    activeColor: AppTheme.accentBlue,
                  ),
                  if (!autoSup[0]) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'New supervisor ID (optional)',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: newIdController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Leave empty to keep current ID',
                        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, {'ok': true}),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                child: const Text('Promote'),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
          stops: [0.0, 0.2],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadHome(), _loadStaff()]);
        },
        color: AppTheme.accentBlue,
        child: _homeLoading && _homeAttendance.isEmpty && _homeLeave.isEmpty && _homeOvertime.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator(color: AppTheme.accentBlue)),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Operations overview',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.95),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HomeStatCard(
                          icon: Icons.more_time_rounded,
                          label: 'OT pending',
                          value: '$pendingOt',
                          color: AppTheme.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _selectSection(2),
                        child: const Text('Full attendance'),
                      ),
                      TextButton(
                        onPressed: () => _selectSection(3),
                        child: const Text('Leave requests'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminOvertimeScreen()),
                          );
                        },
                        child: const Text('All overtime'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Attendance activity (last 7 days)',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (attSlice.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No attendance records in this period.', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  else
                    ...attSlice.map((r) => _HomeAttendanceRow(
                          staffName: _staffDisplayName(r['staffId'] as String?, r['staffName'] as String?),
                          staffId: r['staffId'] as String? ?? '',
                          dateText: _formatDate(r['date']),
                          timeLine: 'In ${r['clockInTime'] ?? '-'} · Out ${r['clockOutTime'] ?? '-'}',
                          late: (r['status'] as String?) == 'late',
                        )),
                  const SizedBox(height: 20),
                  const Text(
                    'Leave requests & supervisors',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pending: shows reporting supervisor. Completed: who approved.',
                    style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  if (leavePending.isEmpty && leaveRecentDone.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No leave requests.', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  else ...[
                    if (leavePending.isNotEmpty) ...[
                      const Text('Awaiting approval', style: TextStyle(color: AppTheme.accentBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
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
                      const SizedBox(height: 12),
                      const Text('Recent decisions', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
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
                  const SizedBox(height: 20),
                  const Text(
                    'Overtime (OT)',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pending: reported supervisor. Completed: approver name.',
                    style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  if (otPending.isEmpty && otRecentDone.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No overtime requests.', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  else ...[
                    if (otPending.isNotEmpty) ...[
                      const Text('Awaiting supervisor', style: TextStyle(color: AppTheme.accentBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
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
                      const SizedBox(height: 12),
                      const Text('Recent approvals / rejections', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
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
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildStaffDirectoryTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
          stops: [0.0, 0.2],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadStaff,
        color: AppTheme.accentBlue,
        child: _staffList.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 48),
                  Icon(Icons.groups_outlined, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'No staff or supervisors yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Create accounts from Register staff — same email/password they use to log in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.85), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _selectedIndex = 7),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                      label: const Text('Add staff'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
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
                              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.95), fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => setState(() => _selectedIndex = 7),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text('Add staff'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
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
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.45)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isSupervisor ? Icons.supervisor_account_rounded : Icons.person_outline_rounded,
                              color: AppTheme.accentBlue,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(sid, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                  if (email.isNotEmpty)
                                    Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(
                                _roleLabel(role),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSupervisor ? Colors.deepPurpleAccent.shade100 : AppTheme.textPrimary,
                                ),
                              ),
                              backgroundColor: isSupervisor
                                  ? Colors.deepPurple.withValues(alpha: 0.25)
                                  : AppTheme.surfaceDark,
                              side: BorderSide(color: AppTheme.borderBlue.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        if (!isSupervisor && reportsTo.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Reports to supervisor ID: $reportsTo',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: () => _openAdminScheduleEditor(s),
                                icon: const Icon(Icons.schedule_rounded, size: 18, color: AppTheme.accentBlue),
                                label: const Text('Weekly schedule', style: TextStyle(color: AppTheme.accentBlue)),
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
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.accentBlue),
                                label: const Text('Edit', style: TextStyle(color: AppTheme.accentBlue)),
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
      selectedColor: AppTheme.accentBlue,
      selectedTileColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(
        icon,
        color: selected ? AppTheme.accentBlue : AppTheme.textSecondary,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.accentBlue : AppTheme.textPrimary,
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
      backgroundColor: AppTheme.backgroundBlack,
      drawer: Drawer(
        backgroundColor: AppTheme.surfaceDark,
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
                    const SizedBox(height: 14),
                    const Text(
                      'Admin Hub',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Staff Hub management',
                      style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: AppTheme.borderBlue, height: 1),
              ),
              const SizedBox(height: 8),
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
              const Divider(color: AppTheme.borderBlue, height: 1),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: AppTheme.accentBlue),
                title: const Text('Settings', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline, color: AppTheme.accentBlue),
                title: const Text('Admin profile', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.gavel_rounded, color: AppTheme.accentBlue),
                title: const Text('Discipline & warnings', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminDisciplineScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.more_time_rounded, color: AppTheme.accentBlue),
                title: const Text('Overtime (audit)', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminOvertimeScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_outlined, color: AppTheme.accentBlue),
                title: const Text('Add admin account', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminRegisterScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(context).pop();
                  _logout();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(
          _sectionTitles[_selectedIndex],
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.accentBlue),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accentBlue),
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
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
          stops: [0.0, 0.2],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadAttendance,
        color: AppTheme.accentBlue,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_attendanceStats != null)
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Total', _attendanceStats!['total']?.toString() ?? '0', AppTheme.accentBlue),
                    _statItem('On Time', _attendanceStats!['onTime']?.toString() ?? '0', Colors.green),
                    _statItem('Late', _attendanceStats!['late']?.toString() ?? '0', Colors.amber),
                  ],
                ),
              ),
            Text('Expected clock-in: ${_expectedTime ?? '09:00'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            ..._attendanceReport.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _staffDisplayName(r['staffId'] as String?, r['staffName'] as String?),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        Text(
                          '${r['staffId']} • ${_formatDate(r['date'])}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        Text('Clock In: ${r['clockInTime'] ?? '-'} | Out: ${r['clockOutTime'] ?? '-'}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No attendance records', style: TextStyle(color: AppTheme.textSecondary))),
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
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
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
                  label: const Text('All'),
                  selected: _leaveStatusFilter == null,
                  onSelected: (_) {
                    setState(() => _leaveStatusFilter = null);
                    _loadLeaveRequests();
                  },
                  selectedColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(color: _leaveStatusFilter == null ? Colors.white : AppTheme.textSecondary),
                ),
                ChoiceChip(
                  label: const Text('Pending'),
                  selected: _leaveStatusFilter == 'pending',
                  onSelected: (_) {
                    setState(() => _leaveStatusFilter = 'pending');
                    _loadLeaveRequests();
                  },
                  selectedColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(color: _leaveStatusFilter == 'pending' ? Colors.white : AppTheme.textSecondary),
                ),
                ChoiceChip(
                  label: const Text('Approved'),
                  selected: _leaveStatusFilter == 'approved',
                  onSelected: (_) {
                    setState(() => _leaveStatusFilter = 'approved');
                    _loadLeaveRequests();
                  },
                  selectedColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(color: _leaveStatusFilter == 'approved' ? Colors.white : AppTheme.textSecondary),
                ),
                ChoiceChip(
                  label: const Text('Rejected'),
                  selected: _leaveStatusFilter == 'rejected',
                  onSelected: (_) {
                    setState(() => _leaveStatusFilter = 'rejected');
                    _loadLeaveRequests();
                  },
                  selectedColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(color: _leaveStatusFilter == 'rejected' ? Colors.white : AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: _leaveLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
                : RefreshIndicator(
                    onRefresh: _loadLeaveRequests,
                    color: AppTheme.accentBlue,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _leaveRequests.length,
                      itemBuilder: (context, i) {
                        final r = _leaveRequests[i];
                        final id = r['_id']?.toString() ?? '';
                        final pending = (r['status'] as String?) == 'pending';
                        final st = r['status'] as String? ?? '';
                        Color stColor = AppTheme.textSecondary;
                        if (st == 'approved') stColor = Colors.green;
                        if (st == 'rejected') stColor = Colors.redAccent;
                        if (st == 'pending') stColor = Colors.amber;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardDark,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.borderBlue.withOpacity(0.45)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _staffDisplayName(r['staffId'] as String?, r['staffName'] as String?),
                                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
                              const SizedBox(height: 6),
                              Text('${_leaveTypeLabel(r['leaveType'] as String?)} · ${r['totalDays'] ?? '-'} working days', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                              Text(
                                '${_formatDate(r['startDate'])} → ${_formatDate(r['endDate'])}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                              if ((r['reason'] as String?)?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text('Reason: ${r['reason']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                ),
                              if (pending && id.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _approveLeave(id, false),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                                        child: const Text('Reject'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _approveLeave(id, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                                        child: const Text('Approve'),
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
      return const Center(child: Text('No staff in list. Register a staff account first.', style: TextStyle(color: AppTheme.textSecondary)));
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
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
              color: AppTheme.accentBlue,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Enter payslip details for staff. They will see net pay and notes on their Payslip screen.',
                    style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.95), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _payslipSelectedStaffId,
                          dropdownColor: AppTheme.cardDark,
                          decoration: const InputDecoration(
                            labelText: 'Staff',
                            labelStyle: TextStyle(color: AppTheme.textSecondary),
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                          items: _staffList.map((s) {
                            final id = s['staffId'] as String? ?? '';
                            final name = s['name'] as String? ?? '';
                            final role = _roleLabel(s['role']);
                            return DropdownMenuItem(value: id, child: Text('$name ($id) · $role'));
                          }).toList(),
                          onChanged: (v) => setState(() => _payslipSelectedStaffId = v),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _payslipMonth,
                                dropdownColor: AppTheme.cardDark,
                                decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                                onChanged: (v) => setState(() => _payslipMonth = v ?? 1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _payslipYear,
                                dropdownColor: AppTheme.cardDark,
                                decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                                items: List.generate(5, (i) {
                                  final y = DateTime.now().year - 2 + i;
                                  return DropdownMenuItem(value: y, child: Text('$y'));
                                }),
                                onChanged: (v) => setState(() => _payslipYear = v ?? DateTime.now().year),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _payslipNetController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Net pay (RM) *',
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _payslipGrossController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Gross salary (RM) — optional',
                            helperText: 'Leave empty to use staff monthly salary',
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _payslipRemarksController,
                          maxLines: 2,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'HR notes',
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _payslipSaving ? null : _saveAdminPayslip,
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                            child: _payslipSaving
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Save payslip'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Recent records', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._payslipRecords.take(20).map((p) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${p['staffId']} · ${p['month']}/${p['year']}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            ),
                          ),
                          Text(
                            'RM ${(p['netPay'] as num?)?.toStringAsFixed(2) ?? '-'}',
                            style: const TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_payslipRecords.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No payslip records yet.', style: TextStyle(color: AppTheme.textSecondary)),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
          stops: [0.0, 0.2],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadStaff,
        color: AppTheme.accentBlue,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Set monthly salary for staff and supervisors. To change a staff member into a supervisor, use the Promote to supervisor section.',
                style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.95), fontSize: 13),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
          stops: [0.0, 0.2],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadStaff,
        color: AppTheme.accentBlue,
        child: staffOnly.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 32),
                  Icon(Icons.supervisor_account_outlined, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  Text(
                    _staffList.isEmpty
                        ? 'No accounts yet. Register staff first.'
                        : 'Everyone is already a supervisor. Register new staff if you need to promote someone.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                        style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.95), fontSize: 13),
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
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person_outline_rounded, color: AppTheme.accentBlue, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                              Text(sid, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              if (email.isNotEmpty)
                                Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: busy ? null : () => _confirmPromoteStaffToSupervisor(s),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.arrow_upward_rounded, size: 18),
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (late ? Colors.amber : Colors.green).withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(late ? Icons.schedule_rounded : Icons.check_circle_outline_rounded, color: late ? Colors.amber : Colors.green, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staffName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                Text('$staffId · $dateText', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text(timeLine, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(staffName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: pending ? Colors.amber.withValues(alpha: 0.2) : Colors.blueGrey.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pending ? 'PENDING' : status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pending ? Colors.amber : AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('$type · $range', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          if (pending && supervisorName != null && supervisorName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reporting supervisor: $supervisorName', style: const TextStyle(color: AppTheme.accentBlue, fontSize: 12)),
          ],
          if (!pending && decidedByName != null && decidedByName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Decision: $decidedByName${roleLabel.isNotEmpty ? ' ($roleLabel)' : ''}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(staffName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: pending ? Colors.amber.withValues(alpha: 0.2) : Colors.blueGrey.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pending ? 'PENDING' : status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pending ? Colors.amber : AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('OT $otDate · $hours h', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          if (pending && supervisorLabel != null && supervisorLabel!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Awaiting supervisor: $supervisorLabel', style: const TextStyle(color: AppTheme.accentBlue, fontSize: 12)),
            ),
          if (!pending && approverName != null && approverName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Approved by: $approverName', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
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
              style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.95), fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5)),
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
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Staff ID (optional)',
                      hintText: 'Leave empty to auto-generate (STF001, …)',
                      prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.accentBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: const Icon(Icons.person_outline, color: AppTheme.accentBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.accentBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Temporary password',
                      helperText: 'Minimum 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.accentBlue),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Register staff'),
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person, color: AppTheme.accentBlue, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.staff['name'] ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    Text(widget.staff['staffId'] ?? '-', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(
                          _roleLabel(widget.staff['role']),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        backgroundColor: AppTheme.surfaceDark,
                        side: BorderSide(color: AppTheme.borderBlue.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    if (widget.staff['department'] != null && (widget.staff['department'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(widget.staff['department'], style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ),
                  ],
                ),
              ),
              if (!_isEditing)
                Text(
                  'RM ${(widget.staff['salary'] ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentBlue),
                ),
            ],
          ),
          if (_isEditing) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _salaryController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Monthly Salary (RM)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveSalary,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit, size: 18, color: AppTheme.accentBlue),
              label: const Text('Edit Salary', style: TextStyle(color: AppTheme.accentBlue)),
            ),
          ],
        ],
      ),
    );
  }
}
