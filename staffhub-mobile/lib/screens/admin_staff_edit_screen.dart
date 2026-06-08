import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

/// Admin: edit staff/supervisor details and assign supervisor (staff only).
class AdminStaffEditScreen extends StatefulWidget {
  const AdminStaffEditScreen({
    super.key,
    required this.staff,
    required this.allStaff,
  });

  final Map<String, dynamic> staff;
  final List<Map<String, dynamic>> allStaff;

  @override
  State<AdminStaffEditScreen> createState() => _AdminStaffEditScreenState();
}

class _AdminStaffEditScreenState extends State<AdminStaffEditScreen> {
  late final String _staffId;
  late final String _initialSupervisorId;
  late final String _role;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _supervisorStaffId = '';
  String _branchCode = '';
  List<Map<String, dynamic>> _branches = [];
  bool _loadingBranches = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    _staffId = s['staffId'] as String? ?? '';
    _role = s['role'] as String? ?? 'staff';
    _initialSupervisorId = (s['supervisorStaffId'] as String?)?.trim() ?? '';
    _supervisorStaffId = _initialSupervisorId;
    _branchCode = (s['branchCode'] as String?)?.trim() ?? '';

    _nameController.text = s['name'] as String? ?? '';
    _emailController.text = s['email'] as String? ?? '';
    _phoneController.text = s['phone'] as String? ?? '';
    _departmentController.text = s['department'] as String? ?? '';
    _positionController.text = s['position'] as String? ?? '';
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final result = await ApiService.getAdminBranches();
      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        final list = List<Map<String, dynamic>>.from(result['data'] as List);
        setState(() {
          _branches = list.where((b) => b['isActive'] != false).toList();
          _loadingBranches = false;
        });
      } else {
        setState(() => _loadingBranches = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBranches = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _supervisors {
    return widget.allStaff
        .where((m) => (m['role'] as String?) == 'supervisor')
        .toList()
      ..sort((a, b) {
        final na = (a['name'] as String? ?? '').toLowerCase();
        final nb = (b['name'] as String? ?? '').toLowerCase();
        return na.compareTo(nb);
      });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email are required.')),
      );
      return;
    }
    final pw = _passwordController.text;
    final pw2 = _confirmPasswordController.text;
    if (pw.isNotEmpty || pw2.isNotEmpty) {
      if (pw != pw2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match.')),
        );
        return;
      }
      if (pw.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 6 characters.')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final update = await ApiService.adminUpdateStaff(
        _staffId,
        name: name,
        email: email,
        phone: _phoneController.text.trim(),
        department: _departmentController.text.trim(),
        position: _positionController.text.trim(),
        newPassword: pw.isEmpty ? null : pw,
        branchCode: _branchCode,
      );
      if (update['success'] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(update['message']?.toString() ?? 'Update failed')),
        );
        return;
      }

      if (_role == 'staff') {
        final next = _supervisorStaffId.trim();
        if (next != _initialSupervisorId) {
          final assign = await ApiService.adminAssignSupervisor(_staffId, next);
          if (assign['success'] != true) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  assign['message']?.toString() ?? 'Profile updated but supervisor assignment failed',
                ),
              ),
            );
            Navigator.of(context).pop(true);
            return;
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = _role == 'staff';
    final roleLabel = _role == 'supervisor' ? 'Supervisor' : 'Staff';

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit staff'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.appColors.surface, context.appColors.background],
            stops: [0.0, 0.25],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '$_staffId · $roleLabel',
              style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: TextStyle(color: context.appColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: context.appColors.textSecondary),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: context.appColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: context.appColors.textSecondary),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: context.appColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Phone',
                labelStyle: TextStyle(color: context.appColors.textSecondary),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _departmentController,
              style: TextStyle(color: context.appColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Department',
                labelStyle: TextStyle(color: context.appColors.textSecondary),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _positionController,
              style: TextStyle(color: context.appColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Position',
                labelStyle: TextStyle(color: context.appColors.textSecondary),
              ),
            ),
            if (isStaff) ...[
              SizedBox(height: 20),
              Text(
                'Reporting supervisor',
                style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
              ),
              SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final orphan = _supervisorStaffId.isNotEmpty &&
                      !_supervisors.any((m) => (m['staffId'] as String?) == _supervisorStaffId);
                  final items = <DropdownMenuItem<String?>>[
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— None —', style: TextStyle(color: context.appColors.textPrimary)),
                    ),
                    if (orphan)
                      DropdownMenuItem<String?>(
                        value: _supervisorStaffId,
                        child: Text(
                          '$_supervisorStaffId (current ID)',
                          style: TextStyle(color: context.appColors.textSecondary),
                        ),
                      ),
                    ..._supervisors.map((sup) {
                      final sid = sup['staffId'] as String? ?? '';
                      final nm = sup['name'] as String? ?? sid;
                      return DropdownMenuItem<String?>(
                        value: sid,
                        child: Text('$nm ($sid)', style: TextStyle(color: context.appColors.textPrimary)),
                      );
                    }),
                  ];
                  return DropdownButtonFormField<String?>(
                    value: _supervisorStaffId.isEmpty ? null : _supervisorStaffId,
                    dropdownColor: context.appColors.card,
                    style: TextStyle(color: context.appColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Supervisor',
                      labelStyle: TextStyle(color: context.appColors.textSecondary),
                    ),
                    items: items,
                    onChanged: _saving
                        ? null
                        : (v) {
                            setState(() => _supervisorStaffId = v ?? '');
                          },
                  );
                },
              ),
            ],
            SizedBox(height: 20),
            Text(
              'Cawangan kerja',
              style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
            ),
            SizedBox(height: 8),
            _loadingBranches
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(color: context.appColors.accentBlue),
                  )
                : Builder(
                    builder: (context) {
                      final orphan = _branchCode.isNotEmpty &&
                          !_branches.any((b) => (b['branchCode'] as String?) == _branchCode);
                      final items = <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— Default workplace —', style: TextStyle(color: context.appColors.textPrimary)),
                        ),
                        if (orphan)
                          DropdownMenuItem<String?>(
                            value: _branchCode,
                            child: Text(
                              '$_branchCode (current)',
                              style: TextStyle(color: context.appColors.textSecondary),
                            ),
                          ),
                        ..._branches.map((b) {
                          final code = b['branchCode'] as String? ?? '';
                          final nm = b['name'] as String? ?? code;
                          return DropdownMenuItem<String?>(
                            value: code,
                            child: Text('$nm ($code)', style: TextStyle(color: context.appColors.textPrimary)),
                          );
                        }),
                      ];
                      return DropdownButtonFormField<String?>(
                        value: _branchCode.isEmpty ? null : _branchCode,
                        dropdownColor: context.appColors.card,
                        style: TextStyle(color: context.appColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Branch / cawangan',
                          labelStyle: TextStyle(color: context.appColors.textSecondary),
                        ),
                        items: items,
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(() => _branchCode = v ?? '');
                              },
                      );
                    },
                  ),
            SizedBox(height: 20),
            Text(
              'Change password (optional)',
              style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: TextStyle(color: context.appColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'New password',
                labelStyle: TextStyle(color: context.appColors.textSecondary),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              style: TextStyle(color: context.appColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Confirm password',
                labelStyle: TextStyle(color: context.appColors.textSecondary),
              ),
            ),
            SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: context.appColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
