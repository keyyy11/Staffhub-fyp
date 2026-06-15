import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/l10n.dart';

/// Reusable performance analytics panel for admin/supervisor staff views.
class StaffPerformancePanel extends StatelessWidget {
  const StaffPerformancePanel({
    super.key,
    required this.data,
    this.loading = false,
    this.periodDays = 90,
  });

  final Map<String, dynamic>? data;
  final bool loading;
  final int periodDays;

  @override
  Widget build(BuildContext context) {
    final cs = context.appColors;

    if (loading) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.borderBlue.withValues(alpha: 0.45)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (data == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.borderBlue.withValues(alpha: 0.45)),
        ),
        child: Text(tr('performance_load_failed'), style: TextStyle(color: cs.textSecondary)),
      );
    }

    final attendance = data!['attendance'] as Map<String, dynamic>? ?? {};
    final leave = data!['leave'] as Map<String, dynamic>? ?? {};
    final overtime = data!['overtime'] as Map<String, dynamic>? ?? {};
    final warnings = data!['warnings'] as Map<String, dynamic>? ?? {};

    final total = attendance['total'] as int? ?? 0;
    final late = attendance['late'] as int? ?? 0;
    final onTime = attendance['onTime'] as int? ?? 0;
    final rate = attendance['rate'] as int? ?? 0;
    final otHours = (overtime['hoursApproved'] as num?) ?? 0;
    final warningCount = warnings['count'] as int? ?? 0;
    final score = data!['performanceScore'] as int? ?? 0;
    final grade = data!['performanceGrade'] as String? ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.borderBlue.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: cs.primaryBlue.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.primaryBlue.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(Icons.insights_outlined, color: cs.accentBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('performance_analytics'),
                    style: TextStyle(
                      color: cs.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  tr('performance_period_days', {'days': '$periodDays'}),
                  style: TextStyle(color: cs.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _scoreRing(context, score),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('performance_score'), style: TextStyle(color: cs.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _gradeColor(grade).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _gradeColor(grade).withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          _gradeLabel(grade),
                          style: TextStyle(color: _gradeColor(grade), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _divider(context),
          _row(context, tr('total_attendance'), '$total ${tr('days_unit')}'),
          _divider(context),
          _row(context, tr('on_time'), '$onTime', valueColor: Colors.greenAccent.shade200),
          _divider(context),
          _row(context, tr('late'), '$late', valueColor: Colors.amber.shade300),
          _divider(context),
          _row(context, tr('attendance_rate'), '$rate%', valueColor: rate >= 90 ? Colors.greenAccent : Colors.amber.shade300, bold: true),
          _divider(context),
          _row(
            context,
            tr('leave_taken'),
            '${leave['daysApproved'] ?? 0} ${tr('days_unit')} · ${leave['approved'] ?? 0} ${tr('approved')}',
            valueColor: Colors.greenAccent.shade200,
          ),
          _divider(context),
          _row(
            context,
            tr('overtime_hours'),
            '${otHours == otHours.roundToDouble() ? otHours.toInt() : otHours} ${tr('hours_unit')}',
            valueColor: Colors.deepPurple.shade200,
          ),
          _divider(context),
          _row(context, tr('warnings_issued'), '$warningCount', valueColor: warningCount > 0 ? Colors.redAccent.shade100 : cs.textPrimary),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: rate / 100,
                  minHeight: 8,
                  backgroundColor: Colors.amber.withValues(alpha: 0.25),
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreRing(BuildContext context, int score) {
    final color = score >= 90
        ? Colors.greenAccent
        : score >= 75
            ? Colors.lightBlueAccent
            : score >= 60
                ? Colors.amber
                : Colors.redAccent;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 6,
            backgroundColor: context.appColors.borderBlue.withValues(alpha: 0.3),
            color: color,
          ),
          Text('$score', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'Excellent':
        return Colors.greenAccent;
      case 'Good':
        return Colors.lightBlueAccent;
      case 'Fair':
        return Colors.amber;
      default:
        return Colors.redAccent;
    }
  }

  String _gradeLabel(String grade) {
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

  Widget _divider(BuildContext context) {
    return Divider(height: 1, color: context.appColors.borderBlue.withValues(alpha: 0.25));
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    final cs = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: cs.textSecondary, fontSize: 14)),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? cs.textPrimary,
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
