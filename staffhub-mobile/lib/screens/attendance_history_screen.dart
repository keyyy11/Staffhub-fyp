import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
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
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Attendance history', style: TextStyle(color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
            stops: [0.0, 0.35],
          ),
        ),
        child: _staffId.isEmpty
            ? const Center(child: Text('No Staff ID', style: TextStyle(color: AppTheme.textSecondary)))
            : FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue));
                  }
                  final body = snapshot.data;
                  if (body == null || body['success'] != true) {
                    return Center(
                      child: Text(
                        'Could not load records.',
                        style: TextStyle(color: Colors.red.shade200),
                      ),
                    );
                  }
                  final list = (body['data'] as List<dynamic>?) ?? [];
                  if (list.isEmpty) {
                    return const Center(child: Text('No attendance records yet.', style: TextStyle(color: AppTheme.textSecondary)));
                  }
                  return RefreshIndicator(
                    color: AppTheme.accentBlue,
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
                            color: AppTheme.cardDark,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.borderBlue.withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppTheme.accentBlue, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _fmtDate(row['date']),
                                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'In: ${_fmtTime(row['clockIn'])}  ·  Out: ${_fmtTime(row['clockOut'])}',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
