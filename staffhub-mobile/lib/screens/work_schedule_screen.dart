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
      return ApiService.getWorkSchedule(year: _year, month: _month);
    }
    final token = await AuthService.getToken();
    if (token != null) {
      try {
        final r = await ApiService.getMyWorkSchedule(year: _year, month: _month);
        if (r['success'] == true) return r;
      } catch (_) {}
    }
    return ApiService.getWorkSchedule(year: _year, month: _month);
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
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text('Work schedule', style: TextStyle(color: context.appColors.textPrimary)),
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
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: context.appColors.accentBlue));
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
            final phPayNote = data['publicHolidayPayNote'] as String?;

            return RefreshIndicator(
              color: context.appColors.accentBlue,
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
                      color: context.appColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.appColors.borderBlue.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expected clock-in', style: TextStyle(color: context.appColors.textSecondary, fontSize: 14)),
                        SizedBox(height: 6),
                        Text(expected, style: TextStyle(color: context.appColors.accentBlue, fontSize: 28, fontWeight: FontWeight.bold)),
                        if (scheduleMode == 'byDate') ...[
                          SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Jadual ikut tarikh (setiap hari boleh berbeza)',
                              style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 12),
                            ),
                          ),
                        ] else if (source == 'custom' || source == 'supervisor') ...[
                          SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Custom schedule (admin or supervisor)',
                              style: TextStyle(color: Colors.tealAccent, fontSize: 12),
                            ),
                          ),
                        ],
                        if (data['notes'] != null) ...[
                          SizedBox(height: 12),
                          Text(
                            data['notes'] as String,
                            style: TextStyle(color: context.appColors.textSecondary, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasCalendar) ...[
                    SizedBox(height: 20),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _shiftMonth(-1),
                          icon: Icon(Icons.chevron_left, color: context.appColors.accentBlue),
                        ),
                        Expanded(
                          child: Text(
                            '${_monthNames[_month - 1]} $_year',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.appColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _shiftMonth(1),
                          icon: Icon(Icons.chevron_right, color: context.appColors.accentBlue),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Kalendar',
                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withOpacity(0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cuti umum — warna emas pada tarikh',
                                  style: TextStyle(color: Colors.amber.shade200, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  phPayNote ??
                                      'Jika anda bekerja pada hari cuti umum, kadar sejam biasanya 2× (ikut syarikat).',
                                  style: TextStyle(color: context.appColors.textSecondary.withOpacity(0.95), fontSize: 11, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    _CalendarMonthGrid(
                      year: _year,
                      month: _month,
                      days: calendarMonth,
                    ),
                  ],
                  SizedBox(height: 20),
                  Text(
                    hasCalendar ? 'Ringkasan mingguan (lalai / fallback)' : 'Weekly',
                    style: TextStyle(color: context.appColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
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
                        color: context.appColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: working ? context.appColors.borderBlue.withOpacity(0.4) : context.appColors.borderBlue.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(day, style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 3,
                            child: working
                                ? Text(
                                    line2.isNotEmpty ? '$line1\n$line2' : line1,
                                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 13, height: 1.3),
                                  )
                                : Text(line1, style: TextStyle(color: context.appColors.textSecondary)),
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
      cells.add(SizedBox());
    }
    for (var i = 0; i < days.length; i++) {
      final row = days[i] as Map<String, dynamic>;
      final dayNum = i + 1;
      final label = row['shiftLabel'] as String? ?? '';
      final src = row['source'] as String? ?? '';
      final working = row['isWorkingDay'] == true;
      final isPh = row['isPublicHoliday'] == true;
      final mult = (row['publicHolidayHourlyMultiplier'] as num?)?.toDouble();
      final color = !working
          ? context.appColors.textSecondary
          : (row['shiftType'] == 'afternoon' ? Colors.orangeAccent : context.appColors.accentBlue);
      final phBorder = Colors.amber.shade600.withOpacity(0.85);
      final phFill = Colors.amber.shade800.withOpacity(0.22);
      final phName = row['publicHolidayName'] as String?;
      final cell = Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isPh ? phFill : context.appColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPh
                ? phBorder
                : (src == 'date' ? context.appColors.accentBlue.withOpacity(0.5) : context.appColors.borderBlue.withOpacity(0.2)),
            width: isPh ? 1.4 : (src == 'date' ? 1.2 : 1),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNum',
                  style: TextStyle(
                    color: isPh ? Colors.amber.shade100 : context.appColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: color.withOpacity(0.95), height: 1.1),
                ),
              ],
            ),
            if (isPh && working)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    mult != null && mult != 2 ? '${mult}x' : '2x',
                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      );
      cells.add(
        isPh && (phName != null && phName.isNotEmpty)
            ? Tooltip(
                message: phName,
                triggerMode: TooltipTriggerMode.longPress,
                child: cell,
              )
            : cell,
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
                  child: Text(w, style: TextStyle(fontSize: 10, color: context.appColors.textSecondary.withOpacity(0.85))),
                ),
              ),
          ],
        ),
        SizedBox(height: 6),
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
