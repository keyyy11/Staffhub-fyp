import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/l10n.dart';
import '../services/api_service.dart';

/// Admin: view discipline metrics and issue formal warning letters to staff.
class AdminDisciplineScreen extends StatefulWidget {
  const AdminDisciplineScreen({super.key});

  @override
  State<AdminDisciplineScreen> createState() => _AdminDisciplineScreenState();
}

class _AdminDisciplineScreenState extends State<AdminDisciplineScreen> with L10nMixin {
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
        return tr('warning_note_late');
      case 'attendance_leave_unsatisfactory':
        return tr('warning_note_attendance');
      default:
        return tr('warning_note_other');
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
          _errorMessage = tr('failed_load_staff_list');
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
        SnackBar(content: Text(tr('notes_min_5'))),
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
          SnackBar(content: Text(tr('warning_issued'))),
        );
        await _loadMetricsAndWarnings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String? ?? tr('failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('warning_issue_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _categoryLabel(String c) {
    switch (c) {
      case 'late_five_times':
        return tr('warning_late_5');
      case 'attendance_leave_unsatisfactory':
        return tr('warning_attendance_unsat');
      case 'other':
        return tr('warning_other');
      default:
        return c;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text(tr('discipline_title'), style: TextStyle(color: context.appColors.textPrimary)),
        backgroundColor: context.appColors.surface,
        foregroundColor: context.appColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loadingStaff
          ? Center(child: CircularProgressIndicator(color: context.appColors.accentBlue))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [context.appColors.surface, context.appColors.background],
                  stops: [0.0, 0.25],
                ),
              ),
              child: _staffList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMessage ?? tr('no_staff_registered'),
                          style: TextStyle(color: context.appColors.textSecondary),
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
                            dropdownColor: context.appColors.card,
                            decoration: InputDecoration(
                              labelText: tr('staff'),
                              labelStyle: TextStyle(color: context.appColors.textSecondary),
                              filled: true,
                              fillColor: context.appColors.card,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _staffList
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s['staffId'] as String?,
                                    child: Text(
                                      '${s['name'] ?? s['staffId']} (${s['staffId']})',
                                      style: TextStyle(color: context.appColors.textPrimary),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() => _selectedStaffId = v);
                              _loadMetricsAndWarnings();
                            },
                          ),
                          SizedBox(height: 16),
                          if (_loadingMetrics)
                            Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: context.appColors.accentBlue)))
                          else if (_metrics != null)
                            _buildMetricsCard(),
                          SizedBox(height: 20),
                          Text(
                            tr('issue_warning_letter'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: context.appColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            tr('issue_warning_desc'),
                            style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                          ),
                          SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _category,
                            dropdownColor: context.appColors.card,
                            decoration: InputDecoration(
                              labelText: tr('warning_type'),
                              labelStyle: TextStyle(color: context.appColors.textSecondary),
                              filled: true,
                              fillColor: context.appColors.card,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: [
                              DropdownMenuItem(value: 'late_five_times', child: Text(tr('warning_late_5'), style: TextStyle(color: context.appColors.textPrimary))),
                              DropdownMenuItem(
                                value: 'attendance_leave_unsatisfactory',
                                child: Text(tr('warning_attendance_unsat'), style: TextStyle(color: context.appColors.textPrimary)),
                              ),
                              DropdownMenuItem(value: 'other', child: Text(tr('warning_other'), style: TextStyle(color: context.appColors.textPrimary))),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _category = v;
                                _notesController.text = _defaultNotes(v);
                              });
                            },
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _notesController,
                            maxLines: 8,
                            style: TextStyle(color: context.appColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: tr('letter_content'),
                              labelStyle: TextStyle(color: context.appColors.textSecondary),
                              filled: true,
                              fillColor: context.appColors.card,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _submitWarning,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.appColors.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _submitting
                                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(tr('issue_warning_btn')),
                            ),
                          ),
                          SizedBox(height: 28),
                          Row(
                            children: [
                              Text(
                                tr('history_for_staff'),
                                style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (_loadingWarnings) ...[
                                SizedBox(width: 12),
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.accentBlue),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 12),
                          if (_warnings.isEmpty && !_loadingWarnings)
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(tr('no_warnings_issued'), style: TextStyle(color: context.appColors.textSecondary)),
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
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.borderBlue.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m['staffName'] as String? ?? '',
            style: TextStyle(color: context.appColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            tr('last_n_days', {'days': (m['periodDays'] ?? 90).toString()}),
            style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
          ),
          SizedBox(height: 4),
          Divider(color: context.appColors.borderBlue),
          SizedBox(height: 8),
          _metricRow(tr('late_clock_ins'), '$late', Colors.amber),
          _metricRow(tr('on_time_metric'), '$onTime', Colors.green),
          _metricRow(tr('total_attendance_days'), '$total', context.appColors.textSecondary),
          _metricRow(tr('on_time_ratio'), '${(ratio * 100).toStringAsFixed(0)}%', context.appColors.accentBlue),
          _metricRow(tr('leave_rejected_period'), '$rej', Colors.orangeAccent),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(tr('eligible_late_warning'), elLate, Colors.amber),
              _chip(tr('eligible_attendance_warning'), elUnsat, Colors.deepOrangeAccent),
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
          Text(label, style: TextStyle(color: context.appColors.textSecondary, fontSize: 14)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: on ? color.withOpacity(0.25) : context.appColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? color : context.appColors.borderBlue.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: on ? color : context.appColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
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
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _categoryLabel(cat),
                  style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
              Text(dateStr, style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            w['notes'] as String? ?? '',
            style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
          ),
          SizedBox(height: 6),
          Text(
            tr('issued_by', {
              'name': w['issuedByName'] ?? '',
              'email': w['issuedByEmail'] ?? '',
            }),
            style: TextStyle(color: context.appColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
