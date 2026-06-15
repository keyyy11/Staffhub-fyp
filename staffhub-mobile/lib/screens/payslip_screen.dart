import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/l10n.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> with L10nMixin {
  String _staffId = '';
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  Future<Map<String, dynamic>>? _future;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await AuthService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _staffId = user?['staffId'] as String? ?? '';
      _future = _staffId.isEmpty ? null : _fetch();
      _booting = false;
    });
  }

  Future<Map<String, dynamic>> _fetch() {
    return ApiService.getPayslip(_staffId, year: _year, month: _month);
  }

  void _reload() {
    setState(() => _future = _fetch());
  }

  static const _monthKeys = [
    'month_jan',
    'month_feb',
    'month_mar',
    'month_apr',
    'month_may',
    'month_jun',
    'month_jul',
    'month_aug',
    'month_sep',
    'month_oct',
    'month_nov',
    'month_dec',
  ];

  String _monthLabel(int month) => tr(_monthKeys[month - 1]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text(tr('payslip'), style: TextStyle(color: context.appColors.textPrimary)),
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _month,
                      dropdownColor: context.appColors.card,
                      decoration: InputDecoration(
                        labelText: tr('month'),
                        labelStyle: TextStyle(color: context.appColors.textSecondary),
                        filled: true,
                        fillColor: context.appColors.card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: TextStyle(color: context.appColors.textPrimary),
                      items: List.generate(12, (i) {
                        final m = i + 1;
                        return DropdownMenuItem(value: m, child: Text(_monthLabel(m)));
                      }),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _month = v;
                          _reload();
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _year,
                      dropdownColor: context.appColors.card,
                      decoration: InputDecoration(
                        labelText: tr('year'),
                        labelStyle: TextStyle(color: context.appColors.textSecondary),
                        filled: true,
                        fillColor: context.appColors.card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: TextStyle(color: context.appColors.textPrimary),
                      items: List.generate(5, (i) {
                        final y = DateTime.now().year - 2 + i;
                        return DropdownMenuItem(value: y, child: Text('$y'));
                      }),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _year = v;
                          _reload();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _booting
                  ? Center(child: CircularProgressIndicator(color: context.appColors.accentBlue))
                  : _staffId.isEmpty
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
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                body?['message'] as String? ?? tr('failed_load_payslip'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red.shade200),
                              ),
                            ),
                          );
                        }
                        final data = body['data'] as Map<String, dynamic>? ?? {};
                        final attendance = data['attendance'] as Map<String, dynamic>? ?? {};
                        final earnings = data['earnings'] as Map<String, dynamic>? ?? {};
                        final deductions = (data['deductions'] as List<dynamic>?) ?? [];
                        final net = data['netPay'];
                        final disclaimer = data['disclaimer'] as String?;

                        return RefreshIndicator(
                          color: context.appColors.accentBlue,
                          onRefresh: () async {
                            setState(() => _future = _fetch());
                            await _future;
                          },
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              Text(
                                data['periodLabel'] as String? ?? '',
                                style: TextStyle(color: context.appColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${data['name']} · ${data['staffId']}',
                                style: TextStyle(color: context.appColors.textSecondary, fontSize: 15),
                              ),
                              if ((data['department'] as String?)?.isNotEmpty == true)
                                Text(tr('department_colon', {'name': data['department'] as String}), style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
                              if (data['fromAdmin'] == true) ...[
                                SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade900.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade600.withOpacity(0.6)),
                                  ),
                                  child: Text(tr('confirmed_by_admin'), style: TextStyle(color: Colors.lightGreenAccent, fontSize: 13)),
                                ),
                              ],
                              if ((data['adminRemarks'] as String?)?.isNotEmpty == true) ...[
                                SizedBox(height: 10),
                                Text(
                                  tr('hr_note', {'note': data['adminRemarks'] as String}),
                                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 14, height: 1.35),
                                ),
                              ],
                              SizedBox(height: 20),
                              _card(
                                tr('attendance_this_month'),
                                [
                                  tr('days_complete_clock', {'count': '${attendance['daysWithCompleteClock'] ?? 0}'}),
                                  tr('total_hours_worked', {'hours': '${attendance['totalHoursWorked'] ?? 0}'}),
                                ],
                              ),
                              SizedBox(height: 12),
                              _card(
                                tr('earnings'),
                                [
                                  '${earnings['label'] ?? tr('salary_label')}: ${tr('amount_rm', {'amount': _fmt(earnings['grossSalary'])})}',
                                ],
                              ),
                              SizedBox(height: 12),
                              _card(
                                tr('deductions'),
                                deductions.map((e) {
                                  final d = e as Map<String, dynamic>;
                                  return '${d['label']}: ${tr('amount_rm', {'amount': _fmt(d['amount'])})}';
                                }).toList(),
                              ),
                              SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: context.appColors.primaryBlue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.appColors.accentBlue.withOpacity(0.6)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      data['fromAdmin'] == true ? tr('net_pay') : tr('net_pay_est'),
                                      style: TextStyle(color: context.appColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      tr('amount_rm', {'amount': _fmt(net)}),
                                      style: TextStyle(color: context.appColors.accentBlue, fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              if (disclaimer != null) ...[
                                SizedBox(height: 16),
                                Text(disclaimer, style: TextStyle(color: Colors.amber.shade200, fontSize: 12, height: 1.4)),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '0.00';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return n.toStringAsFixed(2);
  }

  Widget _card(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.borderBlue.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: context.appColors.accentBlue, fontWeight: FontWeight.bold, fontSize: 15)),
          SizedBox(height: 10),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(l, style: TextStyle(color: context.appColors.textSecondary, height: 1.35)),
              )),
        ],
      ),
    );
  }
}
