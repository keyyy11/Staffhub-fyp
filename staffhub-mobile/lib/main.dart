import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'screens/login_page.dart';
import 'screens/home_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'widgets/staffhub_logo.dart';

void main() {
  runApp(const StaffHubApp());
}

class StaffHubApp extends StatelessWidget {
  const StaffHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Staff Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthCheckScreen(),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundBlack,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StaffHubLogo(height: 88),
                  SizedBox(height: 28),
                  CircularProgressIndicator(color: AppTheme.accentBlue),
                ],
              ),
            ),
          );
        }
        if (snapshot.data == true) {
          return const _RoleRedirect();
        }
        return const LoginPage();
      },
    );
  }
}

class _RoleRedirect extends StatelessWidget {
  const _RoleRedirect();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService.getCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundBlack,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StaffHubLogo(height: 88),
                  SizedBox(height: 28),
                  CircularProgressIndicator(color: AppTheme.accentBlue),
                ],
              ),
            ),
          );
        }
        final user = snapshot.data;
        final role = user?['role'] as String?;
        if (role == 'admin') {
          return const AdminDashboardScreen();
        }
        return const HomeScreen();
      },
    );
  }
}
