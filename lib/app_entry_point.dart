import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/splash_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/auth_options_page.dart';
import 'screens/dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/manager_dashboard.dart';
import 'screens/delivery_dashboard.dart';
import 'screens/employee_dashboard.dart';
import 'services/role_based_auth_service.dart';

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});
  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool? _onboardingDone;
  bool _splashFinished = false;
  final RoleBasedAuthService _roleService = RoleBasedAuthService();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _onboardingDone = prefs.getBool('onboarding_done') ?? false);
  }

  void _onSplashFinished() {
    if (!mounted || _splashFinished) return;
    setState(() => _splashFinished = true);
  }

  Future<void> _onOnboardingFinished() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_splashFinished) {
      return SplashPage(onFinished: _onSplashFinished);
    }
    if (_onboardingDone == false) {
      return OnboardingPage(onFinished: _onOnboardingFinished);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF080F1E),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFF5C518))),
          );
        }
        if (snapshot.hasData) {
          return _AuthedRouter(roleService: _roleService);
        }
        return const AuthOptionsPage();
      },
    );
  }
}

// ── Handles routing after confirmed login ──────────────────────────────────
class _AuthedRouter extends StatefulWidget {
  final RoleBasedAuthService roleService;
  const _AuthedRouter({required this.roleService});
  @override
  State<_AuthedRouter> createState() => _AuthedRouterState();
}

class _AuthedRouterState extends State<_AuthedRouter> {
  bool _routing = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final accessibleRoles = await widget.roleService.getUserAccessibleRoles();
    if (!mounted) return;

    if (accessibleRoles.length > 1) {
      // Multi-role user: always show picker on fresh login
      final selected = await widget.roleService.showRoleSelectionDialog(context);
      if (!mounted) return;
      final route = selected ?? '/dashboard';
      setState(() { _destination = _widgetForRoute(route); _routing = false; });
      return;
    }

    final route = await widget.roleService.getDashboardRoute();
    if (!mounted) return;
    setState(() { _destination = _widgetForRoute(route); _routing = false; });
  }

  Widget _widgetForRoute(String route) {
    switch (route) {
      case '/admin-dashboard':    return const AdminDashboard();
      case '/manager-dashboard':  return const ManagerDashboard();
      case '/delivery-dashboard': return const DeliveryDashboard();
      case '/employee-dashboard': return const EmployeeDashboard();
      default:                    return const DashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_routing) {
      return const Scaffold(
        backgroundColor: Color(0xFF080F1E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF5C518))),
      );
    }
    return _destination!;
  }
}
