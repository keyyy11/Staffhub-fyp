import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Payslip', style: TextStyle(color: AppTheme.textPrimary)),
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _month,
                      dropdownColor: AppTheme.cardDark,
                      decoration: InputDecoration(
                        labelText: 'Month',
                        labelStyle: const TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.cardDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      items: List.generate(12, (i) {
                        final m = i + 1;
                        return DropdownMenuItem(value: m, child: Text('$m'));
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _year,
                      dropdownColor: AppTheme.cardDark,
                      decoration: InputDecoration(
                        labelText: 'Year',
                        labelStyle: const TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.cardDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
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
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
                  : _staffId.isEmpty
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
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                body?['message'] as String? ?? 'Failed to load payslip.',
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
                          color: AppTheme.accentBlue,
                          onRefresh: () async {
                            setState(() => _future = _fetch());
                            await _future;
                          },
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              Text(
                                data['periodLabel'] as String? ?? '',
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${data['name']} · ${data['staffId']}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                              ),
                              if ((data['department'] as String?)?.isNotEmpty == true)
                                Text('Department: ${data['department']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              if (data['fromAdmin'] == true) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade900.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade600.withOpacity(0.6)),
                                  ),
                                  child: const Text('Confirmed by admin / HR', style: TextStyle(color: Colors.lightGreenAccent, fontSize: 13)),
                                ),
                              ],
                              if ((data['adminRemarks'] as String?)?.isNotEmpty == true) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'HR note: ${data['adminRemarks']}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.35),
                                ),
                              ],
                              const SizedBox(height: 20),
                              _card(
                                'Attendance this month',
                                [
                                  'Days with clock-in & out: ${attendance['daysWithCompleteClock'] ?? 0}',
                                  'Total hours worked: ${attendance['totalHoursWorked'] ?? 0}',
                                ],
                              ),
                              const SizedBox(height: 12),
                              _card(
                                'Earnings',
                                [
                                  '${earnings['label'] ?? 'Salary'}: RM ${_fmt(earnings['grossSalary'])}',
                                ],
                              ),
                              const SizedBox(height: 12),
                              _card(
                                'Deductions',
                                deductions.map((e) {
                                  final d = e as Map<String, dynamic>;
                                  return '${d['label']}: RM ${_fmt(d['amount'])}';
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.accentBlue.withOpacity(0.6)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      data['fromAdmin'] == true ? 'Net pay' : 'Net pay (est.)',
                                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'RM ${_fmt(net)}',
                                      style: const TextStyle(color: AppTheme.accentBlue, fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              if (disclaimer != null) ...[
                                const SizedBox(height: 16),
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderBlue.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(l, style: const TextStyle(color: AppTheme.textSecondary, height: 1.35)),
              )),
        ],
      ),
    );
  }
}
