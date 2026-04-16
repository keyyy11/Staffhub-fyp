import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

const _kDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Infer shift from API row (legacy times or [shiftType]).
String inferShiftFromRow(Map<String, dynamic> r) {
  final st = r['shiftType']?.toString().toLowerCase();
  if (st == 'morning') return 'morning';
  if (st == 'afternoon') return 'afternoon';
  if (st == 'off') return 'off';
  final wd = r['isWorkingDay'] == true;
  if (!wd) return 'off';
  final ws = (r['workStart'] ?? '09:00').toString();
  final parts = ws.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts.first : '9') ?? 9;
  return h < 13 ? 'morning' : 'afternoon';
}

/// Lalai mingguan (fallback jika tiada rekod tarikh).
List<Map<String, dynamic>> defaultWeekSchedule() {
  return [
    for (final d in _kDayNames)
      <String, dynamic>{
        'day': d,
        'shiftType': (d == 'Saturday' || d == 'Sunday') ? 'off' : 'morning',
        'isWorkingDay': d != 'Saturday' && d != 'Sunday',
        'workStart': (d == 'Saturday' || d == 'Sunday') ? '09:00' : '08:00',
        'workEnd': (d == 'Saturday' || d == 'Sunday') ? '18:00' : '14:00',
      },
  ];
}

List<Map<String, dynamic>> _weekdaysMondayToThursday() {
  return [
    for (final d in _kDayNames)
      <String, dynamic>{
        'day': d,
        'shiftType': (d == 'Monday' ||
                d == 'Tuesday' ||
                d == 'Wednesday' ||
                d == 'Thursday')
            ? 'morning'
            : 'off',
        'isWorkingDay':
            d == 'Monday' || d == 'Tuesday' || d == 'Wednesday' || d == 'Thursday',
        'workStart': (d == 'Monday' ||
                d == 'Tuesday' ||
                d == 'Wednesday' ||
                d == 'Thursday')
            ? '08:00'
            : '09:00',
        'workEnd': (d == 'Monday' ||
                d == 'Tuesday' ||
                d == 'Wednesday' ||
                d == 'Thursday')
            ? '14:00'
            : '18:00',
      },
  ];
}

typedef StaffScheduleSaveFn = Future<bool> Function(List<Map<String, dynamic>> dateEntries, String notes);

/// Jadual ikut **tarikh**: Isnin minggu ini boleh lain dari Isnin minggu depan.
/// Lalai mingguan dipakai jika tiada rekod untuk tarikh tersebut.
class StaffScheduleEditorDialog extends StatefulWidget {
  const StaffScheduleEditorDialog({
    super.key,
    required this.staffName,
    required this.initialDays,
    this.initialDateEntries,
    required this.initialNotes,
    required this.onSave,
  });

  final String staffName;
  /// Jadual mingguan lalai (Isnin–Ahad) — dipakai bila tiada override tarikh.
  final List<Map<String, dynamic>> initialDays;
  /// Override ikut tarikh daripada API (`YYYY-MM-DD`).
  final List<Map<String, dynamic>>? initialDateEntries;
  final String initialNotes;
  final StaffScheduleSaveFn onSave;

  @override
  State<StaffScheduleEditorDialog> createState() => _StaffScheduleEditorDialogState();
}

class _StaffScheduleEditorDialogState extends State<StaffScheduleEditorDialog> {
  late Map<String, String> _weeklyByDay;
  late Map<String, String> _byDate;
  late TextEditingController _notesController;
  late DateTime _focusedMonth;

  String _shiftForDate(DateTime dt) {
    final s = isoDate(dt);
    if (_byDate.containsKey(s)) return _byDate[s]!;
    final name = _kDayNames[dt.weekday - 1];
    return _weeklyByDay[name] ?? 'morning';
  }

