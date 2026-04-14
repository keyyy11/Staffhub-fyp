import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/staffhub_logo.dart';
import 'login_screen.dart';

/// Supervisor: team attendance, leave, per-staff schedules, clock-in/out notifications.
class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  static const _sectionTitles = ['Attendance', 'Leave', 'Schedules', 'Notifications'];

  int _selectedIndex = 0;
  List<Map<String, dynamic>> _team = [];
  List<Map<String, dynamic>> _attendanceReport = [];
  Map<String, dynamic>? _attendanceStats;
  List<Map<String, dynamic>> _leaveRequests = [];
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
      final results = await Future.wait([
        ApiService.getSupervisorTeam(),
        ApiService.getSupervisorAttendanceReport(),
        ApiService.getSupervisorLeaveRequests(),
        ApiService.getSupervisorNotifications(),
        ApiService.getSupervisorConfig(),
      ]);
      if (!mounted) return;
      final teamR = results[0];
      final attR = results[1];
      final leaveR = results[2];
      final notR = results[3];
      final cfgR = results[4];

      if (teamR['success'] == true && teamR['data'] != null) {
        _team = List<Map<String, dynamic>>.from(teamR['data'] as List);
      }
      if (attR['success'] == true && attR['data'] != null) {
        final d = attR['data'] as Map<String, dynamic>;
        _attendanceReport = List<Map<String, dynamic>>.from(d['report'] as List? ?? []);
        _attendanceStats = d['stats'] as Map<String, dynamic>?;
      }
      if (leaveR['success'] == true && leaveR['data'] != null) {
        _leaveRequests = List<Map<String, dynamic>>.from(leaveR['data'] as List);
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
      _errorMessage = 'Failed to load. Check login and API.';
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
          });
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final saved = await showDialog<bool?>(
      context: context,
      builder: (ctx) => _ScheduleEditorDialog(
        staffId: staffId,
        staffName: name,
        initialDays: days,
        initialNotes: notes,
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
                    StaffHubLogo(height: 48),
                    SizedBox(height: 12),
                    Text('Supervisor', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Team monitoring', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
                          [Icons.access_time, Icons.event_note, Icons.calendar_month, Icons.notifications_active][i],
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
          if (_unreadNotifications > 0 && _selectedIndex != 3)
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
                    _buildAttendanceTab(),
                    _buildLeaveTab(),
                    _buildSchedulesTab(),
                    _buildNotificationsTab(),
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
        itemCount: _leaveRequests.length,
        itemBuilder: (context, i) {
          final r = _leaveRequests[i];
          final st = r['status'] as String? ?? 'pending';
          Color c = AppTheme.textSecondary;
          if (st == 'approved') c = Colors.green;
          if (st == 'rejected') c = Colors.redAccent;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderBlue.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['staffName'] ?? r['staffId'], style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                Text(_leaveTypeLabel(r['leaveType'] as String?), style: const TextStyle(color: AppTheme.accentBlue)),
                Text('${_formatDate(r['startDate'])} → ${_formatDate(r['endDate'])}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                Text(st.toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _team.length,
        itemBuilder: (context, i) {
          final m = _team[i];
          final sid = m['staffId'] as String? ?? '';
          return ListTile(
            tileColor: AppTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.borderBlue.withOpacity(0.35))),
            title: Text(m['name'] ?? sid, style: const TextStyle(color: AppTheme.textPrimary)),
            subtitle: Text(sid, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.edit_calendar, color: AppTheme.accentBlue),
            onTap: () => _openScheduleEditor(m),
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
                final title = type == 'clock_out' ? 'Clock out' : 'Clock in';
                return Dismissible(
                  key: Key(n['_id']?.toString() ?? '$i'),
                  child: ListTile(
                    tileColor: read ? AppTheme.cardDark : AppTheme.cardDark.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: read ? AppTheme.borderBlue.withOpacity(0.2) : AppTheme.accentBlue.withOpacity(0.5)),
                    ),
                    leading: Icon(
                      type == 'clock_out' ? Icons.logout : Icons.login,
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

class _ScheduleEditorDialog extends StatefulWidget {
  const _ScheduleEditorDialog({
    required this.staffId,
    required this.staffName,
    required this.initialDays,
    required this.initialNotes,
  });

  final String staffId;
  final String staffName;
  final List<Map<String, dynamic>> initialDays;
  final String initialNotes;

  @override
  State<_ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<_ScheduleEditorDialog> {
  late List<Map<String, dynamic>> _days;
  late List<TextEditingController> _startControllers;
  late List<TextEditingController> _endControllers;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays.map((e) => Map<String, dynamic>.from(e)).toList();
    _startControllers = [];
    _endControllers = [];
    for (final d in _days) {
      _startControllers.add(TextEditingController(text: d['workStart']?.toString() ?? '09:00'));
      _endControllers.add(TextEditingController(text: d['workEnd']?.toString() ?? '18:00'));
    }
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    for (final c in _startControllers) {
      c.dispose();
    }
    for (final c in _endControllers) {
      c.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    for (var i = 0; i < _days.length; i++) {
      _days[i]['workStart'] = _startControllers[i].text.trim();
      _days[i]['workEnd'] = _endControllers[i].text.trim();
    }
    final clean = _days
        .map(
          (d) => {
            'day': d['day'],
            'isWorkingDay': d['isWorkingDay'] == true,
            'workStart': (d['workStart'] ?? '09:00').toString(),
            'workEnd': (d['workEnd'] ?? '18:00').toString(),
          },
        )
        .toList();
    try {
      final res = await ApiService.putSupervisorStaffSchedule(
        widget.staffId,
        clean,
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, res['success'] == true);
    } catch (_) {
      if (mounted) Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_days.isEmpty) {
      return AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text('Schedule: ${widget.staffName}', style: const TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'No working days could be loaded. Check company work schedule in admin settings.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: AppTheme.cardDark,
      title: Text('Schedule: ${widget.staffName}', style: const TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: ListView(
          children: [
            ..._days.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              final day = row['day'] as String? ?? '';
              return Card(
                color: AppTheme.surfaceDark,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Working day', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        value: row['isWorkingDay'] == true,
                        activeColor: AppTheme.accentBlue,
                        onChanged: (v) => setState(() => _days[i]['isWorkingDay'] = v),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _startControllers[i],
                              decoration: const InputDecoration(
                                labelText: 'Start',
                                labelStyle: TextStyle(color: AppTheme.textSecondary),
                                isDense: true,
                              ),
                              style: const TextStyle(color: AppTheme.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _endControllers[i],
                              decoration: const InputDecoration(
                                labelText: 'End',
                                labelStyle: TextStyle(color: AppTheme.textSecondary),
                                isDense: true,
                              ),
                              style: const TextStyle(color: AppTheme.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Notes for staff',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
