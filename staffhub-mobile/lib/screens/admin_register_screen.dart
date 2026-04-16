import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _staffIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminSecretController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _staffIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _adminSecretController.dispose();
    super.dispose();
  }

  Future<void> _registerAdmin() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final staffId = _staffIdController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final adminSecret = _adminSecretController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || adminSecret.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill name, email, password, and admin secret';
        _isLoading = false;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters';
        _isLoading = false;
      });
      return;
    }

    final result = await AuthService.registerAdmin(
      staffId.isEmpty ? null : staffId,
      name,
      email,
      password,
      adminSecret,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        (route) => false,
      );
    } else {
      setState(() => _errorMessage = result.errorMessage ?? 'Registration failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Register Admin', style: TextStyle(color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.surfaceDark, AppTheme.backgroundBlack],
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderBlue.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade700),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                            if (_errorMessage!.contains('API') || _errorMessage!.contains('Connection'))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('Ensure the API is running (npm.cmd run dev)', style: TextStyle(fontSize: 12, color: Colors.red.shade200)),
                              ),
                          ],
                        ),
                      ),
                  _buildField('Admin ID (optional)', _staffIdController, 'Leave empty for auto ADM001…'),
                  const SizedBox(height: 16),
                  _buildField('Full Name', _nameController, 'Admin Name'),
                  const SizedBox(height: 16),
                  _buildField('Email', _emailController, 'admin@staffhub.com', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildField('Password (min 6)', _passwordController, '••••••', obscure: _obscurePassword, onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword)),
                  const SizedBox(height: 16),
                  _buildField('Admin Secret', _adminSecretController, 'admin123', obscure: true),
                  const SizedBox(height: 8),
                  const Text('Default secret: admin123 (set ADMIN_SECRET in .env to change)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerAdmin,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create Admin'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {bool obscure = false, VoidCallback? onToggleObscure, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType ?? TextInputType.text,
          autocorrect: keyboardType != TextInputType.emailAddress,
          enableSuggestions: !obscure,
          cursorColor: AppTheme.accentBlue,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppTheme.surfaceDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: onToggleObscure != null
                ? IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary), onPressed: onToggleObscure)
                : null,
          ),
        ),
      ],
    );
  }
}
