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
import 'models/firestore_models.dart';
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
    _loadOnboardingPref();
  }

  // 🔹 Load onboarding flag
  Future<void> _loadOnboardingPref() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _onboardingDone = prefs.getBool('onboarding_done') ?? false;
    });
  }

  // 🔹 Called when splash video finishes
  void _onSplashFinished() {
    if (!mounted || _splashFinished) return;

    setState(() {
      _splashFinished = true;
    });
  }

  // 🔹 Called when onboarding is completed or skipped
  Future<void> _onOnboardingFinished() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    if (!mounted) return;

    setState(() {
      _onboardingDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ⏳ Still loading SharedPreferences
    if (_onboardingDone == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 🎬 Splash screen (runs once per app start)
    if (!_splashFinished) {
      return SplashPage(onFinished: _onSplashFinished);
    }

    // 🧭 Onboarding (first app launch only)
    if (_onboardingDone == false) {
      return OnboardingPage(onFinished: _onOnboardingFinished);
    }

    // 🔐 Firebase auth routing
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Waiting for Firebase response
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User logged in → Route to appropriate dashboard
        if (snapshot.hasData) {
          return FutureBuilder<List<UserRole>>(
            future: _roleService.getUserAccessibleRoles(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (!roleSnapshot.hasData) {
                return const DashboardPage();
              }

              final accessibleRoles = roleSnapshot.data!;

              // Multiple roles - show selection dialog
              if (accessibleRoles.length > 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  final selectedRoute =
                      await _roleService.showRoleSelectionDialog(context);
                  if (selectedRoute != null && mounted) {
                    _navigateToDashboard(selectedRoute);
                  }
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // Single role - navigate directly
              return FutureBuilder<String>(
                future: _roleService.getDashboardRoute(),
                builder: (context, routeSnapshot) {
                  if (routeSnapshot.hasData) {
                    return _getDashboardWidget(routeSnapshot.data!);
                  }
                  return const DashboardPage();
                },
              );
            },
          );
        }

        // User not logged in → Auth options
        return const AuthOptionsPage();
      },
    );
  }

  Widget _getDashboardWidget(String route) {
    switch (route) {
      case '/admin-dashboard':
        return const AdminDashboard();
      case '/manager-dashboard':
        return const ManagerDashboard();
      case '/delivery-dashboard':
        return const DeliveryDashboard();
      case '/employee-dashboard':
        return const EmployeeDashboard();
      case '/dashboard':
      default:
        return const DashboardPage();
    }
  }

  void _navigateToDashboard(String route) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _getDashboardWidget(route),
      ),
    );
  }
}
