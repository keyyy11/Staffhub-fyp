import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/l10n.dart';

/// Personal attendance summary for staff home screen.
class StaffAttendanceDashboard extends StatelessWidget {
  const StaffAttendanceDashboard({
    super.key,
    required this.totalAttendance,
    required this.lateAttendance,
    required this.leaveTaken,
    required this.overtimeHours,
    required this.attendanceRate,
    this.periodLabel,
    this.loading = false,
  });

  final int totalAttendance;
  final int lateAttendance;
  final num leaveTaken;
  final num overtimeHours;
  final int attendanceRate;
  final String? periodLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = context.appColors;
    final leaveLabel = leaveTaken == 1 ? tr('day_unit') : tr('days_unit');
    final lateLabel = lateAttendance == 1 ? tr('time_unit') : tr('times_unit');

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
                Icon(Icons.dashboard_customize_outlined, color: cs.accentBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('attendance_dashboard'),
                    style: TextStyle(
                      color: cs.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (periodLabel != null && periodLabel!.isNotEmpty)
                  Text(
                    periodLabel!,
                    style: TextStyle(color: cs.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _row(context, tr('total_attendance'), '$totalAttendance ${tr('days_unit')}'),
            _divider(context),
            _row(context, tr('late_attendance'), '$lateAttendance $lateLabel', valueColor: Colors.amber.shade300),
            _divider(context),
            _row(context, tr('leave_taken'), '$leaveTaken $leaveLabel', valueColor: Colors.greenAccent.shade200),
            _divider(context),
            _row(
              context,
              tr('overtime_hours'),
              '${overtimeHours == overtimeHours.roundToDouble() ? overtimeHours.toInt() : overtimeHours} ${tr('hours_unit')}',
              valueColor: Colors.deepPurple.shade200,
            ),
            _divider(context),
            _row(
              context,
              tr('attendance_rate'),
              '$attendanceRate%',
              valueColor: attendanceRate >= 90 ? Colors.greenAccent : Colors.amber.shade300,
              bold: true,
            ),
            if (totalAttendance > 0) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: attendanceRate / 100,
                    minHeight: 8,
                    backgroundColor: Colors.amber.withValues(alpha: 0.25),
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Text(
                  tr('dashboard_no_attendance_month'),
                  style: TextStyle(color: cs.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: context.appColors.borderBlue.withValues(alpha: 0.25));

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
            child: Text(
              label,
              style: TextStyle(color: cs.textSecondary, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? cs.textPrimary,
              fontSize: bold ? 16 : 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
