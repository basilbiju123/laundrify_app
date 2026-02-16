import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _totalUsers = 0;
  int _totalOrders = 0;
  int _activeOrders = 0;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    try {
      // Get total users
      final usersSnapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'user')
          .count()
          .get();

      // Get total orders
      final ordersSnapshot = await _db.collection('orders').count().get();

      // Get active orders
      final activeSnapshot = await _db
          .collection('orders')
          .where('status',
              whereIn: ['pending', 'pickup', 'processing', 'delivery'])
          .count()
          .get();

      // Calculate revenue (sum of completed orders)
      final completedOrders = await _db
          .collection('orders')
          .where('status', isEqualTo: 'completed')
          .get();

      double revenue = 0;
      for (var doc in completedOrders.docs) {
        revenue += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
      }

      setState(() {
        _totalUsers = usersSnapshot.count ?? 0;
        _totalOrders = ordersSnapshot.count ?? 0;
        _activeOrders = activeSnapshot.count ?? 0;
        _totalRevenue = revenue;
      });
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2332),
        elevation: 0,
        title: const Text(
          'Admin Panel',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Text(
              'Welcome Admin',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 32),

            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Total Users',
                    _totalUsers.toString(),
                    Icons.people,
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Total Orders',
                    _totalOrders.toString(),
                    Icons.shopping_bag,
                    const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Active Orders',
                    _activeOrders.toString(),
                    Icons.local_shipping,
                    const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Revenue',
                    '₹${_totalRevenue.toStringAsFixed(0)}',
                    Icons.currency_rupee,
                    const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Management Section
            const Text(
              'Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            _menuCard(
              'User Management',
              'Manage all users, block/unblock accounts',
              Icons.people_outline,
              const Color(0xFF10B981),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserManagementPage()),
                );
              },
            ),
            _menuCard(
              'Order Management',
              'View and manage all orders',
              Icons.receipt_long,
              const Color(0xFF3B82F6),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OrderManagementPage()),
                );
              },
            ),
            _menuCard(
              'Employee Management',
              'Add delivery partners, managers, staff',
              Icons.badge,
              const Color(0xFFF59E0B),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EmployeeManagementPage()),
                );
              },
            ),
            _menuCard(
              'Services Management',
              'Manage services, items, and pricing',
              Icons.local_laundry_service,
              const Color(0xFF8B5CF6),
              () {
                // Navigate to services management
              },
            ),
            _menuCard(
              'Assign Delivery Partner',
              'Assign orders to delivery partners',
              Icons.assignment_turned_in,
              const Color(0xFFEC4899),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AssignDeliveryPage()),
                );
              },
            ),
            _menuCard(
              'Coupons & Offers',
              'Create and manage discount coupons',
              Icons.local_offer,
              const Color(0xFF14B8A6),
              () {
                // Navigate to coupons management
              },
            ),
            _menuCard(
              'Revenue & Reports',
              'View analytics and download reports',
              Icons.analytics,
              const Color(0xFFF97316),
              () {
                // Navigate to reports
              },
            ),
            _menuCard(
              'Notifications',
              'Send push notifications to users',
              Icons.notifications,
              const Color(0xFF06B6D4),
              () {
                // Navigate to notifications
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: .6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(16),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: .6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: .3),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder pages (you can expand these)
class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: const Center(child: Text('User Management Page')),
    );
  }
}

class OrderManagementPage extends StatelessWidget {
  const OrderManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Management')),
      body: const Center(child: Text('Order Management Page')),
    );
  }
}

class EmployeeManagementPage extends StatelessWidget {
  const EmployeeManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Management')),
      body: const Center(child: Text('Employee Management Page')),
    );
  }
}

class AssignDeliveryPage extends StatelessWidget {
  const AssignDeliveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Delivery')),
      body: const Center(child: Text('Assign Delivery Page')),
    );
  }
}
