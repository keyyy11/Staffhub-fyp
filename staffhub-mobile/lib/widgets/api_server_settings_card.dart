import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_theme.dart';
import '../l10n/l10n.dart';
import '../services/api_config_service.dart';

/// Configure API server URL (IP or cloud URL) without rebuilding the APK.
class ApiServerSettingsCard extends StatefulWidget {
  const ApiServerSettingsCard({super.key, this.compact = false});

  final bool compact;

  @override
  State<ApiServerSettingsCard> createState() => _ApiServerSettingsCardState();
}

class _ApiServerSettingsCardState extends State<ApiServerSettingsCard> with L10nMixin {
  final _controller = TextEditingController();
  bool _testing = false;
  bool _saving = false;
  String? _message;
  bool _ok = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadDisplay();
    ApiConfigService.instance.addListener(_onApiConfigChanged);
  }

  void _onApiConfigChanged() => _loadDisplay();

  void _loadDisplay() {
    final svc = ApiConfigService.instance;
    final current = svc.hasCustomUrl ? svc.displayValue : '';
    if (_controller.text != current) {
      _controller.text = current;
    }
  }

  @override
  void dispose() {
    ApiConfigService.instance.removeListener(_onApiConfigChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _message = null;
    });
    try {
      final url = ApiConfigService.normalizeServerInput(_controller.text.trim());
      if (url.isEmpty) {
        setState(() {
          _testing = false;
          _ok = false;
          _message = tr('api_server_empty');
        });
        return;
      }
      final res = await http.get(Uri.parse('$url/health')).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _testing = false;
          _ok = true;
          _message = tr('api_server_ok');
        });
      } else {
        setState(() {
          _testing = false;
          _ok = false;
          _message = tr('api_server_fail', {'code': '${res.statusCode}'});
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _ok = false;
        _message = tr('api_server_unreachable');
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ApiConfigService.instance.saveFromInput(_controller.text.trim());
      if (!mounted) return;
      setState(() {
        _saving = false;
        _ok = true;
        _message = tr('api_server_saved', {'url': ApiConfigService.instance.baseUrl});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _ok = false;
        _message = tr('api_server_invalid');
      });
    }
  }

  Future<void> _reset() async {
    await ApiConfigService.instance.clearCustom();
    _controller.clear();
    if (!mounted) return;
    setState(() {
      _ok = true;
      _message = tr('api_server_reset');
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.appColors;
    final activeUrl = ApiConfigService.instance.baseUrl;

    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.dns_outlined, color: cs.accentBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tr('api_server_title'), style: TextStyle(color: cs.textSecondary, fontSize: 12)),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: cs.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          if (_expanded) _form(context, cs, activeUrl),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.borderBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('api_server_title'), style: TextStyle(color: cs.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(tr('api_server_hint'), style: TextStyle(color: cs.textSecondary, fontSize: 12, height: 1.35)),
          const SizedBox(height: 12),
          _form(context, cs, activeUrl),
        ],
      ),
    );
  }

  Widget _form(BuildContext context, dynamic cs, String activeUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          style: TextStyle(color: cs.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: tr('api_server_input_label'),
            hintText: tr('api_server_input_hint'),
            labelStyle: TextStyle(color: cs.textSecondary),
            hintStyle: TextStyle(color: cs.textSecondary.withValues(alpha: 0.6)),
            filled: true,
            fillColor: cs.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('api_server_active', {'url': activeUrl}),
          style: TextStyle(color: cs.textSecondary, fontSize: 11),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, style: TextStyle(color: _ok ? Colors.greenAccent : Colors.redAccent.shade100, fontSize: 12)),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _testing ? null : _testConnection,
              child: _testing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr('api_server_test')),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr('api_server_save')),
            ),
            if (ApiConfigService.instance.hasCustomUrl)
              TextButton(onPressed: _reset, child: Text(tr('api_server_reset_btn'))),
          ],
        ),
      ],
    );
  }
}
