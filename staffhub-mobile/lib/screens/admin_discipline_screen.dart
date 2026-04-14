import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

/// Admin: view discipline metrics and issue formal warning letters to staff.
class AdminDisciplineScreen extends StatefulWidget {
  const AdminDisciplineScreen({super.key});

  @override
  State<AdminDisciplineScreen> createState() => _AdminDisciplineScreenState();
}

class _AdminDisciplineScreenState extends State<AdminDisciplineScreen> {
  List<Map<String, dynamic>> _staffList = [];
  String? _selectedStaffId;
  Map<String, dynamic>? _metrics;
  List<Map<String, dynamic>> _warnings = [];
  bool _loadingStaff = true;
  bool _loadingMetrics = false;
  bool _loadingWarnings = false;
  bool _submitting = false;
  String? _errorMessage;

  String _category = 'late_five_times';
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesController.text = _defaultNotes('late_five_times');
    _loadStaff();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _defaultNotes(String cat) {
    switch (cat) {
      case 'late_five_times':
        return 'This is a formal warning under company policy. Our records show repeated late clock-in within the assessment period. '
            'You are required to improve punctuality and meet attendance expectations.';
      case 'attendance_leave_unsatisfactory':
        return 'This is a formal warning. Your attendance and/or leave records have not met satisfactory standards. '
            'You are expected to comply with departmental and HR policies going forward.';
      default:
        return 'State the reason and expected improvement clearly.';
    }
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loadingStaff = true;
      _errorMessage = null;
    });
    try {
      final result = await ApiService.getStaffList();
      if (result['success'] == true && result['data'] != null && mounted) {
        final raw = List<Map<String, dynamic>>.from(result['data'] as List);
        final list = raw.where((s) => (s['role'] as String?) != 'supervisor').toList();
        setState(() {
          _staffList = list;
          if (list.isNotEmpty) {
            _selectedStaffId = list.first['staffId'] as String?;
          }
          _loadingStaff = false;
        });
        if (_selectedStaffId != null) {
          await _loadMetricsAndWarnings();
        }
      } else {
        if (mounted) setState(() => _loadingStaff = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingStaff = false;
          _errorMessage = 'Failed to load staff list';
        });
      }
    }
  }

  Future<void> _loadMetricsAndWarnings() async {
    final id = _selectedStaffId;
    if (id == null) return;
    setState(() {
      _loadingMetrics = true;
      _loadingWarnings = true;
    });
    try {
      final results = await Future.wait([
        ApiService.getStaffDisciplineMetrics(id),
        ApiService.listAdminWarnings(staffId: id),
      ]);
      final m = results[0];
      final w = results[1];
      if (!mounted) return;
      if (m['success'] == true && m['data'] != null) {
        setState(() => _metrics = m['data'] as Map<String, dynamic>);
      } else {
        setState(() => _metrics = null);
      }
      if (w['success'] == true && w['data'] != null) {
        setState(() => _warnings = List<Map<String, dynamic>>.from(w['data'] as List));
      } else {
        setState(() => _warnings = []);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _metrics = null;
          _warnings = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingMetrics = false;
          _loadingWarnings = false;
        });
      }
    }
  }

  Future<void> _submitWarning() async {
    final id = _selectedStaffId;
    if (id == null) return;
    final notes = _notesController.text.trim();
    if (notes.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes must be at least 5 characters')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ApiService.createAdminWarning(
        staffId: id,
        category: _category,
        notes: notes,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warning letter issued')),
        );
        await _loadMetricsAndWarnings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? 'Failed')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not issue warning. Check API.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _categoryLabel(String c) {
    switch (c) {
      case 'late_five_times':
        return 'Late arrivals (5+ times)';
      case 'attendance_leave_unsatisfactory':
        return 'Attendance / leave unsatisfactory';
      case 'other':
        return 'Other';
      default:
        return c;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Discipline & warnings', style: TextStyle(color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loadingStaff
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
                  stops: [0.0, 0.25],
                ),
              ),
              child: _staffList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMessage ?? 'No staff registered yet.',
                          style: const TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedStaffId,
                            dropdownColor: AppTheme.cardDark,
                            decoration: InputDecoration(
                              labelText: 'Staff',
                              labelStyle: const TextStyle(color: AppTheme.textSecondary),
                              filled: true,
                              fillColor: AppTheme.cardDark,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _staffList
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s['staffId'] as String?,
                                    child: Text(
                                      '${s['name'] ?? s['staffId']} (${s['staffId']})',
                                      style: const TextStyle(color: AppTheme.textPrimary),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() => _selectedStaffId = v);
                              _loadMetricsAndWarnings();
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_loadingMetrics)
                            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppTheme.accentBlue)))
                          else if (_metrics != null)
                            _buildMetricsCard(),
                          const SizedBox(height: 20),
                          Text(
                            'Issue warning letter',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Use when the system flags repeated lateness or unsatisfactory attendance/leave. You may edit the letter text before sending.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _category,
                            dropdownColor: AppTheme.cardDark,
                            decoration: InputDecoration(
                              labelText: 'Warning type',
                              labelStyle: const TextStyle(color: AppTheme.textSecondary),
                              filled: true,
                              fillColor: AppTheme.cardDark,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'late_five_times', child: Text('Late arrivals (5+ times)', style: TextStyle(color: AppTheme.textPrimary))),
                              DropdownMenuItem(
                                value: 'attendance_leave_unsatisfactory',
                                child: Text('Attendance / leave unsatisfactory', style: TextStyle(color: AppTheme.textPrimary)),
                              ),
                              DropdownMenuItem(value: 'other', child: Text('Other', style: TextStyle(color: AppTheme.textPrimary))),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _category = v;
                                _notesController.text = _defaultNotes(v);
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesController,
                            maxLines: 8,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Letter content',
                              labelStyle: const TextStyle(color: AppTheme.textSecondary),
                              filled: true,
                              fillColor: AppTheme.cardDark,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _submitWarning,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _submitting
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Issue warning letter'),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              const Text(
                                'History for this staff',
                                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (_loadingWarnings) ...[
                                const SizedBox(width: 12),
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentBlue),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_warnings.isEmpty && !_loadingWarnings)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No warnings issued yet.', style: TextStyle(color: AppTheme.textSecondary)),
                            )
                          else
                            ..._warnings.map(_warningTile),
                        ],
                      ),
                    ),
            ),
    );
  }

  Widget _buildMetricsCard() {
    final m = _metrics!;
    final late = m['lateCount'] ?? 0;
    final onTime = m['onTimeCount'] ?? 0;
    final total = m['totalAttendanceDays'] ?? 0;
    final ratio = (m['onTimeRatio'] as num?)?.toDouble() ?? 0;
    final rej = m['leaveRejected'] ?? 0;
    final elLate = m['eligibleLateWarning'] == true;
    final elUnsat = m['eligibleUnsatisfactoryWarning'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderBlue.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m['staffName'] as String? ?? '',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Last ${m['periodDays'] ?? 90} days',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Divider(color: AppTheme.borderBlue),
          const SizedBox(height: 8),
          _metricRow('Late clock-ins', '$late', Colors.amber),
          _metricRow('On time', '$onTime', Colors.green),
          _metricRow('Total attendance days', '$total', AppTheme.textSecondary),
          _metricRow('On-time ratio', '${(ratio * 100).toStringAsFixed(0)}%', AppTheme.accentBlue),
          _metricRow('Leave rejected (period)', '$rej', Colors.orangeAccent),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Eligible: late warning', elLate, Colors.amber),
              _chip('Eligible: attendance/leave', elUnsat, Colors.deepOrangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: on ? color.withOpacity(0.25) : AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? color : AppTheme.borderBlue.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: on ? color : AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _warningTile(Map<String, dynamic> w) {
    final cat = w['category'] as String? ?? '';
    final date = w['createdAt'] != null ? DateTime.tryParse(w['createdAt'].toString()) : null;
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '-';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _categoryLabel(cat),
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
              Text(dateStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            w['notes'] as String? ?? '',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'By: ${w['issuedByName'] ?? ''} (${w['issuedByEmail'] ?? ''})',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
