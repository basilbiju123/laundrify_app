import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// User role types
enum UserRole {
  user, // Regular customer
  delivery, // Delivery person
  manager, // Manager
  admin, // Admin
}

class RoleBasedAuthService {
  static final RoleBasedAuthService _instance =
      RoleBasedAuthService._internal();
  factory RoleBasedAuthService() => _instance;
  RoleBasedAuthService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ⚠️ CHANGE THESE TO YOUR EMAIL ADDRESSES

  // Admin emails - Full system access
  static const List<String> adminEmails = [
    'admin@gmail.com', // <<< CHANGE THIS!
    'bsheena056@gmail.com', // Add more admin emails
  ];

  // Manager emails - Manage orders and operations
  static const List<String> managerEmails = [
    'manager@gmail.com', // <<< CHANGE THIS!
    // Add more manager emails
  ];

  // Delivery emails - Handle deliveries
  static const List<String> deliveryEmails = [
    'delivery@gmail.com', // <<< CHANGE THIS!
    // Add more delivery emails
  ];

  User? get currentUser => _auth.currentUser;
  String? get userId => _auth.currentUser?.uid;

  /// Check user's default role based on email
  UserRole? _getDefaultRoleByEmail() {
    final email = currentUser?.email?.toLowerCase();
    if (email == null) return null;

    // Check admin first (highest priority)
    if (adminEmails.any((adminEmail) => adminEmail.toLowerCase() == email)) {
      return UserRole.admin;
    }

    // Check manager
    if (managerEmails
        .any((managerEmail) => managerEmail.toLowerCase() == email)) {
      return UserRole.manager;
    }

    // Check delivery
    if (deliveryEmails
        .any((deliveryEmail) => deliveryEmail.toLowerCase() == email)) {
      return UserRole.delivery;
    }

    return null; // No default role, will be regular user
  }

  /// Check if current user has a default role assigned
  bool _hasDefaultRole() {
    return _getDefaultRoleByEmail() != null;
  }

