import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      return const Scaffold(
        backgroundColor: Color(0xFF080F1E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF5C518))),
      );
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
    final user = FirebaseAuth.instance.currentUser;

    // ── Block check: check /users AND all role collections ──────────────────
    if (user != null) {
      try {
        bool isBlocked = false;
        // Check /users first
        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          isBlocked = (userDoc.data()?['isBlocked'] ?? false) == true;
        }
        // Also check role collections (employees not in /users)
        if (!isBlocked) {
          for (final col in ['delivery_agents', 'managers', 'staff']) {
            final doc = await FirebaseFirestore.instance
                .collection(col).doc(user.uid).get();
            if (doc.exists && (doc.data()?['isBlocked'] ?? false) == true) {
              isBlocked = true;
              break;
            }
          }
        }
        if (isBlocked) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          setState(() {
            _destination = const _BlockedAccountScreen();
            _routing = false;
          });
          return;
        }
      } catch (_) {
        // If Firestore unreachable, allow through — don't block on network error
      }
    }

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

// ── Shown when a blocked user tries to sign in ────────────────────────────
class _BlockedAccountScreen extends StatelessWidget {
  const _BlockedAccountScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Red block icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                      width: 2),
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: Color(0xFFEF4444),
                  size: 44,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Account Suspended',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your account has been suspended by an administrator. Please contact support if you believe this is a mistake.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    // StreamBuilder in build() will automatically
                    // re-render to AuthOptionsPage on sign-out
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Back to Sign In',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Color(0xFF2D3A52)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
