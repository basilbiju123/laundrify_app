import 'package:flutter/material.dart';
import '../services/role_based_auth_service.dart';
import '../models/firestore_models.dart';
import 'dashboard.dart';
import 'admin_switcher.dart';
import 'manager_dashboard.dart';
import 'delivery_dashboard.dart';
import 'employee_dashboard.dart';
import 'location_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Shown after login to determine which dashboard to navigate to.
class RoleRedirectPage extends StatefulWidget {
  const RoleRedirectPage({super.key});

  @override
  State<RoleRedirectPage> createState() => _RoleRedirectPageState();
}

class _RoleRedirectPageState extends State<RoleRedirectPage> {
  final _roleService = RoleBasedAuthService();

  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    final role = await _roleService.getUserRole();

    if (!mounted) return;

    // Admin → AdminSwitcherWrapper (can switch between all 5 dashboards)
    if (role == UserRole.admin) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminSwitcherWrapper()),
        (r) => false,
      );
      return;
    }

    // Other roles — navigate directly
    final route = await _roleService.getDashboardRoute();
    if (!mounted) return;

    // Regular users: check if location is saved first
    if (route == '/dashboard') {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final data = doc.data();
          final hasLocation = data != null &&
              data['location'] != null &&
              data['location']['latitude'] != null;
          if (!mounted) return;
          if (!hasLocation) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LocationPage()),
              (r) => false,
            );
            return;
          }
        }
      } catch (_) {}
    }
    _navigateTo(route);
  }

  void _navigateTo(String route) {
    Widget page;
    switch (route) {
      case '/admin-dashboard':
        page = const AdminSwitcherWrapper();
        break;
      case '/manager-dashboard':
        page = const ManagerDashboard();
        break;
      case '/delivery-dashboard':
        page = const DeliveryDashboard();
        break;
      case '/employee-dashboard':
        page = const EmployeeDashboard();
        break;
      default:
        page = const DashboardPage();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF080F1E),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF5C518),
          strokeWidth: 2,
        ),
      ),
    );
  }
}