  /// Get user's role from Firestore
  Future<UserRole> getUserRole() async {
    if (userId == null) return UserRole.user;

    // Check if user has a default role by email
    final defaultRole = _getDefaultRoleByEmail();
    if (defaultRole != null) {
      // Auto-create role in Firestore if it doesn't exist
      await _ensureDefaultRole(defaultRole);
      return defaultRole;
    }

    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        final roleString = doc.data()?['role'] as String?;
        return _parseRole(roleString);
      }
      return UserRole.user;
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return UserRole.user;
    }
  }

  /// Ensure default role is set in Firestore
  Future<void> _ensureDefaultRole(UserRole role) async {
    if (userId == null) return;

    try {
      final doc = await _db.collection('users').doc(userId).get();

      // Only update if role doesn't match
      final currentRole = doc.data()?['role'] as String?;
      if (!doc.exists || currentRole != role.name) {
        // Determine accessible roles based on the role
        List<String> accessibleRoles;
        switch (role) {
          case UserRole.admin:
            accessibleRoles = ['admin', 'manager', 'delivery', 'user'];
            break;
          case UserRole.manager:
            accessibleRoles = ['manager', 'user'];
            break;
          case UserRole.delivery:
            accessibleRoles = ['delivery', 'user'];
            break;
          case UserRole.user:
            accessibleRoles = ['user'];
            break;
        }

        await _db.collection('users').doc(userId).set({
          'role': role.name,
          'accessibleRoles': accessibleRoles,
          'email': currentUser?.email,
          'name': currentUser?.displayName ?? _getRoleDisplayName(role),
          'photoUrl': currentUser?.photoURL,
          'uid': userId,
          'isDefaultRole': true,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': (doc.exists && doc.data() != null)
              ? doc.data()!['createdAt']
              : FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint(
            '✅ ${role.name} role automatically set for ${currentUser?.email}');
      }
    } catch (e) {
      debugPrint('Error ensuring default role: $e');
    }
  }

  /// Set user's role in Firestore
  Future<void> setUserRole(UserRole role) async {
    if (userId == null) return;

    // Prevent changing role of users with default roles (admin, manager, delivery)
    if (_hasDefaultRole()) {
      debugPrint(
          '⚠️ Cannot change role of default role users (admin/manager/delivery)');
      return;
    }

    try {
      await _db.collection('users').doc(userId).update({
        'role': role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting user role: $e');
    }
  }

  /// Check if user has specific role
  Future<bool> hasRole(UserRole role) async {
    final userRole = await getUserRole();
    return userRole == role;
  }

  /// Check if user is admin
  Future<bool> isAdmin() async {
    return await hasRole(UserRole.admin);
  }

  /// Check if user is manager
  Future<bool> isManager() async {
    return await hasRole(UserRole.manager);
  }

  /// Check if user is delivery person
  Future<bool> isDelivery() async {
    return await hasRole(UserRole.delivery);
  }

  /// Get all roles user has access to (for multi-dashboard access)
  Future<List<UserRole>> getUserAccessibleRoles() async {
    if (userId == null) return [UserRole.user];

    // Check default role and return accessible roles
    final defaultRole = _getDefaultRoleByEmail();
    if (defaultRole != null) {
      switch (defaultRole) {
        case UserRole.admin:
          return [
            UserRole.admin,
            UserRole.manager,
            UserRole.delivery,
            UserRole.user
          ];
        case UserRole.manager:
          return [UserRole.manager, UserRole.user];
        case UserRole.delivery:
          return [UserRole.delivery, UserRole.user];
        case UserRole.user:
          return [UserRole.user];
      }
    }

    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        final roles = doc.data()?['accessibleRoles'] as List?;
        if (roles != null) {
          return roles.map((r) => _parseRole(r as String)).toList();
        }
      }
      // Default: user only has access to their primary role
      final primaryRole = await getUserRole();
      return [primaryRole];
    } catch (e) {
      debugPrint('Error getting accessible roles: $e');
      return [UserRole.user];
    }
  }

  /// Grant user access to additional roles (only for regular users)
  Future<void> grantRoleAccess(List<UserRole> roles) async {
    if (userId == null) return;

    // Prevent changing accessible roles for default role users
    if (_hasDefaultRole()) {
      debugPrint('⚠️ Cannot modify accessible roles for default role users');
      return;
    }

    try {
      await _db.collection('users').doc(userId).update({
        'accessibleRoles': roles.map((r) => r.name).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error granting role access: $e');
    }
  }

  /// Navigate to appropriate dashboard based on role
  Future<String> getDashboardRoute() async {
    final role = await getUserRole();

    switch (role) {
      case UserRole.admin:
        return '/admin-dashboard';
      case UserRole.manager:
        return '/manager-dashboard';
      case UserRole.delivery:
        return '/delivery-dashboard';
      case UserRole.user:
        return '/dashboard';
    }
  }

  /// Show role selection dialog if user has multiple accessible roles
  Future<String?> showRoleSelectionDialog(BuildContext context) async {
    final roles = await getUserAccessibleRoles();

    if (!context.mounted) return null;

    if (roles.length == 1) {
      // User has only one role, go directly to that dashboard
      return _getRoleRoute(roles.first);
    }

    // User has multiple roles, show selection dialog
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3F6FD8),
                Color(0xFF2F4F9F),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose which dashboard to access',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color.fromRGBO(255, 255, 255, 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Dashboard options
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: roles.map((role) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(dialogContext, _getRoleRoute(role)),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _getRoleColor(role).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _getRoleColor(role).withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(role),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getRoleIcon(role),
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getRoleDisplayName(role),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _getRoleColor(role),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getRoleDescription(role),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 18,
                                  color: _getRoleColor(role),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get current user info with role
  Future<Map<String, dynamic>> getCurrentUserInfo() async {
    if (userId == null) return {};

    final role = await getUserRole();
    final accessibleRoles = await getUserAccessibleRoles();

    return {
      'uid': userId,
      'email': currentUser?.email,
      'name': currentUser?.displayName,
      'photoUrl': currentUser?.photoURL,
      'role': role.name,
      'accessibleRoles': accessibleRoles.map((r) => r.name).toList(),
      'isDefaultRole': _hasDefaultRole(),
    };
  }

  /// Helper: Parse role string to enum
  UserRole _parseRole(String? roleString) {
    switch (roleString?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'delivery':
        return UserRole.delivery;
      case 'user':
      default:
        return UserRole.user;
    }
  }

  /// Helper: Get route for role
  String _getRoleRoute(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return '/admin-dashboard';
      case UserRole.manager:
        return '/manager-dashboard';
      case UserRole.delivery:
        return '/delivery-dashboard';
      case UserRole.user:
        return '/dashboard';
    }
  }

  /// Helper: Get icon for role
  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.manager:
        return Icons.manage_accounts;
      case UserRole.delivery:
        return Icons.delivery_dining;
      case UserRole.user:
        return Icons.person;
    }
  }

  /// Helper: Get color for role
  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.manager:
        return Colors.blue;
      case UserRole.delivery:
        return Colors.green;
      case UserRole.user:
        return Colors.grey;
    }
  }

  /// Helper: Get display name for role
  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin Dashboard';
      case UserRole.manager:
        return 'Manager Dashboard';
      case UserRole.delivery:
        return 'Delivery Dashboard';
      case UserRole.user:
        return 'User Dashboard';
    }
  }

  /// Helper: Get description for role
  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Manage entire system';
      case UserRole.manager:
        return 'Manage orders and operations';
      case UserRole.delivery:
        return 'Handle deliveries';
      case UserRole.user:
        return 'Place and track orders';
    }
  }
}
