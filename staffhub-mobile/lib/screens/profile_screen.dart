import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../l10n/l10n.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with L10nMixin {
  String _staffId = '';
  String _name = '';
  String _email = '';
  String _phone = '';
  String _department = '';
  String _position = '';
  String _profileImageBase64 = '';
  bool _isSaving = false;
  String? _message;
  bool _isSuccess = false;
  bool _isEditing = false;
  List<Map<String, dynamic>> _warnings = [];
  bool _warningsLoading = false;
  bool _showStaffWarnings = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (user == null) return;

    setState(() {
      _staffId = user['staffId'] as String? ?? '';
      _name = user['name'] as String? ?? '';
      _email = user['email'] as String? ?? '';
      _nameController.text = _name;
      _phoneController.text = _phone;
      _departmentController.text = _department;
      _positionController.text = _position;
    });

    await _loadProfile();
    final role = user['role'] as String?;
    if (role != 'admin' && !await AuthService.isDemoMode()) {
      setState(() => _showStaffWarnings = true);
      await _loadWarnings();
    }
  }

  Future<void> _loadWarnings() async {
    setState(() => _warningsLoading = true);
    try {
      final result = await ApiService.getMyWarnings();
      if (result['success'] == true && result['data'] != null && mounted) {
        setState(() {
          _warnings = List<Map<String, dynamic>>.from(result['data'] as List);
          _warningsLoading = false;
        });
      } else {
        if (mounted) setState(() => _warningsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _warningsLoading = false);
    }
  }

  String _warningCategoryLabel(String? c) {
    switch (c) {
      case 'late_five_times':
        return tr('warning_late');
      case 'attendance_leave_unsatisfactory':
        return tr('warning_attendance');
      case 'other':
        return tr('warning_other');
      default:
        return c ?? tr('warning');
    }
  }

  Future<void> _loadProfile() async {
    if (_staffId.isEmpty) return;

    if (await AuthService.isDemoMode()) {
      final local = await AuthService.getProfileLocally();
      if (local != null && mounted) {
        setState(() {
          _phone = local['phone'] as String? ?? '';
          _department = local['department'] as String? ?? '';
          _position = local['position'] as String? ?? '';
          _profileImageBase64 = local['profileImage'] as String? ?? '';
          _phoneController.text = _phone;
          _departmentController.text = _department;
          _positionController.text = _position;
        });
      }
      return;
    }

    try {
      final result = await ApiService.getProfile(_staffId);
      if (result['success'] == true && result['data'] != null && mounted) {
        final data = result['data'] as Map<String, dynamic>;
        final nameFromApi = data['name'] as String?;
        final emailFromApi = data['email'] as String?;
        setState(() {
          if (nameFromApi != null && nameFromApi.isNotEmpty) _name = nameFromApi;
          if (emailFromApi != null && emailFromApi.isNotEmpty) _email = emailFromApi;
          _phone = data['phone'] as String? ?? _phone;
          _department = data['department'] as String? ?? _department;
          _position = data['position'] as String? ?? _position;
          final img = data['profileImage'] as String?;
          if (img != null && img.isNotEmpty) _profileImageBase64 = img;
          _nameController.text = _name;
          _phoneController.text = _phone;
          _departmentController.text = _department;
          _positionController.text = _position;
        });
      }
    } catch (_) {
      final local = await AuthService.getProfileLocally();
      if (local != null && mounted) {
        setState(() {
          _phone = local['phone'] as String? ?? '';
          _department = local['department'] as String? ?? '';
          _position = local['position'] as String? ?? '';
          _profileImageBase64 = local['profileImage'] as String? ?? '';
          _phoneController.text = _phone;
          _departmentController.text = _department;
          _positionController.text = _position;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        FocusManager.instance.primaryFocus?.unfocus();
        FocusScope.of(context).unfocus();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final binding = SchedulerBinding.instance;
        await Future<void>.delayed(Duration.zero);
        await binding.endOfFrame;
        if (!mounted) return;
      }
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 70,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64 = base64Encode(bytes);
        setState(() => _profileImageBase64 = 'data:image/jpeg;base64,$base64');
      }
    } catch (e) {
      if (mounted) _showMessage(tr('failed_pick_image'), false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _message = null;
    });

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final department = _departmentController.text.trim();
    final position = _positionController.text.trim();

    if (await AuthService.isDemoMode()) {
      await AuthService.saveProfileLocally({
        'phone': phone,
        'department': department,
        'position': position,
        'profileImage': _profileImageBase64,
      });
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _phone = phone;
        _department = department;
        _position = position;
        _isEditing = false;
      });
      _showMessage(tr('saved_locally_demo'), true);
      return;
    }

    try {
      final result = await ApiService.updateProfile(
        _staffId,
        name: name.isEmpty ? null : name,
        phone: phone.isEmpty ? null : phone,
        department: department.isEmpty ? null : department,
        position: position.isEmpty ? null : position,
        profileImage: _profileImageBase64.isEmpty ? null : _profileImageBase64,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        await AuthService.updateStoredUser({
          'staffId': data['staffId'],
          'name': data['name'],
          'email': data['email'],
        });
        await AuthService.saveProfileLocally({
          'phone': data['phone'],
          'department': data['department'],
          'position': data['position'],
          'profileImage': data['profileImage'],
        });
        setState(() {
          _name = data['name'] as String? ?? _name;
          _phone = data['phone'] as String? ?? '';
          _department = data['department'] as String? ?? '';
          _position = data['position'] as String? ?? '';
          _profileImageBase64 = data['profileImage'] as String? ?? '';
          _isEditing = false;
        });
        _showMessage(tr('profile_updated'), true);
      } else {
        _showMessage(result['message'] as String? ?? tr('update_failed'), false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        await AuthService.saveProfileLocally({
          'phone': _phoneController.text.trim(),
          'department': _departmentController.text.trim(),
          'position': _positionController.text.trim(),
          'profileImage': _profileImageBase64,
        });
        setState(() {
          _phone = _phoneController.text.trim();
          _department = _departmentController.text.trim();
          _position = _positionController.text.trim();
          _isEditing = false;
        });
        _showMessage(tr('saved_locally_demo'), true);
      }
    }
  }

  void _showMessage(String msg, bool success) {
    setState(() {
      _message = msg;
      _isSuccess = success;
    });
  }

  ImageProvider? _buildProfileImage() {
    try {
      final base64 = _profileImageBase64.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
      return MemoryImage(base64Decode(base64));
    } catch (_) {
      return null;
    }
  }

  String _getInitials() {
    if (_name.isNotEmpty) {
      final parts = _name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return _name.substring(0, _name.length >= 2 ? 2 : 1).toUpperCase();
    }
    return _staffId.isNotEmpty ? _staffId.substring(0, 2).toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text(tr('profile'), style: TextStyle(color: context.appColors.textPrimary)),
        backgroundColor: context.appColors.surface,
        foregroundColor: context.appColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: context.appColors.accentBlue),
            tooltip: tr('settings'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : () => setState(() => _isEditing = false),
              child: Text(tr('cancel'), style: TextStyle(color: context.appColors.textSecondary)),
            ),
          TextButton(
            onPressed: _isSaving
                ? null
                : () {
                    if (_isEditing) {
                      _saveProfile();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
            child: _isSaving
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.accentBlue))
                : Text(_isEditing ? tr('save') : tr('edit'), style: TextStyle(color: context.appColors.accentBlue, fontWeight: FontWeight.w600)),
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen())),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.appColors.surface, context.appColors.background],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              children: [
                SizedBox(height: 20),
                GestureDetector(
                  onTap: _isEditing ? _pickImage : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 80,
                        backgroundColor: context.appColors.card,
                        backgroundImage: _profileImageBase64.isNotEmpty
                            ? _buildProfileImage()
                            : null,
                        child: _buildProfileImage() == null
                            ? Text(
                                _getInitials(),
                                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: context.appColors.accentBlue),
                              )
                            : null,
                      ),
                      if (_isEditing)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: context.appColors.primaryBlue, shape: BoxShape.circle),
                            child: Icon(Icons.camera_alt, color: Colors.white, size: 24),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isEditing)
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(tr('tap_change_photo'), style: TextStyle(color: context.appColors.textSecondary, fontSize: 15)),
                  ),
                SizedBox(height: 24),
                if (_message != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _isSuccess ? Colors.green.shade900.withOpacity(0.3) : Colors.red.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _isSuccess ? Colors.green.shade700 : Colors.red.shade700),
                    ),
                    child: Row(
                      children: [
                        Icon(_isSuccess ? Icons.check_circle : Icons.error, color: _isSuccess ? Colors.greenAccent : Colors.redAccent, size: 24),
                        SizedBox(width: 12),
                        Expanded(child: Text(_message!, style: TextStyle(color: _isSuccess ? Colors.greenAccent : Colors.redAccent))),
                      ],
                    ),
                  ),
                if (_showStaffWarnings) ...[
                  if (_warningsLoading)
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Center(child: CircularProgressIndicator(color: context.appColors.accentBlue)),
                    )
                  else if (_warnings.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                              SizedBox(width: 8),
                              Text(
                                tr('formal_warnings'),
                                style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          ..._warnings.map(
                            (w) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _warningCategoryLabel(w['category'] as String?),
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    w['notes'] as String? ?? '',
                                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                                  ),
                                  Text(
                                    w['createdAt'] != null
                                        ? DateTime.tryParse(w['createdAt'].toString()).toString().split(' ').first
                                        : '',
                                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                _buildProfileCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.borderBlue.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildField(tr('staff_id'), _staffId, false),
          SizedBox(height: 24),
          _buildField(tr('full_name'), _nameController, _isEditing),
          SizedBox(height: 24),
          _buildField(tr('email'), _email, false),
          SizedBox(height: 24),
          _buildField(tr('phone'), _phoneController, _isEditing),
          SizedBox(height: 24),
          _buildField(tr('department'), _departmentController, _isEditing),
          SizedBox(height: 24),
          _buildField(tr('position'), _positionController, _isEditing),
        ],
      ),
    );
  }

  Widget _buildField(String label, dynamic value, bool editable) {
    if (editable && value is TextEditingController) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.appColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          TextField(
            controller: value,
            style: TextStyle(color: context.appColors.textPrimary, fontSize: 20),
            decoration: InputDecoration(
              filled: true,
              fillColor: context.appColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.appColors.borderBlue.withOpacity(0.5), width: 1.5)),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.appColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        Text(
          value is TextEditingController ? value.text : (value as String? ?? '-'),
          style: TextStyle(color: context.appColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
