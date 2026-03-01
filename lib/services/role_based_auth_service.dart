import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/firestore_models.dart';

class RoleBasedAuthService {
  static final RoleBasedAuthService _instance = RoleBasedAuthService._internal();
  factory RoleBasedAuthService() => _instance;
  RoleBasedAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // SUPER ADMIN — this email always has full admin access regardless of DB role
  // ─────────────────────────────────────────────────────────────────────────
  static const String superAdminEmail = 'bsheena056@gmail.com';

  bool get isSuperAdmin {
    final email = _auth.currentUser?.email?.toLowerCase().trim() ?? '';
    return email == superAdminEmail.toLowerCase();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET USER ROLE FROM FIRESTORE
  // ─────────────────────────────────────────────────────────────────────────

  Future<UserRole> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return UserRole.user;

    // Super admin email always gets admin role
    if (isSuperAdmin) return UserRole.admin;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) return UserRole.user;
      final roleStr = (doc.data()?['role'] as String?) ?? 'user';
      return _parseRole(roleStr);
    } catch (_) {
      return UserRole.user;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET ACCESSIBLE ROLES (some users have multiple roles)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<UserRole>> getUserAccessibleRoles() async {
    final role = await getUserRole();
    // Admin can access all dashboards including user
    if (role == UserRole.admin) {
      return [UserRole.user, UserRole.admin, UserRole.manager, UserRole.delivery, UserRole.staff];
    }
    return [role];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET DASHBOARD ROUTE BASED ON ROLE
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> getDashboardRoute() async {
    final role = await getUserRole();
    switch (role) {
      case UserRole.admin:
        return '/admin-dashboard';
      case UserRole.manager:
        return '/manager-dashboard';
      case UserRole.delivery:
        return '/delivery-dashboard';
      case UserRole.staff:
        return '/employee-dashboard';
      default:
        return '/dashboard';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHOW ROLE SELECTION DIALOG (for multi-role users)
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> showRoleSelectionDialog(BuildContext context) async {
    final roles = await getUserAccessibleRoles();
    if (!context.mounted) return null;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF080F1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.dashboard_rounded, color: Color(0xFFF5C518), size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Choose Dashboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
              const SizedBox(height: 6),
              const Text('Select how you want to continue',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              ...roles.map((role) {
                final route = _routeForRole(role);
                final label = _labelForRole(role);
                final icon = _iconForRole(role);
                final color = _colorForRole(role);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, route),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Text(label,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color))),
                            Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.5), size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROLE MANAGEMENT — Add/Remove roles for users
  // ─────────────────────────────────────────────────────────────────────────

  /// Assign a role to a user by UID
  Future<void> assignRole(String uid, String role) async {
    await _db.collection('users').doc(uid).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a role from a user (set back to 'user')
  Future<void> removeRole(String uid) async {
    await _db.collection('users').doc(uid).update({
      'role': 'user',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add role by email — finds the user and sets their role
  Future<Map<String, dynamic>> addRoleByEmail(String email, String role) async {
    try {
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        return {'success': false, 'error': 'No user found with email: $email'};
      }

      final doc = snap.docs.first;
      await _db.collection('users').doc(doc.id).update({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'uid': doc.id,
        'name': doc.data()['name'] ?? '',
        'email': email,
        'role': role,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get all users with a specific role
  Stream<QuerySnapshot> getUsersByRole(String role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _routeForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:    return '/admin-dashboard';
      case UserRole.manager:  return '/manager-dashboard';
      case UserRole.delivery: return '/delivery-dashboard';
      case UserRole.staff:    return '/employee-dashboard';
      default:                return '/dashboard';
    }
  }

  String _labelForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:    return 'Admin Dashboard';
      case UserRole.manager:  return 'Manager Dashboard';
      case UserRole.delivery: return 'Delivery Dashboard';
      case UserRole.staff:    return 'Employee Dashboard';
      default:                return 'User Dashboard';
    }
  }

  IconData _iconForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:    return Icons.admin_panel_settings_rounded;
      case UserRole.manager:  return Icons.manage_accounts_rounded;
      case UserRole.delivery: return Icons.delivery_dining_rounded;
      case UserRole.staff:    return Icons.badge_rounded;
      default:                return Icons.person_rounded;
    }
  }

  Color _colorForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:    return const Color(0xFF080F1E);
      case UserRole.manager:  return const Color(0xFF7C3AED);
      case UserRole.delivery: return const Color(0xFF0EA5E9);
      case UserRole.staff:    return const Color(0xFF059669);
      default:                return const Color(0xFF1B4FD8);
    }
  }

  UserRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin':    return UserRole.admin;
      case 'manager':  return UserRole.manager;
      case 'delivery': return UserRole.delivery;
      case 'staff':    return UserRole.staff;
      default:         return UserRole.user;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHECK IF USER IS BLOCKED
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> isUserBlocked() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    // Super admin is never blocked
    if (isSuperAdmin) return false;
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      return doc.data()?['isBlocked'] ?? false;
    } catch (_) {
      return false;
    }
  }
}
