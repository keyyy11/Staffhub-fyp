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
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

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
        final r = await ApiService.getMyWorkSchedule(year: _year, month: _month);
        if (r['success'] == true) return r;
      } catch (_) {}
    }
    return ApiService.getWorkSchedule();
  }

  void _shiftMonth(int delta) {
    var m = _month + delta;
    var y = _year;
    if (m > 12) {
      m = 1;
      y++;
    }
    if (m < 1) {
      m = 12;
      y--;
    }
    setState(() {
      _month = m;
      _year = y;
      _future = _fetch();
    });
  }

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

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
            final scheduleMode = data['scheduleMode'] as String?;
            final calendarMonth = (data['calendarMonth'] as List<dynamic>?) ?? [];
            final hasCalendar = calendarMonth.isNotEmpty;

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
                        if (scheduleMode == 'byDate') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Jadual ikut tarikh (setiap hari boleh berbeza)',
                              style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 12),
                            ),
                          ),
                        ] else if (source == 'custom' || source == 'supervisor') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Custom schedule (admin or supervisor)',
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
                  if (hasCalendar) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _shiftMonth(-1),
                          icon: const Icon(Icons.chevron_left, color: AppTheme.accentBlue),
                        ),
                        Expanded(
                          child: Text(
                            '${_monthNames[_month - 1]} $_year',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _shiftMonth(1),
                          icon: const Icon(Icons.chevron_right, color: AppTheme.accentBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kalendar',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _CalendarMonthGrid(
                      year: _year,
                      month: _month,
                      days: calendarMonth,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    hasCalendar ? 'Ringkasan mingguan (lalai / fallback)' : 'Weekly',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...weekly.map((raw) {
                    final row = raw as Map<String, dynamic>;
                    final day = row['day'] as String? ?? '';
                    final label = row['shiftLabel'] as String?;
                    final working = row['isWorkingDay'] == true;
                    final line1 = label ?? (working ? 'Shift' : 'Hari cuti');
                    final line2 = working
                        ? '${row['workStart']} – ${row['workEnd']}'
                            '${row['breakMinutes'] != null ? '\nBreak ~${row['breakMinutes']} min' : ''}'
                        : '';
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
                                    line2.isNotEmpty ? '$line1\n$line2' : line1,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.3),
                                  )
                                : Text(line1, style: const TextStyle(color: AppTheme.textSecondary)),
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

class _CalendarMonthGrid extends StatelessWidget {
  const _CalendarMonthGrid({
    required this.year,
    required this.month,
    required this.days,
  });

  final int year;
  final int month;
  final List<dynamic> days;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final startOffset = first.weekday - 1;
    final cells = <Widget>[];
    for (var i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }
    for (var i = 0; i < days.length; i++) {
      final row = days[i] as Map<String, dynamic>;
      final dayNum = i + 1;
      final label = row['shiftLabel'] as String? ?? '';
      final src = row['source'] as String? ?? '';
      final working = row['isWorkingDay'] == true;
      final color = !working
          ? AppTheme.textSecondary
          : (row['shiftType'] == 'afternoon' ? Colors.orangeAccent : AppTheme.accentBlue);
      cells.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: src == 'date' ? AppTheme.accentBlue.withOpacity(0.5) : AppTheme.borderBlue.withOpacity(0.2),
              width: src == 'date' ? 1.2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNum',
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: color.withOpacity(0.95), height: 1.1),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final w in ['Isn', 'Sel', 'Rab', 'Kha', 'Jum', 'Sab', 'Aha'])
              Expanded(
                child: Center(
                  child: Text(w, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.85))),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.9,
          children: cells,
        ),
      ],
    );
  }
}
