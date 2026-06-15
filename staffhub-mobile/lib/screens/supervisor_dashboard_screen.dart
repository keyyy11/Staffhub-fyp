import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/l10n.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/staffhub_logo.dart';
import '../widgets/staff_schedule_editor_dialog.dart';
import '../widgets/mc_letter_viewer.dart';
import '../widgets/attendance_clock_panel.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'staff_performance_screen.dart';

/// Supervisor: team attendance, leave, per-staff schedules, clock-in/out notifications.
class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> with L10nMixin {

  int _selectedIndex = 0;
  String _supervisorName = '';
  String _homeSearchQuery = '';
  List<Map<String, dynamic>> _team = [];
  List<Map<String, dynamic>> _orgStaff = [];
  List<Map<String, dynamic>> _orgLeaveRequests = [];
  List<Map<String, dynamic>> _orgOvertimeRequests = [];
  List<Map<String, dynamic>> _attendanceReport = [];
  Map<String, dynamic>? _attendanceStats;
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _overtimeRequests = [];
  List<Map<String, dynamic>> _notifications = [];
  int _unreadNotifications = 0;
  String? _expectedTime = '09:00';
  bool _loading = true;
  String? _errorMessage;
  Timer? _pollTimer;

  String _sectionTitle(int index) {
    switch (index) {
      case 0:
        return tr('home');
      case 1:
        return tr('attendance');
      case 2:
        return tr('leave');
      case 3:
        return tr('supervisor_tab_overtime');
      case 4:
        return tr('schedules');
      case 5:
        return tr('notifications');
      default:
        return tr('home');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
    _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) => _pollNotifications());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final me = await AuthService.getCurrentUser();
      if (me != null && mounted) {
        _supervisorName = (me['name'] as String?)?.trim() ?? '';
      }
      final results = await Future.wait([
        ApiService.getSupervisorTeam(),
        ApiService.getSupervisorOrgStaff(),
        ApiService.getSupervisorOrgLeaveRequests(),
        ApiService.getSupervisorOrgOvertimeRequests(),
        ApiService.getSupervisorAttendanceReport(),
        ApiService.getSupervisorLeaveRequests(),
        ApiService.getSupervisorOvertimeRequests(),
        ApiService.getSupervisorNotifications(),
        ApiService.getSupervisorConfig(),
      ]);
      if (!mounted) return;
      final teamR = results[0];
      final orgR = results[1];
      final orgLeaveR = results[2];
      final orgOtR = results[3];
      final attR = results[4];
      final leaveR = results[5];
      final otR = results[6];
      final notR = results[7];
      final cfgR = results[8];

