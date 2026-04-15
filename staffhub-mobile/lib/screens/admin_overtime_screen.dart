import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

/// Admin: full visibility of OT flow (submitted → approved/rejected) for all staff.
class AdminOvertimeScreen extends StatefulWidget {
  const AdminOvertimeScreen({super.key});

  @override
  State<AdminOvertimeScreen> createState() => _AdminOvertimeScreenState();
}

class _AdminOvertimeScreenState extends State<AdminOvertimeScreen> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getAdminOvertimeRequests(status: _statusFilter);
      if (!mounted) return;
      if (r['success'] == true && r['data'] != null) {
        setState(() {
          _list = List<Map<String, dynamic>>.from(r['data'] as List);
          _loading = false;
        });
      } else {
        setState(() {
          _list = [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic d) {
    if (d == null) return '-';
    final date = DateTime.parse(d.toString());
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _fmtDt(dynamic d) {
    if (d == null) return '-';
    try {
      final date = DateTime.parse(d.toString());
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return d.toString();
    }
  }

  Color _stColor(String? s) {
    switch (s) {
      case 'approved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Overtime audit', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accentBlue),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'All OT applications and approval flow (read-only). Supervisors approve; you monitor the full trail.',
              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.95), fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (_) {
                    setState(() => _statusFilter = null);
                    _load();
                  },
                  selectedColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(color: _statusFilter == null ? Colors.white : AppTheme.textSecondary),
                ),
                ChoiceChip(
                  label: const Text('Pending'),
                  selected: _statusFilter == 'pending',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'pending');
                    _load();
                  },
                  selectedColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(color: _statusFilter == 'pending' ? Colors.white : AppTheme.textSecondary),
                ),
                ChoiceChip(
                  label: const Text('Approved'),
                  selected: _statusFilter == 'approved',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'approved');
                    _load();
                  },
                  selectedColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(color: _statusFilter == 'approved' ? Colors.white : AppTheme.textSecondary),
                ),
                ChoiceChip(
                  label: const Text('Rejected'),
                  selected: _statusFilter == 'rejected',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'rejected');
                    _load();
                  },
                  selectedColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(color: _statusFilter == 'rejected' ? Colors.white : AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
                : RefreshIndicator(
                    color: AppTheme.accentBlue,
                    onRefresh: _load,
                    child: _list.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 48),
                              Center(child: Text('No OT records', style: TextStyle(color: AppTheme.textSecondary))),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _list.length,
                            itemBuilder: (context, i) {
                              final r = _list[i];
                              final st = r['status'] as String? ?? 'pending';
                              final flow = r['flow'];
                              List<Map<String, dynamic>> steps = [];
                              if (flow is List) {
                                for (final e in flow) {
                                  if (e is Map) steps.add(Map<String, dynamic>.from(e));
                                }
                              }
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardDark,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.borderBlue.withValues(alpha: 0.4)),
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r['staffName'] ?? r['staffId'] ?? '-',
                                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _stColor(st).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(st.toUpperCase(), style: TextStyle(color: _stColor(st), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'OT date ${_fmt(r['otDate'])} · ${r['hours'] ?? '-'} h · ID ${r['staffId']}',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                  ),
                                  children: [
                                    if ((r['reason'] as String?)?.isNotEmpty == true)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Reason: ${r['reason']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                      ),
                                    if ((r['supervisorStaffIdAtSubmit'] as String?)?.isNotEmpty == true)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Supervisor at submit: ${r['supervisorStaffIdAtSubmit']}',
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    const Divider(color: AppTheme.borderBlue),
                                    const Text('Activity flow', style: TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    if (steps.isEmpty)
                                      Text('Submitted ${_fmtDt(r['createdAt'])}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))
                                    else
                                      ...steps.map((s) {
                                        final action = s['action'] as String? ?? '';
                                        final role = s['actorRole'] as String? ?? '';
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                action == 'submitted' ? Icons.send : (action == 'approved' ? Icons.check_circle : Icons.cancel),
                                                size: 18,
                                                color: AppTheme.accentBlue,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '$action · $role · ${s['actorStaffId'] ?? '-'}',
                                                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                                    ),
                                                    Text(_fmtDt(s['at']), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                                    if ((s['note'] as String?)?.isNotEmpty == true)
                                                      Text(s['note'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                                  ],
                                                ),
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
          ),
        ],
      ),
    );
  }
}
