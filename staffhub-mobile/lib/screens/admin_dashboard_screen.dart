import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/staffhub_logo.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'admin_register_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_discipline_screen.dart';

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

  @override
  void initState() {
    super.initState();
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Promote to supervisor?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '$name ($sid) will become a supervisor. They keep the same email and password and will see the supervisor dashboard. Assign other staff to report to supervisor ID: $sid.\n\nContinue?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('Promote'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _promotingStaffId = sid);
    try {
      final result = await ApiService.promoteStaffToSupervisor(sid);
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
                children: const [
                  SizedBox(height: 48),
                  Center(child: Text('No staff or supervisors yet.', style: TextStyle(color: AppTheme.textSecondary))),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _staffList.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        'All staff and supervisors (${_staffList.length}). Names, roles, and reporting lines.',
                        style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.95), fontSize: 13),
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
                    const StaffHubLogo(height: 52),
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
                    _drawerNavTile(index: 0, icon: Icons.groups_rounded, label: 'Staff directory'),
                    _drawerNavTile(index: 1, icon: Icons.access_time_rounded, label: 'Attendance'),
                    _drawerNavTile(index: 2, icon: Icons.event_note_rounded, label: 'Leave requests'),
                    _drawerNavTile(index: 3, icon: Icons.receipt_long_rounded, label: 'Payslip'),
                    _drawerNavTile(index: 4, icon: Icons.payments_rounded, label: 'Staff pay'),
                    _drawerNavTile(index: 5, icon: Icons.supervisor_account_outlined, label: 'Promote to supervisor'),
                    _drawerNavTile(index: 6, icon: Icons.person_add_alt_1_rounded, label: 'Register staff'),
                  ],
                ),
              ),
              const Divider(color: AppTheme.borderBlue, height: 1),
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
            icon: const Icon(Icons.refresh, color: AppTheme.accentBlue),
            tooltip: 'Refresh data',
            onPressed: () {
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
                        'Admin only: choose a staff member to promote. They keep the same login; after promotion, assign other staff to report to their Staff ID in the API or future tools.',
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
    return _AdminRegisterStaffForm(onStaffCreated: _loadStaff);
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

    if (staffId.isEmpty || name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Please fill all fields';
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
      final result = await ApiService.registerStaffByAdmin(staffId, name, email, password);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _isLoading = false;
          _success = true;
          _message = result['message'] as String? ?? 'Staff registered successfully';
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
                      labelText: 'Staff ID',
                      hintText: 'e.g. staff002',
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
