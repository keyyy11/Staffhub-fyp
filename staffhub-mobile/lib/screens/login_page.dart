import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/staffhub_logo.dart';
import 'register_screen.dart';
import 'admin_register_screen.dart';
import 'admin_dashboard_screen.dart';
import 'home_screen.dart';
import 'supervisor_dashboard_screen.dart';

/// Dedicated login page — entry for staff and admin.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter email and password';
        _isLoading = false;
      });
      return;
    }

    final result = await AuthService.login(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      final user = await AuthService.getCurrentUser();
      final role = user?['role'] as String?;
      if (!mounted) return;
      Widget next = const HomeScreen();
      if (role == 'admin') {
        next = const AdminDashboardScreen();
      } else if (role == 'supervisor') {
        next = const SupervisorDashboardScreen();
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    } else {
      setState(() => _errorMessage = result.errorMessage ?? 'Login failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.appColors.surface, context.appColors.background],
            stops: [0.0, 0.5],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 16),
                    const StaffHubLogo(height: 152),
                    SizedBox(height: 24),
                    Text(
                      'Login',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: context.appColors.accentBlue),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sign in with your email and password',
                      style: TextStyle(fontSize: 14, color: context.appColors.textSecondary),
                    ),
                    SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.appColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.appColors.borderBlue.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: context.appColors.primaryBlue.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade700),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red.shade700),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(_errorMessage!, style: TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            cursorColor: context.appColors.accentBlue,
                            style: TextStyle(color: context.appColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'name@email.com',
                              prefixIcon: Icon(Icons.email_outlined, color: context.appColors.accentBlue),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: context.appColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: '••••••••',
                              prefixIcon: Icon(Icons.lock_outlined, color: context.appColors.accentBlue),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                            ),
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.appColors.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text('Sign In'),
                            ),
                          ),
                          SizedBox(height: 12),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    await AuthService.setDemoMode('staff001');
                                    if (!mounted) return;
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                                    );
                                  },
                            child: Text(
                              'Demo Mode (no API)',
                              style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Don't have an account? ", style: TextStyle(color: context.appColors.textSecondary)),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                ),
                                child: Text('Register as Staff', style: TextStyle(color: context.appColors.accentBlue)),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminRegisterScreen()),
                            ),
                            child: Text(
                              'Register as Admin',
                              style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
