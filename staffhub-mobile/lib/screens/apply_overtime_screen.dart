import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

/// Staff: submit OT for a work date; supervisor approves from their dashboard.
class ApplyOvertimeScreen extends StatefulWidget {
  const ApplyOvertimeScreen({super.key});

  @override
  State<ApplyOvertimeScreen> createState() => _ApplyOvertimeScreenState();
}

class _ApplyOvertimeScreenState extends State<ApplyOvertimeScreen> {
  DateTime? _otDate;
  final _hoursController = TextEditingController(text: '2');
  final _reasonController = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _success = false;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    if (await AuthService.isDemoMode()) return;
    try {
      final r = await ApiService.getMyOvertimeRequests();
      if (r['success'] == true && r['data'] != null && mounted) {
        setState(() => _requests = List<Map<String, dynamic>>.from(r['data'] as List));
      }
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _otDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final ac = context.appColors;
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: dark
                ? ColorScheme.dark(
                    primary: ac.accentBlue,
                    surface: ac.card,
                    onSurface: ac.textPrimary,
                  )
                : ColorScheme.light(
                    primary: ac.primaryBlue,
                    surface: ac.surface,
                    onSurface: ac.textPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) setState(() => _otDate = picked);
  }

  Future<void> _submit() async {
    if (_otDate == null) {
      setState(() {
        _message = 'Select OT work date';
        _success = false;
      });
      return;
    }
    final h = double.tryParse(_hoursController.text.trim());
    if (h == null || h < 0.5 || h > 24) {
      setState(() {
        _message = 'Hours must be between 0.5 and 24';
        _success = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final result = await ApiService.applyOvertime(
        otDate: _otDate!,
        hours: h,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _loading = false;
          _success = true;
          _message = result['message'] as String? ?? 'Submitted';
        });
        await _loadList();
      } else {
        setState(() {
          _loading = false;
          _success = false;
          _message = result['message'] as String? ?? 'Failed';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _success = false;
          _message = 'Connection error';
        });
      }
    }
  }

  String _fmt(dynamic d) {
    if (d == null) return '-';
    final date = DateTime.parse(d.toString());
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _stColor(String? s) {
    switch (s) {
      case 'approved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text('Overtime (OT)', style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: context.appColors.surface,
        foregroundColor: context.appColors.textPrimary,
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
        child: RefreshIndicator(
          color: context.appColors.accentBlue,
          onRefresh: _loadList,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Apply for overtime on a specific work date. Your supervisor (manager) will approve or reject.',
                style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.95), fontSize: 13),
              ),
              SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.appColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _message!,
                          style: TextStyle(color: _success ? Colors.greenAccent : Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('OT work date', style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
                      subtitle: Text(
                        _otDate != null ? _fmt(_otDate!.toIso8601String()) : 'Tap to choose',
                        style: TextStyle(color: context.appColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      trailing: Icon(Icons.calendar_today, color: context.appColors.accentBlue),
                      onTap: _pickDate,
                    ),
                    TextField(
                      controller: _hoursController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: context.appColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Hours (0.5–24)',
                        labelStyle: TextStyle(color: context.appColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _reasonController,
                      maxLines: 2,
                      style: TextStyle(color: context.appColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Reason (optional)',
                        labelStyle: TextStyle(color: context.appColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: context.appColors.primaryBlue),
                        child: _loading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text('Submit OT request'),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 28),
              Text('My OT requests', style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 10),
              if (_requests.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No requests yet.',
                    style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.9)),
                  ),
                )
              else
                ..._requests.map((r) {
                  final st = r['status'] as String? ?? 'pending';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.appColors.borderBlue.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_fmt(r['otDate'])} · ${r['hours'] ?? '-'} h',
                                style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _stColor(st).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(st.toUpperCase(), style: TextStyle(color: _stColor(st), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        if ((r['reason'] as String?)?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${r['reason']}', style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
                          ),
                        if (st != 'pending' && (r['approverName'] as String?)?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'By: ${r['approverName']} · ${_fmt(r['decidedAt'])}',
                              style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
