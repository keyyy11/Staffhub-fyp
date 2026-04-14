import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class WorkScheduleScreen extends StatefulWidget {
  const WorkScheduleScreen({super.key});

  @override
  State<WorkScheduleScreen> createState() => _WorkScheduleScreenState();
}

class _WorkScheduleScreenState extends State<WorkScheduleScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<Map<String, dynamic>> _fetch() async {
    if (await AuthService.isDemoMode()) {
      return ApiService.getWorkSchedule();
    }
    final token = await AuthService.getToken();
    if (token != null) {
      try {
        final r = await ApiService.getMyWorkSchedule();
        if (r['success'] == true) return r;
      } catch (_) {}
    }
    return ApiService.getWorkSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Work schedule', style: TextStyle(color: AppTheme.textPrimary)),
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
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue));
            }
            if (snapshot.hasError || snapshot.data?['success'] != true) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load schedule. Make sure the API is running.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade200),
                  ),
                ),
              );
            }
            final data = snapshot.data!['data'] as Map<String, dynamic>? ?? {};
            final expected = data['expectedClockIn'] as String? ?? '—';
            final weekly = (data['weeklySchedule'] as List<dynamic>?) ?? [];
            final source = data['source'] as String?;

            return RefreshIndicator(
              color: AppTheme.accentBlue,
              onRefresh: () async {
                setState(() => _future = _fetch());
                await _future;
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Expected clock-in', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        const SizedBox(height: 6),
                        Text(expected, style: const TextStyle(color: AppTheme.accentBlue, fontSize: 28, fontWeight: FontWeight.bold)),
                        if (source == 'supervisor') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Includes schedule from your supervisor',
                              style: TextStyle(color: Colors.tealAccent, fontSize: 12),
                            ),
                          ),
                        ],
                        if (data['notes'] != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            data['notes'] as String,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Weekly',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...weekly.map((raw) {
                    final row = raw as Map<String, dynamic>;
                    final day = row['day'] as String? ?? '';
                    final working = row['isWorkingDay'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: working ? AppTheme.borderBlue.withOpacity(0.4) : AppTheme.borderBlue.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(day, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 3,
                            child: working
                                ? Text(
                                    '${row['workStart']} – ${row['workEnd']}\nBreak ~${row['breakMinutes']} min',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.3),
                                  )
                                : const Text('Off', style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
