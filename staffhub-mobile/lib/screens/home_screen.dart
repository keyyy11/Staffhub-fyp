import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/leave_balance.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'apply_leave_screen.dart';
import 'apply_overtime_screen.dart';
import 'attendance_history_screen.dart';
import 'payslip_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'work_schedule_screen.dart';
import '../widgets/staffhub_logo.dart';
import '../widgets/attendance_clock_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _staffId = '';
  String _staffName = '';
  List<LeaveBalance> _leaveBalances = [];
  List<Map<String, dynamic>> _leaveRequestsPreview = [];
  List<Map<String, dynamic>> _otRequestsPreview = [];

  @override
  void initState() {
    super.initState();
    // Defer work until after first frame so the shell can paint (reduces ANR risk with Maps + GPS on emulator).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUser();
      // Workplace loads after staffId is known (see _loadUser).
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (user != null && mounted) {
      final staffId = user['staffId'] as String? ?? '';
      final name = (user['name'] as String?)?.trim() ?? '';
      setState(() {
        _staffId = staffId;
        _staffName = name;
      });
      _loadLeaveBalance(staffId);
      // Defer previews so Maps + GPS finish first (reduces emulator ANR / "System UI not responding").
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || staffId.isEmpty) return;
        _loadLeaveRequestsPreview(staffId);
        _loadOvertimePreview();
      });
    }
  }

  Future<void> _loadOvertimePreview() async {
    if (await AuthService.isDemoMode()) return;
    try {
      final result = await ApiService.getMyOvertimeRequests();
      if (result['success'] == true && result['data'] != null && mounted) {
        final list = List<Map<String, dynamic>>.from(result['data'] as List);
        setState(() {
          _otRequestsPreview = list.take(5).toList();
        });
      }
    } catch (_) {}
  }

  String _shortDate(dynamic d) {
    if (d == null) return '-';
    final date = DateTime.parse(d.toString());
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _loadLeaveRequestsPreview(String staffId) async {
    if (staffId.isEmpty) return;
    if (await AuthService.isDemoMode()) return;
    try {
      final result = await ApiService.getMyLeaveRequests(staffId);
      if (result['success'] == true && result['data'] != null && mounted) {
        final list = List<Map<String, dynamic>>.from(result['data'] as List);
        setState(() {
          _leaveRequestsPreview = list.take(5).toList();
        });
      }
    } catch (_) {}
  }

  Color _leaveStatusColor(String? s) {
    switch (s) {
      case 'approved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.amber;
    }
  }

  String _leaveStatusLabel(String? s) {
    switch (s) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  Future<void> _loadLeaveBalance([String? staffId]) async {
    final id = staffId ?? _staffId;
    if (id.isEmpty) return;
    try {
      final result = await ApiService.getLeaveBalance(id);
      if (result['success'] == true && result['data'] != null && mounted) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _leaveBalances = [
            LeaveBalance.fromJson('medical', 'Medical Leave', 'medical_services', data['medicalLeave'] as Map<String, dynamic>? ?? {}),
            LeaveBalance.fromJson('annual', 'Annual Leave', 'event_available', data['annualLeave'] as Map<String, dynamic>? ?? {}),
            LeaveBalance.fromJson('unpaid', 'Unpaid Leave', 'money_off', data['unpaidLeave'] as Map<String, dynamic>? ?? {}),
            LeaveBalance.fromJson('other', 'Other Leave', 'more_horiz', data['otherLeave'] as Map<String, dynamic>? ?? {}),
          ];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _leaveBalances = [
            LeaveBalance(type: 'medical', label: 'Medical Leave', iconData: Icons.medical_services, total: 14, used: 2, remaining: 12),
            LeaveBalance(type: 'annual', label: 'Annual Leave', iconData: Icons.event_available, total: 14, used: 5, remaining: 9),
            LeaveBalance(type: 'unpaid', label: 'Unpaid Leave', iconData: Icons.money_off, total: 0, used: 0, remaining: 0),
            LeaveBalance(type: 'other', label: 'Other Leave', iconData: Icons.more_horiz, total: 5, used: 1, remaining: 4),
          ];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      drawer: Drawer(
        backgroundColor: context.appColors.surface,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: context.appColors.primaryBlue.withOpacity(0.15),
                  border: Border(bottom: BorderSide(color: context.appColors.borderBlue.withOpacity(0.3))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const StaffHubLogo(height: 58),
                    SizedBox(height: 12),
                    if (_staffId.isNotEmpty)
                      Text(
                        'ID: $_staffId',
                        style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.home_outlined, color: context.appColors.accentBlue),
                title: Text('Home', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(Icons.calendar_month_outlined, color: context.appColors.accentBlue),
                title: Text('Work schedule', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkScheduleScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.receipt_long_outlined, color: context.appColors.accentBlue),
                title: Text('Payslip', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayslipScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.history, color: context.appColors.accentBlue),
                title: Text('Attendance history', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.event_available_outlined, color: context.appColors.accentBlue),
                title: Text('Apply leave', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.more_time_rounded, color: context.appColors.accentBlue),
                title: Text('Apply overtime (OT)', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ApplyOvertimeScreen()))
                      .then((_) {
                        if (mounted) _loadOvertimePreview();
                      });
                },
              ),
              Divider(color: context.appColors.borderBlue),
              ListTile(
                leading: Icon(Icons.settings_outlined, color: context.appColors.accentBlue),
                title: Text('Settings', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.person_outline, color: context.appColors.accentBlue),
                title: Text('Profile', style: TextStyle(color: context.appColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.redAccent),
                title: Text('Log out', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: StaffHubLogo(height: 36),
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
            icon: Icon(Icons.person_outline, color: context.appColors.accentBlue),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout, color: context.appColors.accentBlue),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.appColors.surface,
              context.appColors.background,
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  _staffName.isNotEmpty ? _staffName : 'Staff',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: context.appColors.textPrimary,
                  ),
                ),
                if (_staffId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Staff ID: $_staffId',
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                    ),
                  ),
                SizedBox(height: 24),
                AttendanceClockPanel(staffId: _staffId.isNotEmpty ? _staffId : null),
                SizedBox(height: 32),
                Text(
                  'Leave',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.appColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12),
                if (_leaveBalances.isNotEmpty)
                  SizedBox(
                    height: 128,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _leaveBalances.length,
                      itemBuilder: (context, index) {
                        final leave = _leaveBalances[index];
                        return _LeaveCard(leave: leave);
                      },
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.appColors.card.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.appColors.borderBlue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.accentBlue),
                        ),
                        SizedBox(width: 12),
                        Text('Loading leave balance...', style: TextStyle(color: context.appColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  ),
                SizedBox(height: 12),
                if (_leaveRequestsPreview.isNotEmpty) ...[
                  Text(
                    'Leave request responses',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  ..._leaveRequestsPreview.map((r) {
                    final st = r['status'] as String? ?? 'pending';
                    final stColor = _leaveStatusColor(st);
                    final start = r['startDate'] != null ? DateTime.tryParse(r['startDate'].toString()) : null;
                    final end = r['endDate'] != null ? DateTime.tryParse(r['endDate'].toString()) : null;
                    final range = (start != null && end != null)
                        ? '${start.day}/${start.month}–${end.day}/${end.month}'
                        : '';
                    final note = (r['adminComment'] as String?)?.trim();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.appColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: stColor.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  range,
                                  style: TextStyle(color: context.appColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                if (note != null && note.isNotEmpty)
                                  Text(
                                    'Admin: $note',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: stColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _leaveStatusLabel(st),
                              style: TextStyle(color: stColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()),
                        )
                        .then((_) {
                          if (mounted) _loadLeaveRequestsPreview(_staffId);
                        }),
                    icon: Icon(Icons.add_circle_outline, size: 20),
                    label: Text('Apply Leave'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.appColors.accentBlue,
                      side: BorderSide(color: context.appColors.accentBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                SizedBox(height: 32),
                Text(
                  'Overtime (OT)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.appColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your recent OT requests and status (supervisor approval).',
                  style: TextStyle(fontSize: 13, color: context.appColors.textSecondary.withValues(alpha: 0.95)),
                ),
                SizedBox(height: 12),
                if (_otRequestsPreview.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.appColors.card.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'No OT requests yet. Submit one to see it here.',
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
                    ),
                  )
                else
                  ..._otRequestsPreview.map((r) {
                    final st = r['status'] as String? ?? 'pending';
                    final stColor = _leaveStatusColor(st);
                    final hours = r['hours'];
                    final hLabel = hours is num ? '${hours.toString()} h' : '${hours ?? '-'} h';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.appColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: stColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.more_time_rounded, size: 22, color: stColor.withValues(alpha: 0.9)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_shortDate(r['otDate'])} · $hLabel',
                                  style: TextStyle(color: context.appColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                if ((r['reason'] as String?)?.trim().isNotEmpty == true)
                                  Text(
                                    r['reason'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: stColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _leaveStatusLabel(st),
                              style: TextStyle(color: stColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(builder: (_) => const ApplyOvertimeScreen()),
                        )
                        .then((_) {
                          if (mounted) _loadOvertimePreview();
                        }),
                    icon: Icon(Icons.add_circle_outline, size: 20),
                    label: Text('Apply OT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.appColors.accentBlue,
                      side: BorderSide(color: context.appColors.accentBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveBalance leave;

  const _LeaveCard({required this.leave});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.borderBlue.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: context.appColors.primaryBlue.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(leave.iconData, color: context.appColors.accentBlue, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  leave.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '${leave.remaining}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.appColors.accentBlue,
              height: 1.2,
            ),
          ),
          Text(
            'remaining / ${leave.total} days',
            style: TextStyle(
              fontSize: 11,
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
