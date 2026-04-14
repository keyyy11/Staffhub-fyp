import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
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
  bool _loading = true;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await AuthService.getCurrentUser();
    if (user == null) return;
    setState(() {
      _staffId = user['staffId'] as String? ?? '';
      _name = user['name'] as String? ?? '';
      _email = user['email'] as String? ?? '';
      _nameController.text = _name;
    });

    try {
      final result = await ApiService.getAdminProfile();
      if (result['success'] == true && result['data'] != null && mounted) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _name = data['name'] as String? ?? _name;
          _email = data['email'] as String? ?? _email;
          _phone = data['phone'] as String? ?? '';
          _department = data['department'] as String? ?? '';
          _position = data['position'] as String? ?? '';
          final img = data['profileImage'] as String?;
          if (img != null && img.isNotEmpty) _profileImageBase64 = img;
          _nameController.text = _name;
          _phoneController.text = _phone;
          _departmentController.text = _department;
          _positionController.text = _position;
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
    } catch (_) {
      if (mounted) _showMessage('Failed to pick image', false);
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

    try {
      final result = await ApiService.updateAdminProfile(
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
          'role': 'admin',
        });
        setState(() {
          _name = data['name'] as String? ?? _name;
          _phone = data['phone'] as String? ?? '';
          _department = data['department'] as String? ?? '';
          _position = data['position'] as String? ?? '';
          _profileImageBase64 = data['profileImage'] as String? ?? '';
          _isEditing = false;
        });
        _showMessage('Profile updated', true);
      } else {
        _showMessage(result['message'] as String? ?? 'Update failed', false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showMessage('Could not save. Check API connection.', false);
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
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundBlack,
        appBar: AppBar(
          title: const Text('Admin profile', style: TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: AppTheme.surfaceDark,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Admin profile', style: TextStyle(color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : () => setState(() => _isEditing = false),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentBlue))
                : Text(_isEditing ? 'Save' : 'Edit', style: const TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _isEditing ? _pickImage : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 72,
                        backgroundColor: AppTheme.cardDark,
                        backgroundImage: _profileImageBase64.isNotEmpty ? _buildProfileImage() : null,
                        child: _buildProfileImage() == null
                            ? Text(
                                _getInitials(),
                                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.accentBlue),
                              )
                            : null,
                      ),
                      if (_isEditing)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: AppTheme.primaryBlue, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isEditing)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Tap to change photo', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ),
                const SizedBox(height: 20),
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
                        Icon(_isSuccess ? Icons.check_circle : Icons.error, color: _isSuccess ? Colors.greenAccent : Colors.redAccent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_message!, style: TextStyle(color: _isSuccess ? Colors.greenAccent : Colors.redAccent))),
                      ],
                    ),
                  ),
                _buildCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field('Role', 'Administrator', false),
          const SizedBox(height: 20),
          _field('Staff ID', _staffId, false),
          const SizedBox(height: 20),
          _field('Full name', _nameController, _isEditing),
          const SizedBox(height: 20),
          _field('Email', _email, false),
          const SizedBox(height: 20),
          _field('Phone', _phoneController, _isEditing),
          const SizedBox(height: 20),
          _field('Department', _departmentController, _isEditing),
          const SizedBox(height: 20),
          _field('Position', _positionController, _isEditing),
        ],
      ),
    );
  }

  Widget _field(String label, dynamic value, bool editable) {
    if (editable && value is TextEditingController) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: value,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceDark,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.borderBlue.withOpacity(0.5), width: 1.5),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(
          value is TextEditingController ? value.text : (value as String? ?? '-'),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
