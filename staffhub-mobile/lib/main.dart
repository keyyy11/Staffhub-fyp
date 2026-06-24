import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_theme.dart';
import 'l10n/l10n.dart';
import 'screens/login_page.dart';
import 'screens/home_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/supervisor_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'services/settings_controller.dart';
import 'services/api_config_service.dart';
import 'widgets/staffhub_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsController.instance.load();
  await ApiConfigService.instance.load();
  runApp(const StaffHubApp());
}

class StaffHubApp extends StatelessWidget {
  const StaffHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsController.instance,
      builder: (context, _) {
        final s = SettingsController.instance;
        return MaterialApp(
          title: tr('app_title'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: s.themeMode,
          locale: s.locale,
          supportedLocales: const [
            Locale('en'),
            Locale('ms'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthCheckScreen(),
        );
      },
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
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const StaffHubLogo(height: 100),
                  const SizedBox(height: 28),
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const StaffHubLogo(height: 100),
                  const SizedBox(height: 28),
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
        if (role == 'supervisor') {
          return const SupervisorDashboardScreen();
        }
        return const HomeScreen();
      },
    );
  }
}
