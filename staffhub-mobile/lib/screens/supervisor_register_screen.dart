import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import 'supervisor_dashboard_screen.dart';

class SupervisorRegisterScreen extends StatefulWidget {
  const SupervisorRegisterScreen({super.key});

  @override
  State<SupervisorRegisterScreen> createState() => _SupervisorRegisterScreenState();
}

class _SupervisorRegisterScreenState extends State<SupervisorRegisterScreen> {
  final _staffIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secretController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _staffIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final staffId = _staffIdController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final secret = _secretController.text;

    if (staffId.isEmpty || name.isEmpty || email.isEmpty || password.isEmpty || secret.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill all fields';
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

    final result = await AuthService.registerSupervisor(staffId, name, email, password, secret);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SupervisorDashboardScreen()),
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
        title: const Text('Register Supervisor', style: TextStyle(color: AppTheme.textPrimary)),
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
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Normally, supervisors are created by an administrator: register the person as staff, then Admin → Staff pay → Promote to supervisor. Self-registration here only works if the server sets ALLOW_SUPERVISOR_SELF_REGISTER=true.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade700),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                TextField(
                  controller: _staffIdController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _decoration('Staff ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _decoration('Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _decoration('Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _decoration('Password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _secretController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _decoration('Supervisor secret'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Register'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      filled: true,
      fillColor: AppTheme.cardDark,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
