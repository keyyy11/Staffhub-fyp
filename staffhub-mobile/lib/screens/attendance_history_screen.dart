import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/l10n.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> with L10nMixin {
  String _staffId = '';
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AuthService.getCurrentUser();
    if (!mounted) return;
    final id = user?['staffId'] as String? ?? '';
    setState(() {
      _staffId = id;
      if (id.isNotEmpty) _future = ApiService.getMyAttendance(id);
    });
  }

  String _fmtDate(dynamic d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return d.toString();
    }
  }

  String _fmtTime(dynamic t) {
    if (t == null) return '—';
    try {
      final dt = DateTime.parse(t.toString());
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text(tr('attendance_history'), style: TextStyle(color: context.appColors.textPrimary)),
        backgroundColor: context.appColors.surface,
        foregroundColor: context.appColors.textPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.appColors.surface, context.appColors.background],
            stops: [0.0, 0.35],
          ),
        ),
        child: _staffId.isEmpty
            ? Center(child: Text(tr('no_staff_id'), style: TextStyle(color: context.appColors.textSecondary)))
            : FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: context.appColors.accentBlue));
                  }
                  final body = snapshot.data;
                  if (body == null || body['success'] != true) {
                    return Center(
                      child: Text(
                        tr('could_not_load_records'),
                        style: TextStyle(color: Colors.red.shade200),
                      ),
                    );
                  }
                  final list = (body['data'] as List<dynamic>?) ?? [];
                  if (list.isEmpty) {
                    return Center(child: Text(tr('no_attendance_records'), style: TextStyle(color: context.appColors.textSecondary)));
                  }
                  return RefreshIndicator(
                    color: context.appColors.accentBlue,
                    onRefresh: () async {
                      setState(() => _future = ApiService.getMyAttendance(_staffId));
                      await _future;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final row = list[i] as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.appColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.appColors.borderBlue.withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: context.appColors.accentBlue, size: 22),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _fmtDate(row['date']),
                                      style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      tr('clock_in_out_line', {
                                        'inTime': _fmtTime(row['clockIn']),
                                        'outTime': _fmtTime(row['clockOut']),
                                      }),
                                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