  int get _overrideCount => _byDate.length;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialDays.isNotEmpty ? widget.initialDays : defaultWeekSchedule();
    _weeklyByDay = {
      for (final r in seed) r['day'] as String: inferShiftFromRow(Map<String, dynamic>.from(r)),
    };
    _byDate = {};
    for (final e in widget.initialDateEntries ?? []) {
      final m = Map<String, dynamic>.from(e);
      final iso = m['date']?.toString();
      if (iso != null && iso.isNotEmpty) {
        _byDate[iso] = inferShiftFromRow(m);
      }
    }
    _notesController = TextEditingController(text: widget.initialNotes);
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _applyWeeklyFromList(List<Map<String, dynamic>> daysList) {
    setState(() {
      for (final r in daysList) {
        final day = r['day'] as String?;
        if (day != null) {
          _weeklyByDay[day] = inferShiftFromRow(Map<String, dynamic>.from(r));
        }
      }
    });
  }

  Future<void> _loadCompanyTemplate() async {
    try {
      final w = await ApiService.getWorkSchedule();
      final weekly = (w['data']?['weeklySchedule'] as List?) ?? [];
      if (weekly.isEmpty) return;
      final newDays = <Map<String, dynamic>>[];
      for (final raw in weekly) {
        final r = raw as Map<String, dynamic>;
        newDays.add({
          'day': r['day'],
          'isWorkingDay': r['isWorkingDay'] == true,
          'workStart': r['workStart'] ?? '09:00',
          'workEnd': r['workEnd'] ?? '18:00',
          'shiftType': r['shiftType'],
        });
      }
      _applyWeeklyFromList(newDays);
    } catch (_) {}
  }

  void _fillFocusedMonthFromWeekly() {
    final y = _focusedMonth.year;
    final m = _focusedMonth.month;
    final last = DateTime(y, m + 1, 0).day;
    setState(() {
      for (var d = 1; d <= last; d++) {
        final dt = DateTime(y, m, d);
        final name = _kDayNames[dt.weekday - 1];
        _byDate[isoDate(dt)] = _weeklyByDay[name] ?? 'morning';
      }
    });
  }

  String _weeklyShiftForIso(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return 'morning';
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return 'morning';
    final dt = DateTime(y, m, d);
    final name = _kDayNames[dt.weekday - 1];
    return _weeklyByDay[name] ?? 'morning';
  }