      if (teamR['success'] == true && teamR['data'] != null) {
        _team = List<Map<String, dynamic>>.from(teamR['data'] as List);
      }
      if (orgR['success'] == true && orgR['data'] != null) {
        _orgStaff = List<Map<String, dynamic>>.from(orgR['data'] as List);
      }
      if (orgLeaveR['success'] == true && orgLeaveR['data'] != null) {
        _orgLeaveRequests = List<Map<String, dynamic>>.from(orgLeaveR['data'] as List);
      }
      if (orgOtR['success'] == true && orgOtR['data'] != null) {
        _orgOvertimeRequests = List<Map<String, dynamic>>.from(orgOtR['data'] as List);
      }
      if (attR['success'] == true && attR['data'] != null) {
        final d = attR['data'] as Map<String, dynamic>;
        _attendanceReport = List<Map<String, dynamic>>.from(d['report'] as List? ?? []);
        _attendanceStats = d['stats'] as Map<String, dynamic>?;
      }
      if (leaveR['success'] == true && leaveR['data'] != null) {
        _leaveRequests = List<Map<String, dynamic>>.from(leaveR['data'] as List);
      }
      if (otR['success'] == true && otR['data'] != null) {
        _overtimeRequests = List<Map<String, dynamic>>.from(otR['data'] as List);
      }
      if (notR['success'] == true && notR['data'] != null) {
        final nd = notR['data'] as Map<String, dynamic>;
        _notifications = List<Map<String, dynamic>>.from(nd['list'] as List? ?? []);
        _unreadNotifications = (nd['unreadCount'] as num?)?.toInt() ?? 0;
      }
      if (cfgR['success'] == true && cfgR['data'] != null) {
        _expectedTime = cfgR['data']['expectedClockIn'] as String? ?? _expectedTime;
      }
    } catch (e) {
      final msg = e.toString();
      _errorMessage = msg.contains('Not authenticated')
          ? tr('session_expired')
          : tr('failed_load_detail', {'message': msg});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pollNotifications() async {
    if (!mounted) return;
    try {
      final notR = await ApiService.getSupervisorNotifications();
      if (notR['success'] == true && notR['data'] != null && mounted) {
        final nd = notR['data'] as Map<String, dynamic>;
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(nd['list'] as List? ?? []);
          _unreadNotifications = (nd['unreadCount'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
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

  DateTime? _dateOnly(dynamic d) {
    if (d == null) return null;
    final dt = DateTime.tryParse(d.toString());
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Approved leave where today falls between start and end (inclusive).
  List<Map<String, dynamic>> _approvedLeaveToday() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final list = _orgLeaveRequests.where((r) {
      if ((r['status'] as String?) != 'approved') return false;
      final sd = _dateOnly(r['startDate']);
      final ed = _dateOnly(r['endDate']);
      if (sd == null || ed == null) return false;
      return !today.isBefore(sd) && !today.isAfter(ed);
    }).toList();
    list.sort((a, b) {
      final an = (a['staffName'] as String?) ?? (a['staffId'] as String?) ?? '';
      final bn = (b['staffName'] as String?) ?? (b['staffId'] as String?) ?? '';
      return an.compareTo(bn);
    });
    return list;
  }

  Color _statusColor(String? st) {
    switch (st) {
      case 'approved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.amber;
    }
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
        return tr('approved').toUpperCase();
      case 'rejected':
        return tr('rejected').toUpperCase();
      case 'pending':
        return tr('pending').toUpperCase();
      default:
        return (st ?? '').toUpperCase();
    }
  }

  Future<void> _openScheduleEditor(Map<String, dynamic> member) async {
    final staffId = member['staffId'] as String? ?? '';
    final name = member['name'] as String? ?? staffId;
    List<Map<String, dynamic>> days = [];
    List<Map<String, dynamic>> dateEntries = [];
    String notes = '';
    try {
      final custom = await ApiService.getSupervisorStaffSchedule(staffId);
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
          final res = await ApiService.putSupervisorStaffSchedule(
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
      await _loadAll();
    } else if (saved == false) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('schedule_save_failed'))));
    }
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
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaffHubLogo(height: 58),
                    SizedBox(height: 12),
                    Text(tr('supervisor'), style: TextStyle(color: context.appColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(tr('supervisor_home_org'), style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Divider(color: context.appColors.borderBlue),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (var i = 0; i < 6; i++)
                      ListTile(
                        leading: Icon(
                          [
                            Icons.home_rounded,
                            Icons.access_time,
                            Icons.event_note,
                            Icons.more_time_rounded,
                            Icons.calendar_month,
                            Icons.notifications_active,
                          ][i],
                          color: _selectedIndex == i ? context.appColors.accentBlue : context.appColors.textSecondary,
                        ),
                        title: Text(
                          _sectionTitle(i),
                          style: TextStyle(
                            color: _selectedIndex == i ? context.appColors.accentBlue : context.appColors.textPrimary,
                            fontWeight: _selectedIndex == i ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        selected: _selectedIndex == i,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _selectedIndex = i);
                        },
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.settings_outlined, color: context.appColors.accentBlue),
                title: Text(tr('settings'), style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.redAccent),
                title: Text(tr('logout'), style: TextStyle(color: Colors.redAccent)),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(_sectionTitle(_selectedIndex), style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: context.appColors.surface,
        foregroundColor: context.appColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: context.appColors.accentBlue),
            tooltip: tr('settings'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          if (_unreadNotifications > 0 && _selectedIndex != 5)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text('$_unreadNotifications', style: TextStyle(fontSize: 11)),
                  backgroundColor: Colors.redAccent.withOpacity(0.3),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: context.appColors.accentBlue),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.appColors.accentBlue))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: TextStyle(color: context.appColors.textSecondary)))
              : IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildHomeTab(),
                    _buildAttendanceTab(),
                    _buildLeaveTab(),
                    _buildOvertimeTab(),
                    _buildSchedulesTab(),
                    _buildNotificationsTab(),
                  ],
                ),
    );
  }

  Widget _buildHomeTab() {
    final q = _homeSearchQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _orgStaff
        : _orgStaff.where((s) {
            final id = (s['staffId'] as String? ?? '').toLowerCase();
            final name = (s['name'] as String? ?? '').toLowerCase();
            final dept = (s['department'] as String? ?? '').toLowerCase();
            return id.contains(q) || name.contains(q) || dept.contains(q);
          }).toList();
    final onLeaveToday = _approvedLeaveToday();

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
        color: context.appColors.accentBlue,
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _supervisorName.isNotEmpty ? tr('welcome_name', {'name': _supervisorName}) : tr('welcome'),
              style: TextStyle(color: context.appColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              tr('supervisor_overview_desc'),
              style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.95), fontSize: 13),
            ),
            SizedBox(height: 20),
            Text(
              tr('my_attendance'),
              style: TextStyle(color: context.appColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              tr('clock_branch_hint'),
              style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.95), fontSize: 13),
            ),
            SizedBox(height: 12),
            const AttendanceClockPanel(showSectionTitle: false),
            SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _homeStatCard(
                    tr('organisation'),
                    '${_orgStaff.length}',
                    tr('staff_supervisors_count'),
                    Icons.groups_rounded,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _homeStatCard(
                    tr('direct_team'),
                    '${_team.length}',
                    tr('report_to_you'),
                    Icons.supervisor_account_rounded,
                  ),
                ),
              ],
            ),
            SizedBox(height: 22),
            _homeSectionHeader(tr('overtime_requests'), Icons.more_time_rounded, '${_orgOvertimeRequests.length}'),
            Text(
              tr('all_ot_org'),
              style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.88), fontSize: 12),
            ),
            SizedBox(height: 10),
            if (_orgOvertimeRequests.isEmpty)
              _homeEmptyHint(tr('no_ot_yet'))
            else
              ..._orgOvertimeRequests.map(_homeOvertimeTile),
            SizedBox(height: 22),
            _homeSectionHeader(tr('on_leave_today'), Icons.beach_access_rounded, '${onLeaveToday.length}'),
            Text(
              tr('approved_leave_today'),
              style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.88), fontSize: 12),
            ),
            SizedBox(height: 10),
            if (onLeaveToday.isEmpty)
              _homeEmptyHint(tr('no_one_on_leave'))
            else
              ...onLeaveToday.map(_homeLeaveTodayTile),
            SizedBox(height: 22),
            _homeSectionHeader(tr('directory_search'), Icons.person_search_rounded, null),
            TextField(
              onChanged: (v) => setState(() => _homeSearchQuery = v),
              style: TextStyle(color: context.appColors.textPrimary),
              decoration: InputDecoration(
                hintText: tr('search_hint'),
                hintStyle: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.7)),
                prefixIcon: Icon(Icons.search, color: context.appColors.accentBlue),
                filled: true,
                fillColor: context.appColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.appColors.borderBlue.withValues(alpha: 0.5)),
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              tr('org_directory_count', {'count': '${filtered.length}'}),
              style: TextStyle(color: context.appColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            ...filtered.map(_orgStaffTile),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _orgStaff.isEmpty ? tr('no_org_data') : tr('no_matches'),
                  style: TextStyle(color: context.appColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _homeSectionHeader(String title, IconData icon, String? count) {
    return Row(
      children: [
        Icon(icon, color: context.appColors.accentBlue, size: 22),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            count != null ? '$title ($count)' : title,
            style: TextStyle(color: context.appColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _homeEmptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.9), fontSize: 14)),
    );
  }

  Widget _homeOvertimeTile(Map<String, dynamic> r) {
    final st = r['status'] as String? ?? 'pending';
    final c = _statusColor(st);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['staffName'] ?? r['staffId'] ?? '-',
                  style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  tr('ot_date_hours', {'date': _formatDate(r['otDate']), 'hours': '${r['hours'] ?? '-'}'}),
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_statusLabel(st), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _homeLeaveTodayTile(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline_rounded, color: Colors.tealAccent.shade100, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['staffName'] ?? r['staffId'] ?? '-',
                  style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  '${_leaveTypeLabel(r['leaveType'] as String?)} · ${_formatDate(r['startDate'])} → ${_formatDate(r['endDate'])}',
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 22),
        ],
      ),
    );
  }

  Widget _homeStatCard(String title, String value, String subtitle, IconData icon) {
    return Container(
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
            children: [
              Icon(icon, color: context.appColors.accentBlue, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(value, style: TextStyle(color: context.appColors.textPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(subtitle, style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.9), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _orgStaffTile(Map<String, dynamic> s) {
    final role = s['role'] as String? ?? 'staff';
    final isSup = role == 'supervisor';
    final sid = s['staffId'] as String? ?? '';
    final name = s['name'] as String? ?? sid;
    final reportsTo = (s['supervisorStaffId'] as String?)?.trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSup ? Icons.supervisor_account_rounded : Icons.person_outline_rounded,
            color: context.appColors.accentBlue,
            size: 32,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(sid, style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
                if ((s['email'] as String?)?.isNotEmpty == true)
                  Text(s['email'] as String, style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
                if ((s['department'] as String?)?.isNotEmpty == true)
                  Text(s['department'] as String, style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
                if (!isSup && reportsTo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(tr('reports_to_supervisor', {'id': reportsTo}), style: TextStyle(color: context.appColors.textSecondary, fontSize: 11)),
                  ),
              ],
            ),
          ),
          Chip(
            label: Text(
              isSup ? tr('role_supervisor') : tr('role_staff'),
              style: TextStyle(fontSize: 11, color: isSup ? Colors.deepPurpleAccent.shade100 : context.appColors.textPrimary),
            ),
            backgroundColor: isSup ? Colors.deepPurple.withValues(alpha: 0.22) : context.appColors.surface,
            side: BorderSide(color: context.appColors.borderBlue.withValues(alpha: 0.5)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
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
        color: context.appColors.accentBlue,
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_team.isEmpty)
              Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  tr('no_team_members'),
                  style: TextStyle(color: context.appColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_attendanceStats != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(tr('total'), '${_attendanceStats!['total'] ?? 0}'),
                  _stat(tr('on_time'), '${_attendanceStats!['onTime'] ?? 0}', Colors.green),
                  _stat(tr('late'), '${_attendanceStats!['late'] ?? 0}', Colors.amber),
                ],
              ),
            Text(tr('expected_clock_in_time', {'time': _expectedTime ?? ''}), style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
            SizedBox(height: 12),
            ..._attendanceReport.map((r) {
              final late = (r['status'] as String?) == 'late';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.appColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (late ? Colors.amber : Colors.green).withOpacity(0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['staffName'] ?? r['staffId'], style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.w600)),
                    Text(
                      tr('attendance_date_in_out', {
                        'date': _formatDate(r['date']),
                        'inTime': '${r['clockInTime'] ?? '-'}',
                        'outTime': '${r['clockOutTime'] ?? '-'}',
                      }),
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                    ),
                    Text(late ? tr('late_status') : tr('on_time_status'), style: TextStyle(color: late ? Colors.amber : Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, [Color? c]) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c ?? context.appColors.accentBlue)),
        Text(label, style: TextStyle(fontSize: 12, color: context.appColors.textSecondary)),
      ],
    );
  }

  Widget _buildLeaveTab() {
    return RefreshIndicator(
      color: context.appColors.accentBlue,
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaveRequests.isEmpty ? 2 : _leaveRequests.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                tr('leave_tab_hint'),
                style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.95), fontSize: 13),
              ),
            );
          }
          if (_leaveRequests.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                tr('no_team_leave'),
                style: TextStyle(color: context.appColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            );
          }
          final r = _leaveRequests[i - 1];
          final st = r['status'] as String? ?? 'pending';
          Color c = context.appColors.textSecondary;
          if (st == 'approved') c = Colors.green;
          if (st == 'rejected') c = Colors.redAccent;
          final pending = st == 'pending';
          final id = r['_id']?.toString() ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['staffName'] ?? r['staffId'], style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold)),
                Text(_leaveTypeLabel(r['leaveType'] as String?), style: TextStyle(color: context.appColors.accentBlue)),
                Text(
                  '${tr('working_days_count', {'count': '${r['totalDays'] ?? '-'}'})} · ${_formatDate(r['startDate'])} → ${_formatDate(r['endDate'])}',
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                ),
                if ((r['reason'] as String?)?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(tr('reason_colon', {'reason': '${r['reason']}'}), style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
                  ),
                if (r['hasMcLetter'] == true && id.isNotEmpty) ...[
                  SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => showMcLetterDialog(context, requestId: id, asSupervisor: true),
                    icon: Icon(Icons.description_outlined, size: 18, color: context.appColors.accentBlue),
                    label: Text(tr('view_mc_letter'), style: TextStyle(color: context.appColors.accentBlue)),
                  ),
                ],
                if ((r['adminComment'] as String?)?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(tr('note_colon', {'note': '${r['adminComment']}'}), style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
                  ),
                Text(_statusLabel(st), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
                if (pending && id.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _decideLeave(id, false),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                          child: Text(tr('reject')),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _decideLeave(id, true),
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
    );
  }

  Future<void> _decideLeave(String id, bool approve) async {
    String? comment;
    if (!approve) {
      final commentCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.appColors.card,
          title: Text(tr('reject_leave_title'), style: TextStyle(color: context.appColors.textPrimary)),
          content: TextField(
            controller: commentCtrl,
            style: TextStyle(color: context.appColors.textPrimary),
            decoration: InputDecoration(
              labelText: tr('comment_optional'),
              labelStyle: TextStyle(color: context.appColors.textSecondary),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('reject'))),
          ],
        ),
      );
      final t = commentCtrl.text.trim();
      commentCtrl.dispose();
      if (ok != true || !mounted) return;
      if (t.isNotEmpty) comment = t;
    }
    try {
      final result = await ApiService.supervisorDecideLeave(
        id,
        approve ? 'approved' : 'rejected',
        comment: comment,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? tr('updated'))),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? tr('failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('connection_error'))));
      }
    }
  }

  Future<void> _decideOvertime(String id, bool approve) async {
    String? comment;
    if (!approve) {
      final commentCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.appColors.card,
          title: Text(tr('reject_ot_q'), style: TextStyle(color: context.appColors.textPrimary)),
          content: TextField(
            controller: commentCtrl,
            style: TextStyle(color: context.appColors.textPrimary),
            decoration: InputDecoration(
              labelText: tr('comment_optional'),
              labelStyle: TextStyle(color: context.appColors.textSecondary),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('reject'))),
          ],
        ),
      );
      final t = commentCtrl.text.trim();
      commentCtrl.dispose();
      if (ok != true || !mounted) return;
      if (t.isNotEmpty) comment = t;
    }
    try {
      final result = await ApiService.supervisorDecideOvertime(
        id,
        approve ? 'approved' : 'rejected',
        comment: comment,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? tr('updated'))),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? tr('failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('connection_error'))));
      }
    }
  }

  Widget _buildOvertimeTab() {
    return RefreshIndicator(
      color: context.appColors.accentBlue,
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _overtimeRequests.isEmpty ? 2 : _overtimeRequests.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                tr('ot_tab_hint'),
                style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.95), fontSize: 13),
              ),
            );
          }
          if (_overtimeRequests.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                tr('no_team_ot'),
                style: TextStyle(color: context.appColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            );
          }
          final r = _overtimeRequests[i - 1];
          final st = r['status'] as String? ?? 'pending';
          Color c = context.appColors.textSecondary;
          if (st == 'approved') c = Colors.green;
          if (st == 'rejected') c = Colors.redAccent;
          final pending = st == 'pending';
          final id = r['_id']?.toString() ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['staffName'] ?? r['staffId'], style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold)),
                Text(
                  tr('ot_date_hours', {'date': _formatDate(r['otDate']), 'hours': '${r['hours'] ?? '-'}'}),
                  style: TextStyle(color: context.appColors.accentBlue, fontSize: 13),
                ),
                if ((r['reason'] as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${r['reason']}', style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
                  ),
                if (st != 'pending' && (r['approverComment'] as String?)?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(tr('response_colon', {'response': '${r['approverComment']}'}), style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
                  ),
                Text(_statusLabel(st), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
                if (pending && id.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _decideOvertime(id, false),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                          child: Text(tr('reject')),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _decideOvertime(id, true),
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
    );
  }

  Widget _buildSchedulesTab() {
    return RefreshIndicator(
      color: context.appColors.accentBlue,
      onRefresh: _loadAll,
      child: _team.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                SizedBox(height: 24),
                Icon(Icons.calendar_month_outlined, size: 48, color: context.appColors.textSecondary),
                SizedBox(height: 16),
                Text(
                  tr('no_direct_reports_schedules'),
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _team.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('create_staff_schedules'),
                          style: TextStyle(color: context.appColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          tr('schedules_weekly_desc'),
                          style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.95), fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                final m = _team[i - 1];
                final sid = m['staffId'] as String? ?? '';
                final name = m['name'] as String? ?? sid;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.appColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.4)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openScheduleEditor(m),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline, color: context.appColors.accentBlue, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(color: context.appColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
                                  Text(sid, style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
                                  SizedBox(height: 4),
                                  Text(
                                    tr('tap_edit_weekly_schedule'),
                                    style: TextStyle(color: context.appColors.accentBlue.withValues(alpha: 0.95), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: tr('view_performance'),
                              icon: Icon(Icons.insights_outlined, color: context.appColors.accentBlue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StaffPerformanceScreen(
                                      staffId: sid,
                                      staffName: name,
                                      asSupervisor: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                            Icon(Icons.chevron_right, color: context.appColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNotificationsTab() {
    return RefreshIndicator(
      color: context.appColors.accentBlue,
      onRefresh: () async {
        await _pollNotifications();
        await _loadAll();
      },
      child: Column(
        children: [
          if (_unreadNotifications > 0)
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: () async {
                  await ApiService.markAllSupervisorNotificationsRead();
                  await _pollNotifications();
                },
                child: Text(tr('mark_all_read')),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, i) {
                final n = _notifications[i];
                final read = n['read'] == true;
                final type = n['type'] as String? ?? '';
                final title = type == 'clock_out'
                    ? tr('notification_clock_out')
                    : type == 'ot_request'
                        ? tr('notification_ot_request')
                        : tr('notification_clock_in');
                return Dismissible(
                  key: Key(n['_id']?.toString() ?? '$i'),
                  child: ListTile(
                    tileColor: read ? context.appColors.card : context.appColors.card.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: read ? context.appColors.borderBlue.withOpacity(0.2) : context.appColors.accentBlue.withOpacity(0.5)),
                    ),
                    leading: Icon(
                      type == 'clock_out'
                          ? Icons.logout
                          : type == 'ot_request'
                              ? Icons.more_time_rounded
                              : Icons.login,
                      color: context.appColors.accentBlue,
                    ),
                    title: Text(
                      tr('notification_title_format', {
                        'title': title,
                        'name': '${n['staffName'] ?? n['staffId']}',
                      }),
                      style: TextStyle(color: context.appColors.textPrimary),
                    ),
                    subtitle: Text(
                      n['createdAt']?.toString() ?? '',
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 11),
                    ),
                    onTap: () async {
                      final id = n['_id']?.toString();
                      if (id != null && !read) {
                        await ApiService.markSupervisorNotificationRead(id);
                        await _pollNotifications();
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
