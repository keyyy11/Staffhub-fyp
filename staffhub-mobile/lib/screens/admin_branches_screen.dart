import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

/// Admin: manage branch/cawangan locations for staff attendance geofence.
class AdminBranchesScreen extends StatefulWidget {
  const AdminBranchesScreen({super.key});

  @override
  State<AdminBranchesScreen> createState() => _AdminBranchesScreenState();
}

class _AdminBranchesScreenState extends State<AdminBranchesScreen> {
  List<Map<String, dynamic>> _branches = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final result = await ApiService.getAdminBranches();
      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _branches = List<Map<String, dynamic>>.from(result['data'] as List);
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _errorMessage = result['message']?.toString() ?? 'Failed to load branches';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _openBranchForm({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Material(
          color: context.appColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Scaffold(
            backgroundColor: context.appColors.card,
            body: _BranchFormSheet(
              existing: existing,
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Branch created' : 'Branch updated')),
      );
      await _loadBranches();
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> branch) async {
    final code = branch['branchCode'] as String? ?? '';
    final name = branch['name'] as String? ?? code;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete branch?'),
        content: Text('Remove "$name" ($code)? Staff must be reassigned first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final result = await ApiService.deleteAdminBranch(code);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branch deleted')));
      await _loadBranches();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Delete failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cawangan / Branches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadBranches,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _openBranchForm(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Tambah cawangan'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.appColors.surface, context.appColors.background],
            stops: const [0.0, 0.25],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: _loadBranches, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : _branches.isEmpty
                    ? Center(
                        child: Text(
                          'No branches yet. Add one to assign staff.',
                          style: TextStyle(color: context.appColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        itemCount: _branches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final b = _branches[i];
                          final code = b['branchCode'] as String? ?? '';
                          final name = b['name'] as String? ?? code;
                          final active = b['isActive'] != false;
                          final lat = (b['lat'] as num?)?.toDouble();
                          final lng = (b['lng'] as num?)?.toDouble();
                          final radius = b['radiusMeters'];
                          final address = b['address'] as String? ?? '';

                          return Card(
                            color: context.appColors.card,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: active
                                    ? context.appColors.accentBlue.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                child: Icon(
                                  Icons.store_mall_directory_outlined,
                                  color: active ? context.appColors.accentBlue : Colors.grey,
                                ),
                              ),
                              title: Text(name, style: TextStyle(color: context.appColors.textPrimary)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$code · ${active ? 'Active' : 'Inactive'} · ${radius ?? 60}m radius',
                                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                                  ),
                                  if (address.isNotEmpty)
                                    Text(address, style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
                                  if (lat != null && lng != null)
                                    Text(
                                      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                                      style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    _openBranchForm(existing: b);
                                  } else if (v == 'delete') {
                                    _confirmDelete(b);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _BranchFormSheet extends StatefulWidget {
  const _BranchFormSheet({
    this.existing,
    required this.scrollController,
  });

  final Map<String, dynamic>? existing;
  final ScrollController scrollController;

  @override
  State<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<_BranchFormSheet> {
  static final RegExp _branchCodeRe = RegExp(r'^[A-Z0-9_-]{2,16}$');

  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '60');
  bool _isActive = true;
  bool _saving = false;
  bool _loadingDefaults = false;
  String? _formError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _codeController.text = e['branchCode'] as String? ?? '';
      _nameController.text = e['name'] as String? ?? '';
      _addressController.text = e['address'] as String? ?? '';
      _latController.text = (e['lat'] as num?)?.toString() ?? '';
      _lngController.text = (e['lng'] as num?)?.toString() ?? '';
      _radiusController.text = (e['radiusMeters'] as num?)?.toString() ?? '60';
      _isActive = e['isActive'] != false;
    } else {
      _loadDefaultCoords();
    }
  }

  Future<void> _loadDefaultCoords({bool force = false}) async {
    setState(() => _loadingDefaults = true);
    try {
      final result = await ApiService.getWorkplaceInfo();
      if (!mounted || result['success'] != true || result['data'] == null) return;
      final data = result['data'] as Map<String, dynamic>;
      setState(() {
        if (force || _latController.text.trim().isEmpty) {
          _latController.text = (data['lat'] as num).toString();
        }
        if (force || _lngController.text.trim().isEmpty) {
          _lngController.text = (data['lng'] as num).toString();
        }
        final r = data['radiusMeters'];
        if (r != null && (force || _radiusController.text.trim() == '60')) {
          _radiusController.text = (r as num).toString();
        }
      });
    } catch (_) {
      if (mounted) {
        _showError('Could not load default location. Check API connection.');
      }
    } finally {
      if (mounted) setState(() => _loadingDefaults = false);
    }
  }

  double? _parseCoord(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);

    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final lat = _parseCoord(_latController.text);
    final lng = _parseCoord(_lngController.text);
    final radius = int.tryParse(_radiusController.text.trim()) ?? 60;

    if (!_isEdit && code.isEmpty) {
      _showError('Branch code is required');
      return;
    }
    if (!_isEdit && !_branchCodeRe.hasMatch(code)) {
      _showError('Branch code: 2–16 characters (A-Z, 0-9, _ or -). Example: JB01, KL01');
      return;
    }
    if (name.isEmpty) {
      _showError('Branch name is required');
      return;
    }
    if (lat == null || lng == null) {
      _showError('Latitude and longitude are required. Tap "Use default location" or enter GPS coordinates.');
      return;
    }

    setState(() => _saving = true);
    try {
      final Map<String, dynamic> result;
      if (_isEdit) {
        result = await ApiService.updateAdminBranch(
          code,
          name: name,
          address: _addressController.text.trim(),
          lat: lat,
          lng: lng,
          radiusMeters: radius,
          isActive: _isActive,
        );
      } else {
        result = await ApiService.createAdminBranch(
          branchCode: code,
          name: name,
          address: _addressController.text.trim(),
          lat: lat,
          lng: lng,
          radiusMeters: radius,
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        _showError(result['message']?.toString() ?? 'Save failed');
      }
    } catch (e) {
      if (mounted) {
        _showError(
          e.toString().contains('TimeoutException')
              ? 'Request timed out. Check API connection and that staffhub-api is running.'
              : 'Error: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    setState(() => _formError = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: context.appColors.textSecondary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(
          _isEdit ? 'Edit cawangan' : 'Tambah cawangan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.appColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set GPS coordinates and radius for clock-in geofence. HQ is created automatically — use a different code (e.g. JB01).',
          style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
        ),
        if (_loadingDefaults)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(color: context.appColors.accentBlue),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          enabled: !_isEdit && !_saving,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: context.appColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Branch code (e.g. JB01, KL01)',
            helperText: 'Min 2 characters. HQ already exists by default.',
            labelStyle: TextStyle(color: context.appColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          enabled: !_saving,
          style: TextStyle(color: context.appColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Nama cawangan',
            labelStyle: TextStyle(color: context.appColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          enabled: !_saving,
          style: TextStyle(color: context.appColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Alamat (optional)',
            labelStyle: TextStyle(color: context.appColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _latController,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: TextStyle(color: context.appColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Latitude',
                  labelStyle: TextStyle(color: context.appColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _lngController,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: TextStyle(color: context.appColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Longitude',
                  labelStyle: TextStyle(color: context.appColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _saving || _loadingDefaults ? null : () => _loadDefaultCoords(force: true),
            icon: const Icon(Icons.my_location_outlined, size: 18),
            label: const Text('Use default location'),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _radiusController,
          enabled: !_saving,
          keyboardType: TextInputType.number,
          style: TextStyle(color: context.appColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Radius (meter)',
            labelStyle: TextStyle(color: context.appColors.textSecondary),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Active', style: TextStyle(color: context.appColors.textPrimary)),
          value: _isActive,
          onChanged: _saving ? null : (v) => setState(() => _isActive = v),
        ),
        if (_formError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_formError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: context.appColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _saving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEdit ? 'Save changes' : 'Create branch'),
        ),
      ],
    );
  }
}
