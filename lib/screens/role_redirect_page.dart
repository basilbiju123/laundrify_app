import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_dashboard.dart';
import 'delivery_dashboard.dart';
import 'manager_dashboard.dart';
import 'location_page.dart';

/// Role-based redirect after successful login
/// Determines user role and navigates to appropriate dashboard
class RoleRedirectPage extends StatelessWidget {
  const RoleRedirectPage({super.key});

  /// Fetch user role from Firestore
  Future<Map<String, dynamic>> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'role': 'user', 'isBlocked': false};
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // If user document doesn't exist, create it with default role
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? 'User',
          'email': user.email,
          'phone': user.phoneNumber ?? '',
          'role': 'user',
          'isBlocked': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return {'role': 'user', 'isBlocked': false};
      }

      final data = doc.data()!;
      return {
        'role': data['role'] ?? 'user',
        'isBlocked': data['isBlocked'] ?? false,
        'name': data['name'] ?? 'User',
      };
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      return {'role': 'user', 'isBlocked': false};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserData(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF080F1E),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF080F1E),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Error loading user data',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RoleRedirectPage(),
                        ),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final userData = snapshot.data!;
        final role = userData['role'] as String;
        final isBlocked = userData['isBlocked'] as bool;

        // Check if user is blocked
        if (isBlocked) {
          return Scaffold(
            backgroundColor: const Color(0xFF080F1E),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.block,
                      color: Colors.red,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Account Blocked',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your account has been blocked. Please contact support.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Route based on role
        Widget destination;
        switch (role) {
          case 'admin':
            destination = const AdminDashboard();
            break;
          case 'manager':
            destination = const ManagerDashboard();
            break;
          case 'delivery':
            destination = const DeliveryDashboard();
            break;
          case 'staff':
            destination = const StaffDashboard();
            break;
          case 'user':
          default:
            destination = const LocationPage();
            break;
        }

        // Navigate to appropriate dashboard
        return destination;
      },
    );
  }
}

/// Staff Dashboard for laundry processing workers
class StaffDashboard extends StatelessWidget {
  const StaffDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2332),
        elevation: 0,
        title: const Text('Staff Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome ${user?.displayName ?? "Staff Member"}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Laundry Processing',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            _buildCard(
              context,
              title: 'Processing Orders',
              icon: Icons.local_laundry_service,
              color: const Color(0xFF10B981),
              onTap: () {
                // Navigate to processing orders
              },
            ),
            _buildCard(
              context,
              title: 'Mark Complete',
              icon: Icons.check_circle,
              color: const Color(0xFF3B82F6),
              onTap: () {
                // Mark order as complete
              },
            ),
            _buildCard(
              context,
              title: 'My Stats',
              icon: Icons.bar_chart,
              color: const Color(0xFFF59E0B),
              onTap: () {
                // View stats
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
