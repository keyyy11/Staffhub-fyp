import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/l10n.dart';
import '../services/api_service.dart';

/// Admin: view login / logout access logs.
class AdminAccessLogsScreen extends StatefulWidget {
  const AdminAccessLogsScreen({super.key});

  @override
  State<AdminAccessLogsScreen> createState() => _AdminAccessLogsScreenState();
}

class _AdminAccessLogsScreenState extends State<AdminAccessLogsScreen> with L10nMixin {
  static const _dayOptions = [7, 30, 90];

  int _days = 30;
  String? _actionFilter;
  String? _platformFilter;
  List<Map<String, dynamic>> _logs = [];
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
      final res = await ApiService.getAdminAccessLogs(
        days: _days,
        limit: 150,
        action: _actionFilter,
        platform: _platformFilter,
      );
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data['logs'] as List? ?? []);
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['message'] as String? ?? tr('access_logs_load_failed');
          _logs = [];
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

  String _actionLabel(String? action) {
    switch (action) {
      case 'login':
        return tr('access_action_login');
      case 'logout':
        return tr('access_action_logout');
      case 'login_failed':
        return tr('access_action_login_failed');
      default:
        return action ?? '-';
    }
  }

  String _platformLabel(String? platform) {
    switch (platform) {
      case 'cms':
        return tr('platform_cms');
      case 'mobile':
        return tr('platform_mobile');
      default:
        return tr('platform_unknown');
    }
  }

  Color _actionColor(String? action, bool success) {
    if (!success) return Colors.redAccent.shade100;
    if (action == 'logout') return Colors.amber.shade200;
    if (action == 'login') return Colors.greenAccent.shade200;
    return context.appColors.accentBlue;
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString();
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
        title: Text(tr('access_logs_title')),
      ),
      body: RefreshIndicator(
        color: cs.accentBlue,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr('access_logs_sub'), style: TextStyle(color: cs.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._dayOptions.map((d) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tr('performance_period_days', {'days': '$d'})),
                          selected: _days == d,
                          onSelected: (_) {
                            setState(() => _days = d);
                            _load();
                          },
                          selectedColor: cs.primaryBlue.withValues(alpha: 0.35),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(tr('access_action_login')),
                  selected: _actionFilter == 'login',
                  onSelected: (_) {
                    setState(() => _actionFilter = _actionFilter == 'login' ? null : 'login');
                    _load();
                  },
                ),
                FilterChip(
                  label: Text(tr('access_action_logout')),
                  selected: _actionFilter == 'logout',
                  onSelected: (_) {
                    setState(() => _actionFilter = _actionFilter == 'logout' ? null : 'logout');
                    _load();
                  },
                ),
                FilterChip(
                  label: Text(tr('platform_cms')),
                  selected: _platformFilter == 'cms',
                  onSelected: (_) {
                    setState(() => _platformFilter = _platformFilter == 'cms' ? null : 'cms');
                    _load();
                  },
                ),
                FilterChip(
                  label: Text(tr('platform_mobile')),
                  selected: _platformFilter == 'mobile',
                  onSelected: (_) {
                    setState(() => _platformFilter = _platformFilter == 'mobile' ? null : 'mobile');
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: Colors.redAccent.shade100)),
              )
            else if (_logs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('access_logs_empty'), style: TextStyle(color: cs.textSecondary), textAlign: TextAlign.center),
              )
            else
              ..._logs.map((log) {
                final action = log['action'] as String?;
                final success = log['success'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _actionColor(action, success).withValues(alpha: 0.45)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            action == 'logout' ? Icons.logout_rounded : Icons.login_rounded,
                            color: _actionColor(action, success),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              log['name'] as String? ?? log['staffId'] as String? ?? '-',
                              style: TextStyle(color: cs.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Text(
                            _actionLabel(action),
                            style: TextStyle(color: _actionColor(action, success), fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(log['email'] as String? ?? '', style: TextStyle(color: cs.textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatDateTime(log['createdAt']),
                              style: TextStyle(color: cs.textSecondary, fontSize: 12),
                            ),
                          ),
                          Text(
                            _platformLabel(log['platform'] as String?),
                            style: TextStyle(color: cs.accentBlue, fontSize: 12),
                          ),
                        ],
                      ),
                      if ((log['ipAddress'] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          tr('access_log_ip', {'ip': log['ipAddress'] as String}),
                          style: TextStyle(color: cs.textSecondary.withValues(alpha: 0.85), fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
