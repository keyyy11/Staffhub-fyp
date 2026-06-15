import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/l10n.dart';
import '../services/api_service.dart';
import '../widgets/staff_performance_panel.dart';

/// Full-screen staff performance analytics for admin or supervisor.
class StaffPerformanceScreen extends StatefulWidget {
  const StaffPerformanceScreen({
    super.key,
    required this.staffId,
    required this.staffName,
    this.asSupervisor = false,
  });

  final String staffId;
  final String staffName;
  final bool asSupervisor;

  @override
  State<StaffPerformanceScreen> createState() => _StaffPerformanceScreenState();
}

class _StaffPerformanceScreenState extends State<StaffPerformanceScreen> with L10nMixin {
  static const _periodOptions = [30, 60, 90, 180];

  int _days = 90;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = widget.asSupervisor
          ? await ApiService.getSupervisorStaffPerformance(widget.staffId, days: _days)
          : await ApiService.getAdminStaffPerformance(widget.staffId, days: _days);
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _data = Map<String, dynamic>.from(res['data'] as Map);
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['message'] as String? ?? tr('performance_load_failed');
          _data = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.appColors;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.textPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('performance_analytics'), style: const TextStyle(fontSize: 17)),
            Text(widget.staffName, style: TextStyle(fontSize: 12, color: cs.textSecondary)),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: cs.accentBlue,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _periodOptions.map((d) {
                  final selected = _days == d;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tr('performance_period_days', {'days': '$d'})),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _days = d);
                        _load();
                      },
                      selectedColor: cs.primaryBlue.withValues(alpha: 0.35),
                      labelStyle: TextStyle(
                        color: selected ? cs.textPrimary : cs.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null && !_loading)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: Colors.redAccent.shade100, fontSize: 13)),
              ),
            StaffPerformancePanel(data: _data, loading: _loading, periodDays: _days),
          ],
        ),
      ),
    );
  }
}
