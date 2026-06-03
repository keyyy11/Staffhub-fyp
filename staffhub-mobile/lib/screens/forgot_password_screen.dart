import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your registered email';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await AuthService.forgotPassword(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() {
        _successMessage = result.errorMessage ??
            'If this email is registered, a reset code has been sent. Check your inbox.';
        _errorMessage = null;
      });
    } else {
      setState(() => _errorMessage = result.errorMessage ?? 'Failed to send reset email');
    }
  }

  void _goToReset() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(initialEmail: _emailController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text('Forgot password'),
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
                'Reset your password',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.accentBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the email registered by your admin. We will send a 6-digit reset code to that address.',
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
                  hintText: 'name@email.com',
                  prefixIcon: Icon(Icons.email_outlined, color: context.appColors.accentBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendResetCode,
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
                      : const Text('Send reset code'),
                ),
              ),
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _goToReset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.appColors.accentBlue,
                    side: BorderSide(color: context.appColors.accentBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Enter reset code'),
                ),
              ],
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