  Future<void> _pickShiftForDate(String iso) async {
    final weeklyFallback = _weeklyShiftForIso(iso);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  iso,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.wb_sunny_outlined, color: Colors.amber.shade300),
                title: const Text('Shift pagi', style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: Text('08:00 – 14:00', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9))),
                onTap: () => Navigator.pop(ctx, 'morning'),
              ),
              ListTile(
                leading: Icon(Icons.nights_stay_outlined, color: Colors.orange.shade300),
                title: const Text('Shift petang', style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: Text('14:00 – 22:00', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9))),
                onTap: () => Navigator.pop(ctx, 'afternoon'),
              ),
              ListTile(
                leading: const Icon(Icons.event_busy, color: AppTheme.textSecondary),
                title: const Text('Hari cuti (off)', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () => Navigator.pop(ctx, 'off'),
              ),
              const Divider(color: AppTheme.borderBlue),
              ListTile(
                leading: const Icon(Icons.undo, color: AppTheme.accentBlue),
                title: const Text('Buang tetapan tarikh ini', style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: Text(
                  'Kembali kepada lalai mingguan (${_shortLabelMs(weeklyFallback)})',
                  style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.85), fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, '__clear__'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      if (choice == '__clear__') {
        _byDate.remove(iso);
      } else {
        _byDate[iso] = choice;
      }
    });
  }

  Future<void> _save() async {
    final clean = _byDate.entries.map((e) => {'date': e.key, 'shiftType': e.value}).toList();
    try {
      final ok = await widget.onSave(clean, _notesController.text.trim());
      if (!mounted) return;
      Navigator.pop(context, ok);
    } catch (_) {
      if (mounted) Navigator.pop(context, false);
    }
  }

  Color _colorForShift(String shift) {
    switch (shift) {
      case 'morning':
        return AppTheme.accentBlue;
      case 'afternoon':
        return Colors.orangeAccent;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _shortLabelMs(String shift) {
    switch (shift) {
      case 'morning':
        return 'Pagi';
      case 'afternoon':
        return 'Petang';
      default:
        return 'Cuti';
    }
  }

  Widget _dayCell(DateTime date) {
    final iso = isoDate(date);
    final shift = _shiftForDate(date);
    final explicit = _byDate.containsKey(iso);
    final c = _colorForShift(shift);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickShiftForDate(iso),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: c.withValues(alpha: shift == 'off' ? 0.12 : 0.22),
            border: Border.all(
              color: explicit ? AppTheme.accentBlue.withValues(alpha: 0.75) : AppTheme.borderBlue.withValues(alpha: 0.35),
              width: explicit ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                _shortLabelMs(shift),
                style: TextStyle(fontSize: 10, color: c.withValues(alpha: 0.95), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGrid() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0).day;
    final startOffset = firstDay.weekday - 1;

    final cells = <Widget>[];
    for (var i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= lastDay; d++) {
      cells.add(_dayCell(DateTime(year, month, d)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() {
                _focusedMonth = DateTime(year, month - 1);
              }),
              icon: const Icon(Icons.chevron_left, color: AppTheme.accentBlue),
            ),
            Expanded(
              child: Text(
                '${_monthNames[month - 1]} $year',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                _focusedMonth = DateTime(year, month + 1);
              }),
              icon: const Icon(Icons.chevron_right, color: AppTheme.accentBlue),
            ),
          ],
        ),
        Row(
          children: [
            for (final w in ['Isn', 'Sel', 'Rab', 'Kha', 'Jum', 'Sab', 'Aha'])
              Expanded(
                child: Center(
                  child: Text(w, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.85))),
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
          childAspectRatio: 1.05,
          children: cells,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _legendRow(AppTheme.accentBlue, 'Pagi'),
            _legendRow(Colors.orangeAccent, 'Petang'),
            _legendRow(AppTheme.textSecondary, 'Cuti'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.9), width: 1.5),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Tetapan tarikh', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color.withValues(alpha: 0.6), shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardDark,
      title: Text('Jadual ikut tarikh · ${widget.staffName}', style: const TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        height: 560,
        child: ListView(
          children: [
            Text(
              'Ketik tarikh untuk tetapkan shift bagi hari itu sahaja. '
              'Tarikh lain tidak berubah — Isnin minggu ini dan Isnin minggu depan boleh berbeza. '
              'Birukan sempadan = ada tetapan khas; buang tetapan untuk guna lalai mingguan.',
              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.95), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_calendar, size: 20, color: AppTheme.accentBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tetapan ikut tarikh: $_overrideCount · Lalai mingguan dipakai jika tiada tetapan',
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadCompanyTemplate,
                  icon: const Icon(Icons.business, size: 18, color: AppTheme.accentBlue),
                  label: const Text('Lalai mingguan syarikat'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentBlue),
                ),
                OutlinedButton.icon(
                  onPressed: () => _applyWeeklyFromList(defaultWeekSchedule()),
                  icon: const Icon(Icons.weekend_rounded, size: 18, color: AppTheme.accentBlue),
                  label: const Text('Isnin–Jumaat pagi, Sabtu–Ahad cuti'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentBlue),
                ),
                OutlinedButton.icon(
                  onPressed: () => _applyWeeklyFromList(_weekdaysMondayToThursday()),
                  icon: const Icon(Icons.event_busy_outlined, size: 18, color: AppTheme.accentBlue),
                  label: const Text('Isnin–Khamis pagi, Jumaat–Ahad cuti'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentBlue),
                ),
                OutlinedButton.icon(
                  onPressed: _fillFocusedMonthFromWeekly,
                  icon: const Icon(Icons.date_range, size: 18, color: AppTheme.accentBlue),
                  label: const Text('Isi bulan ini daripada lalai mingguan'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentBlue),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMonthGrid(),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Notes for staff',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
          child: const Text('Save schedule'),
        ),
      ],
    );
  }
}
