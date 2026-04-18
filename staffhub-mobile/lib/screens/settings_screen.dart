import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/settings_strings.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  bool _savingPw = false;
  String? _pwMessage;
  bool _pwOk = false;

  @override
  void dispose() {
    _currentPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  Widget _themeChip(ThemeMode mode, String label, SettingsController s) {
    final sel = s.themeMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) => s.setThemeMode(mode),
      selectedColor: context.appColors.accentBlue.withValues(alpha: 0.35),
    );
  }

  Future<void> _submitPassword(String lang) async {
    if (await AuthService.isDemoMode()) {
      setState(() {
        _pwMessage = SettingsStrings.t(lang, 'demo_password');
        _pwOk = false;
      });
      return;
    }
    final c = _currentPw.text;
    final n = _newPw.text;
    final cf = _confirmPw.text;
    if (c.isEmpty || n.isEmpty || cf.isEmpty) {
      setState(() {
        _pwMessage = SettingsStrings.t(lang, 'fill_all');
        _pwOk = false;
      });
      return;
    }
    if (n != cf) {
      setState(() {
        _pwMessage = SettingsStrings.t(lang, 'password_mismatch');
        _pwOk = false;
      });
      return;
    }
    setState(() {
      _savingPw = true;
      _pwMessage = null;
    });
    try {
      final r = await ApiService.changePassword(currentPassword: c, newPassword: n);
      if (!mounted) return;
      setState(() {
        _savingPw = false;
        if (r['success'] == true) {
          _pwOk = true;
          _pwMessage = SettingsStrings.t(lang, 'password_updated');
          _currentPw.clear();
          _newPw.clear();
          _confirmPw.clear();
        } else {
          _pwOk = false;
          _pwMessage = r['message'] as String? ?? 'Error';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _savingPw = false;
          _pwOk = false;
          _pwMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: SettingsController.instance,
      builder: (context, _) {
        final s = SettingsController.instance;
        final lang = s.langCode;
        String tr(String k) => SettingsStrings.t(lang, k);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(tr('settings_title')),
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(tr('language'), style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
              SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'ms', label: Text(tr('lang_ms'))),
                  ButtonSegment(value: 'en', label: Text(tr('lang_en'))),
                ],
                selected: {lang},
                onSelectionChanged: (Set<String> v) {
                  if (v.isEmpty) return;
                  s.setLocale(Locale(v.first));
                  setState(() {});
                },
              ),
              SizedBox(height: 24),
              Text(tr('appearance'), style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
              SizedBox(height: 8),
              Text(tr('theme'), style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75), fontSize: 13)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _themeChip(ThemeMode.dark, tr('theme_dark'), s),
                  _themeChip(ThemeMode.light, tr('theme_light'), s),
                  _themeChip(ThemeMode.system, tr('theme_system'), s),
                ],
              ),
              SizedBox(height: 28),
              Text(tr('security'), style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
              SizedBox(height: 12),
              Text(tr('change_password'), style: TextStyle(color: cs.onSurface.withValues(alpha: 0.9), fontSize: 15)),
              SizedBox(height: 10),
              TextField(
                controller: _currentPw,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('current_password')),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _newPw,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('new_password')),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _confirmPw,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('confirm_password')),
              ),
              if (_pwMessage != null) ...[
                SizedBox(height: 10),
                Text(_pwMessage!, style: TextStyle(color: _pwOk ? Colors.green : Colors.redAccent, fontSize: 13)),
              ],
              SizedBox(height: 12),
              FilledButton(
                onPressed: _savingPw ? null : () => _submitPassword(lang),
                child: _savingPw
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr('save_password')),
              ),
              SizedBox(height: 32),
              Text(tr('notifications'), style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
              SizedBox(height: 8),
              Text(tr('notifications_hint'), style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75), fontSize: 13, height: 1.4)),
              SizedBox(height: 28),
              Text(tr('about'), style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
              SizedBox(height: 8),
              Text(tr('version'), style: TextStyle(color: cs.onSurface.withValues(alpha: 0.85))),
              SizedBox(height: 4),
              Text('1.0.0+1', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}
