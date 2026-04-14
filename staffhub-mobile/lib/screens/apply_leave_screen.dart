import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  String _staffId = '';
  String _selectedLeaveType = 'annual';
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;
  List<Map<String, dynamic>> _myRequests = [];

  static const _leaveTypes = [
    {'id': 'medical', 'label': 'Medical Leave'},
    {'id': 'annual', 'label': 'Annual Leave'},
    {'id': 'unpaid', 'label': 'Unpaid Leave'},
    {'id': 'other', 'label': 'Other Leave'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (user != null && mounted) {
      setState(() => _staffId = user['staffId'] as String? ?? '');
      _loadMyRequests();
    }
  }

  Future<void> _loadMyRequests() async {
    if (_staffId.isEmpty) return;
    try {
      final result = await ApiService.getMyLeaveRequests(_staffId);
      if (result['success'] == true && result['data'] != null && mounted) {
        setState(() => _myRequests = List<Map<String, dynamic>>.from(result['data'] as List));
      }
    } catch (_) {}
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accentBlue,
            surface: AppTheme.cardDark,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final initial = _endDate ?? _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accentBlue,
            surface: AppTheme.cardDark,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _endDate = picked);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Select';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  int _calculateDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!current.isAfter(endDate)) {
      if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) count++;
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _submit() async {
    if (_staffId.isEmpty) {
      _showMessage('Please log in again', false);
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showMessage('Please select start and end date', false);
      return;
    }
    if (_startDate!.isAfter(_endDate!)) {
      _showMessage('End date must be after start date', false);
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final result = await ApiService.applyLeave(
        _staffId,
        _selectedLeaveType,
        _startDate!,
        _endDate!,
        _reasonController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        _showMessage('Leave application submitted successfully', true);
        _loadMyRequests();
        _reasonController.clear();
        setState(() {
          _startDate = null;
          _endDate = null;
        });
      } else {
        _showMessage(result['message'] as String? ?? 'Failed to submit', false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Connection error. Please ensure API is running.', false);
      }
    }
  }

  void _showMessage(String msg, bool success) {
    setState(() {
      _message = msg;
      _isSuccess = success;
    });
  }

  String _getLeaveTypeLabel(String type) {
    return _leaveTypes.firstWhere((t) => t['id'] == type, orElse: () => {'label': type})['label'] as String;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.amber;
    }
  }

  String _formatDateTime(dynamic d) {
    if (d == null) return '-';
    final dt = DateTime.tryParse(d.toString());
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} · '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _statusResponseText(String? status) {
    switch (status) {
      case 'approved':
        return 'Approved — your leave request has been accepted.';
      case 'rejected':
        return 'Rejected — your leave request was not approved.';
      default:
        return 'Pending — waiting for admin review.';
    }
  }

  Widget _buildLeaveRequestCard(Map<String, dynamic> r) {
    final start = r['startDate'] != null ? DateTime.tryParse(r['startDate'].toString()) : null;
    final end = r['endDate'] != null ? DateTime.tryParse(r['endDate'].toString()) : null;
    final status = r['status'] as String? ?? 'pending';
    final reason = (r['reason'] as String?)?.trim() ?? '';
    final adminComment = (r['adminComment'] as String?)?.trim() ?? '';
    final stColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stColor.withOpacity(0.45), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                status == 'approved'
                    ? Icons.check_circle_outline
                    : status == 'rejected'
                        ? Icons.cancel_outlined
                        : Icons.hourglass_empty_rounded,
                color: stColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getLeaveTypeLabel(r['leaveType'] as String? ?? ''),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusResponseText(status),
                      style: TextStyle(color: stColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: stColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: stColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (start != null && end != null)
            Text(
              '${_formatDate(start)} → ${_formatDate(end)} · ${r['totalDays'] ?? '-'} working day(s)',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          const SizedBox(height: 6),
          Text(
            'Submitted: ${_formatDateTime(r['createdAt'])}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (status != 'pending') ...[
            const SizedBox(height: 4),
            Text(
              'Response time: ${_formatDateTime(r['updatedAt'])}',
              style: const TextStyle(color: AppTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Your reason', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(height: 2),
            Text(reason, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          ],
          if (adminComment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderBlue.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin response', style: TextStyle(color: AppTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(adminComment, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Apply Leave', style: TextStyle(color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.accentBlue,
            onRefresh: _loadMyRequests,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your leave requests & responses',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'See admin decision (approved / rejected) and any note below.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (_myRequests.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderBlue.withOpacity(0.3)),
                      ),
                      child: const Center(
                        child: Text('No leave requests yet. Submit a new application below.', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    )
                  else
                    ..._myRequests.map((r) => _buildLeaveRequestCard(r)),
                  const SizedBox(height: 28),
                  const Text(
                    'New leave application',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 14),
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
                      const Text('Leave Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedLeaveType,
                        dropdownColor: AppTheme.cardDark,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
                        ),
                        items: _leaveTypes.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['label'] as String))).toList(),
                        onChanged: (v) => setState(() => _selectedLeaveType = v ?? 'annual'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Start Date', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectStartDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppTheme.accentBlue, size: 20),
                              const SizedBox(width: 12),
                              Text(_formatDate(_startDate), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('End Date', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectEndDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppTheme.accentBlue, size: 20),
                              const SizedBox(width: 12),
                              Text(_formatDate(_endDate), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      if (_startDate != null && _endDate != null && !_endDate!.isBefore(_startDate!)) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${_calculateDays(_startDate!, _endDate!)} working days',
                          style: const TextStyle(color: AppTheme.accentBlue, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _reasonController,
                        maxLines: 3,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Reason (optional)',
                          labelStyle: const TextStyle(color: AppTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_message != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: _isSuccess ? Colors.green.shade900.withOpacity(0.3) : Colors.red.shade900.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _isSuccess ? Colors.green.shade700 : Colors.red.shade700),
                          ),
                          child: Row(
                            children: [
                              Icon(_isSuccess ? Icons.check_circle : Icons.error, color: _isSuccess ? Colors.greenAccent : Colors.redAccent, size: 24),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_message!, style: TextStyle(color: _isSuccess ? Colors.greenAccent : Colors.redAccent))),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Submit Application'),
                        ),
                      ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
