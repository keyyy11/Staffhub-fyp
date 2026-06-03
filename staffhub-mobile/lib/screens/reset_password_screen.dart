import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ResetPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || code.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill all fields';
        _successMessage = null;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters';
        _successMessage = null;
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        _errorMessage = 'Passwords do not match';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await AuthService.resetPassword(
      email: email,
      code: code,
      newPassword: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() {
        _successMessage = result.errorMessage ?? 'Password reset successfully';
        _errorMessage = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      setState(() => _errorMessage = result.errorMessage ?? 'Reset failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text('Reset password'),
        backgroundColor: context.appColors.surface,
        foregroundColor: context.appColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter reset code',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.accentBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the 6-digit code sent to your registered email, then choose a new password.',
                style: TextStyle(fontSize: 14, color: context.appColors.textSecondary),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null) ...[
                _messageBox(_errorMessage!, isError: true),
                const SizedBox(height: 16),
              ],
              if (_successMessage != null) ...[
                _messageBox(_successMessage!, isError: false),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: TextStyle(color: context.appColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Registered email',
                  prefixIcon: Icon(Icons.email_outlined, color: context.appColors.accentBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(color: context.appColors.textPrimary, letterSpacing: 4),
                decoration: InputDecoration(
                  labelText: 'Reset code',
                  hintText: '123456',
                  counterText: '',
                  prefixIcon: Icon(Icons.pin_outlined, color: context.appColors.accentBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: context.appColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: Icon(Icons.lock_outlined, color: context.appColors.accentBlue),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                style: TextStyle(color: context.appColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: Icon(Icons.lock_outlined, color: context.appColors.accentBlue),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Reset password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageBox(String message, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.shade900.withOpacity(0.3)
            : Colors.green.shade900.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isError ? Colors.red.shade700 : Colors.green.shade700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red.shade700 : Colors.green.shade400,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: isError ? Colors.redAccent : Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }
}
