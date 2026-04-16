import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/staffhub_logo.dart';
import '../widgets/staff_schedule_editor_dialog.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

/// Supervisor: team attendance, leave, per-staff schedules, clock-in/out notifications.
class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  static const _sectionTitles = ['Home', 'Attendance', 'Leave', 'Overtime', 'Schedules', 'Notifications'];

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
          ? 'Session expired. Please log in again.'
          : 'Failed to load: $msg';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule saved')));
      await _loadAll();
    } else if (saved == false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save schedule')));
    }
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
              const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaffHubLogo(height: 58),
                    SizedBox(height: 12),
                    Text('Supervisor', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Home & organisation', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const Divider(color: AppTheme.borderBlue),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (var i = 0; i < _sectionTitles.length; i++)
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
                          color: _selectedIndex == i ? AppTheme.accentBlue : AppTheme.textSecondary,
                        ),
                        title: Text(
                          _sectionTitles[i],
                          style: TextStyle(
                            color: _selectedIndex == i ? AppTheme.accentBlue : AppTheme.textPrimary,
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
                leading: const Icon(Icons.settings_outlined, color: AppTheme.accentBlue),
                title: const Text('Settings', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(_sectionTitles[_selectedIndex], style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.accentBlue),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          if (_unreadNotifications > 0 && _selectedIndex != 5)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text('$_unreadNotifications', style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.redAccent.withOpacity(0.3),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accentBlue),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.textSecondary)))
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
          stops: [0.0, 0.2],
        ),
      ),
      child: RefreshIndicator(
        color: AppTheme.accentBlue,
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _supervisorName.isNotEmpty ? 'Welcome, $_supervisorName' : 'Welcome',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Overview: all OT requests and who is on approved leave today. Directory below (admin excluded). Other tabs focus on your direct team where applicable.',
              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.95), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _homeStatCard(
                    'Organisation',
                    '${_orgStaff.length}',
                    'staff & supervisors',
                    Icons.groups_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _homeStatCard(
                    'Direct team',
                    '${_team.length}',
                    'report to you',
                    Icons.supervisor_account_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _homeSectionHeader('Overtime requests', Icons.more_time_rounded, '${_orgOvertimeRequests.length}'),
            Text(
              'All OT applications from organisation staff & supervisors.',
              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.88), fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (_orgOvertimeRequests.isEmpty)
              _homeEmptyHint('No overtime requests yet.')
            else
              ..._orgOvertimeRequests.map(_homeOvertimeTile),
            const SizedBox(height: 22),
            _homeSectionHeader('On leave today', Icons.beach_access_rounded, '${onLeaveToday.length}'),
            Text(
              'Approved leave covering today’s date.',
              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.88), fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (onLeaveToday.isEmpty)
              _homeEmptyHint('No one on approved leave today.')
            else
              ...onLeaveToday.map(_homeLeaveTodayTile),
            const SizedBox(height: 22),
            _homeSectionHeader('Directory search', Icons.person_search_rounded, null),
            TextField(
              onChanged: (v) => setState(() => _homeSearchQuery = v),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name, ID, department…',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                prefixIcon: const Icon(Icons.search, color: AppTheme.accentBlue),
                filled: true,
                fillColor: AppTheme.cardDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderBlue.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'All staff & supervisors (admin excluded) · ${filtered.length} shown',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...filtered.map(_orgStaffTile),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _orgStaff.isEmpty ? 'No organisation data loaded.' : 'No matches for your search.',
                  style: const TextStyle(color: AppTheme.textSecondary),
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
        Icon(icon, color: AppTheme.accentBlue, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            count != null ? '$title ($count)' : title,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _homeEmptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), fontSize: 14)),
    );
  }

  Widget _homeOvertimeTile(Map<String, dynamic> r) {
    final st = r['status'] as String? ?? 'pending';
    final c = _statusColor(st);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
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
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  'OT date ${_formatDate(r['otDate'])} · ${r['hours'] ?? '-'} h',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
            child: Text(st.toUpperCase(), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline_rounded, color: Colors.tealAccent.shade100, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['staffName'] ?? r['staffId'] ?? '-',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  '${_leaveTypeLabel(r['leaveType'] as String?)} · ${_formatDate(r['startDate'])} → ${_formatDate(r['endDate'])}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 22),
        ],
      ),
    );
  }

  Widget _homeStatCard(String title, String value, String subtitle, IconData icon) {
    return Container(
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
            children: [
              Icon(icon, color: AppTheme.accentBlue, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(subtitle, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), fontSize: 11)),
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
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSup ? Icons.supervisor_account_rounded : Icons.person_outline_rounded,
            color: AppTheme.accentBlue,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(sid, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if ((s['email'] as String?)?.isNotEmpty == true)
                  Text(s['email'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if ((s['department'] as String?)?.isNotEmpty == true)
                  Text(s['department'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if (!isSup && reportsTo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Reports to supervisor ID: $reportsTo', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ),
              ],
            ),
          ),
          Chip(
            label: Text(
              isSup ? 'Supervisor' : 'Staff',
              style: TextStyle(fontSize: 11, color: isSup ? Colors.deepPurpleAccent.shade100 : AppTheme.textPrimary),
            ),
            backgroundColor: isSup ? Colors.deepPurple.withValues(alpha: 0.22) : AppTheme.surfaceDark,
            side: BorderSide(color: AppTheme.borderBlue.withValues(alpha: 0.5)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
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
        color: AppTheme.accentBlue,
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_team.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No team members yet. Ask admin to assign staff to you (set supervisor Staff ID on each staff account).',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_attendanceStats != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('Total', '${_attendanceStats!['total'] ?? 0}'),
                  _stat('On time', '${_attendanceStats!['onTime'] ?? 0}', Colors.green),
                  _stat('Late', '${_attendanceStats!['late'] ?? 0}', Colors.amber),
                ],
              ),
            Text('Expected clock-in: $_expectedTime', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            ..._attendanceReport.map((r) {
              final late = (r['status'] as String?) == 'late';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (late ? Colors.amber : Colors.green).withOpacity(0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['staffName'] ?? r['staffId'], style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    Text('${_formatDate(r['date'])} · In ${r['clockInTime'] ?? '-'} · Out ${r['clockOutTime'] ?? '-'}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    Text(late ? 'LATE' : 'ON TIME', style: TextStyle(color: late ? Colors.amber : Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
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
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c ?? AppTheme.accentBlue)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildLeaveTab() {
    return RefreshIndicator(
      color: AppTheme.accentBlue,
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaveRequests.isEmpty ? 2 : _leaveRequests.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                'Approve or reject leave from staff who report to you. Pending requests show Approve / Reject.',
                style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.95), fontSize: 13),
              ),
            );
          }
          if (_leaveRequests.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No leave requests from your team.',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            );
          }
          final r = _leaveRequests[i - 1];
          final st = r['status'] as String? ?? 'pending';
          Color c = AppTheme.textSecondary;
          if (st == 'approved') c = Colors.green;
          if (st == 'rejected') c = Colors.redAccent;
          final pending = st == 'pending';
          final id = r['_id']?.toString() ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['staffName'] ?? r['staffId'], style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                Text(_leaveTypeLabel(r['leaveType'] as String?), style: const TextStyle(color: AppTheme.accentBlue)),
                Text(
                  '${r['totalDays'] ?? '-'} working days · ${_formatDate(r['startDate'])} → ${_formatDate(r['endDate'])}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                if ((r['reason'] as String?)?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Reason: ${r['reason']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ),
                if ((r['adminComment'] as String?)?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Note: ${r['adminComment']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                Text(st.toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
                if (pending && id.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _decideLeave(id, false),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _decideLeave(id, true),
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
    );
  }

  Future<void> _decideLeave(String id, bool approve) async {
    String? comment;
    if (!approve) {
      final commentCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          title: const Text('Reject leave?', style: TextStyle(color: AppTheme.textPrimary)),
          content: TextField(
            controller: commentCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              labelStyle: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
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
          SnackBar(content: Text(result['message'] as String? ?? 'Updated')),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? 'Failed')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error')));
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
          backgroundColor: AppTheme.cardDark,
          title: const Text('Reject OT?', style: TextStyle(color: AppTheme.textPrimary)),
          content: TextField(
            controller: commentCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              labelStyle: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
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
          SnackBar(content: Text(result['message'] as String? ?? 'Updated')),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? 'Failed')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error')));
      }
    }
  }

  Widget _buildOvertimeTab() {
    return RefreshIndicator(
      color: AppTheme.accentBlue,
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _overtimeRequests.isEmpty ? 2 : _overtimeRequests.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                'Approve or reject OT from your direct team. Pending requests show Approve / Reject.',
                style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.95), fontSize: 13),
              ),
            );
          }
          if (_overtimeRequests.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No overtime requests from your team.',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            );
          }
          final r = _overtimeRequests[i - 1];
          final st = r['status'] as String? ?? 'pending';
          Color c = AppTheme.textSecondary;
          if (st == 'approved') c = Colors.green;
          if (st == 'rejected') c = Colors.redAccent;
          final pending = st == 'pending';
          final id = r['_id']?.toString() ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['staffName'] ?? r['staffId'], style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                Text('OT date ${_formatDate(r['otDate'])} · ${r['hours'] ?? '-'} h', style: const TextStyle(color: AppTheme.accentBlue, fontSize: 13)),
                if ((r['reason'] as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${r['reason']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ),
                if (st != 'pending' && (r['approverComment'] as String?)?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Response: ${r['approverComment']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                Text(st.toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
                if (pending && id.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _decideOvertime(id, false),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _decideOvertime(id, true),
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
    );
  }

  Widget _buildSchedulesTab() {
    return RefreshIndicator(
      color: AppTheme.accentBlue,
      onRefresh: _loadAll,
      child: _team.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 24),
                Icon(Icons.calendar_month_outlined, size: 48, color: AppTheme.textSecondary),
                SizedBox(height: 16),
                Text(
                  'No direct reports yet. Ask admin to assign staff to your supervisor Staff ID, then you can create a weekly schedule for each person.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                        const Text(
                          'Create staff schedules',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Set a new weekly timetable (Mon–Sun) for each team member — working days, start/end times, and notes. Saving creates or updates their schedule.',
                          style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.95), fontSize: 13),
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
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.4)),
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
                            const Icon(Icons.add_circle_outline, color: AppTheme.accentBlue, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
                                  Text(sid, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to create or edit weekly schedule',
                                    style: TextStyle(color: AppTheme.accentBlue.withValues(alpha: 0.95), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
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
      color: AppTheme.accentBlue,
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
                child: const Text('Mark all as read'),
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
                    ? 'Clock out'
                    : type == 'ot_request'
                        ? 'OT request'
                        : 'Clock in';
                return Dismissible(
                  key: Key(n['_id']?.toString() ?? '$i'),
                  child: ListTile(
                    tileColor: read ? AppTheme.cardDark : AppTheme.cardDark.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: read ? AppTheme.borderBlue.withOpacity(0.2) : AppTheme.accentBlue.withOpacity(0.5)),
                    ),
                    leading: Icon(
                      type == 'clock_out'
                          ? Icons.logout
                          : type == 'ot_request'
                              ? Icons.more_time_rounded
                              : Icons.login,
                      color: AppTheme.accentBlue,
                    ),
                    title: Text('$title — ${n['staffName'] ?? n['staffId']}', style: const TextStyle(color: AppTheme.textPrimary)),
                    subtitle: Text(
                      n['createdAt']?.toString() ?? '',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
