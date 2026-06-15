import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/l10n.dart';
import '../screens/staff_performance_screen.dart';

/// Admin home: on-time / late percentages + staff performance overview.
class AdminWorkforceAnalytics extends StatelessWidget {
  const AdminWorkforceAnalytics({
    super.key,
    required this.attendanceStats,
    required this.performanceStaff,
    this.loadingPerformance = false,
    this.periodDays = 30,
  });

  final Map<String, dynamic>? attendanceStats;
  final List<Map<String, dynamic>> performanceStaff;
  final bool loadingPerformance;
  final int periodDays;

  @override
  Widget build(BuildContext context) {
    final cs = context.appColors;
    final total = attendanceStats?['total'] as int? ?? 0;
    final onTime = attendanceStats?['onTime'] as int? ?? 0;
    final late = attendanceStats?['late'] as int? ?? 0;
    final onTimePct = total > 0 ? ((onTime / total) * 100).round() : 0;
    final latePct = total > 0 ? ((late / total) * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > 0) ...[
          Row(
            children: [
              Expanded(
                child: _PctCard(
                  label: tr('on_time_percentage'),
                  percent: onTimePct,
                  sub: tr('on_time_count_sub', {'count': '$onTime', 'total': '$total'}),
                  color: Colors.greenAccent,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PctCard(
                  label: tr('late_percentage'),
                  percent: latePct,
                  sub: tr('late_count_sub', {'count': '$late', 'total': '$total'}),
                  color: Colors.amber.shade300,
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                if (onTimePct > 0)
                  Expanded(
                    flex: onTimePct,
                    child: Container(height: 10, color: Colors.greenAccent),
                  ),
                if (latePct > 0)
                  Expanded(
                    flex: latePct,
                    child: Container(height: 10, color: Colors.amber.shade400),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('on_time_pct_label', {'percent': '$onTimePct'}),
                style: TextStyle(color: Colors.greenAccent.shade200, fontSize: 11),
              ),
              Text(
                tr('late_pct_label', {'percent': '$latePct'}),
                style: TextStyle(color: Colors.amber.shade200, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            Icon(Icons.insights_outlined, color: cs.accentBlue, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('staff_performance_overview'),
                style: TextStyle(
                  color: cs.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tr('performance_analytics_sub', {'days': '$periodDays'}),
          style: TextStyle(color: cs.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (loadingPerformance)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (performanceStaff.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(tr('no_performance_data'), style: TextStyle(color: cs.textSecondary)),
          )
        else
          ...performanceStaff.take(8).map((s) => _StaffPerfTile(staff: s)),
      ],
    );
  }
}

class _PctCard extends StatelessWidget {
  const _PctCard({
    required this.label,
    required this.percent,
    required this.sub,
    required this.color,
    required this.icon,
  });

  final String label;
  final int percent;
  final String sub;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text('$percent%', style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: cs.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: cs.textSecondary.withValues(alpha: 0.8), fontSize: 10)),
        ],
      ),
    );
  }
}

class _StaffPerfTile extends StatelessWidget {
  const _StaffPerfTile({required this.staff});

  final Map<String, dynamic> staff;

  Color _scoreColor(int score) {
    if (score >= 90) return Colors.greenAccent;
    if (score >= 75) return Colors.lightBlueAccent;
    if (score >= 60) return Colors.amber;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.appColors;
    final sid = staff['staffId'] as String? ?? '';
    final name = staff['staffName'] as String? ?? sid;
    final score = staff['performanceScore'] as int? ?? 0;
    final grade = staff['performanceGrade'] as String? ?? '';
    final att = staff['attendance'] as Map<String, dynamic>? ?? {};
    final total = att['total'] as int? ?? 0;
    final onTime = att['onTime'] as int? ?? 0;
    final late = att['late'] as int? ?? 0;
    final onTimePct = total > 0 ? ((onTime / total) * 100).round() : 0;
    final latePct = total > 0 ? ((late / total) * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.borderBlue.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(name, style: TextStyle(color: cs.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          tr('perf_attendance_pct', {'onTime': '$onTimePct', 'late': '$latePct'}),
          style: TextStyle(color: cs.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$score', style: TextStyle(color: _scoreColor(score), fontWeight: FontWeight.bold, fontSize: 18)),
                Text(_gradeShort(grade), style: TextStyle(color: cs.textSecondary, fontSize: 10)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: cs.textSecondary, size: 20),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StaffPerformanceScreen(staffId: sid, staffName: name),
            ),
          );
        },
      ),
    );
  }

  String _gradeShort(String grade) {
    switch (grade) {
      case 'Excellent':
        return tr('grade_excellent');
      case 'Good':
        return tr('grade_good');
      case 'Fair':
        return tr('grade_fair');
      default:
        return tr('grade_needs_improvement');
    }
  }
}
