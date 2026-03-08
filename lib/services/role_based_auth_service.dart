import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';
import 'employee_notification_service.dart';
import 'dart:convert';

// ─── Hardcoded super-admin emails ────────────────────────────────────────────
// These two accounts ALWAYS have admin access to ALL 5 dashboards,
// regardless of what is stored in Firestore.
const Set<String> kSuperAdminEmails = {
  'bsheena056@gmail.com',
  'alenpoovan@gmail.com',
};

/// Returns true if [email] belongs to a hardcoded super-admin.
bool isHardcodedAdmin(String? email) =>
    email != null && kSuperAdminEmails.contains(email.toLowerCase().trim());

/// Returns ALL 5 accessible dashboard routes for a super-admin.
const List<String> kAdminAllRoutes = [
  '/admin-dashboard',
  '/manager-dashboard',
  '/delivery-dashboard',
  '/employee-dashboard',
  '/dashboard',
];


/// Central service that:
///   1. Reads the 'role' field from /users/{uid} after login
///   2. Returns the correct dashboard route
///   3. Writes to role-specific collections (managers / delivery_agents / staff)
///      whenever admin assigns / changes a role
class RoleBasedAuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const Map<String, String> _roleCollections = {
    'manager': 'managers',
    'delivery': 'delivery_agents',
    'staff': 'staff',
  };

  String _normEmail(String? email) => (email ?? '').toLowerCase().trim();

  Future<Map<String, dynamic>?> _findEmployeeByEmail(String email) async {
    final normalized = _normEmail(email);
    if (normalized.isEmpty) return null;
    final uid = _auth.currentUser?.uid;
    for (final entry in _roleCollections.entries) {
      // Check by UID first (fast — O(1) doc lookup, covers post-first-login)
      if (uid != null) {
        final byUid = await _db.collection(entry.value).doc(uid).get();
        if (byUid.exists) {
          return {'role': entry.key, 'collection': entry.value, 'doc': byUid};
        }
      }
      // Fall back to email query (covers pre-first-login pending docs)
      final q = await _db
          .collection(entry.value)
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        return {
          'role': entry.key,
          'collection': entry.value,
          'doc': q.docs.first,
        };
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // 1.  ROUTE RESOLUTION  (called right after any sign-in)
  // ─────────────────────────────────────────────────────────────

  /// Returns the dashboard route string for the currently signed-in user.
  /// Super-admin emails always return '/admin-dashboard'.
  /// Otherwise: role stored in /users/{uid}  →  fallback '/dashboard'
  Future<String> getDashboardRoute() async {
    final user = _auth.currentUser;
    if (user == null) return '/dashboard';

    // Super-admin email bypass — always admin regardless of Firestore
    if (isHardcodedAdmin(user.email)) return '/admin-dashboard';

    try {
      final employee = await _findEmployeeByEmail(user.email ?? '');
      if (employee != null) {
        return _routeForRole(employee['role'] as String);
      }

      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final byEmail = await _db
            .collection('users')
            .where('email', isEqualTo: _normEmail(user.email))
            .limit(1)
            .get();
        if (byEmail.docs.isEmpty) return '/dashboard';
        final role =
            (byEmail.docs.first.data()['role'] as String? ?? 'user').toLowerCase();
        return _routeForRole(role);
      }

      final role = (doc.data()?['role'] as String? ?? 'user').toLowerCase();
      return _routeForRole(role);
    } catch (_) {
      return '/dashboard';
    }
  }

  /// Same as [getDashboardRoute] but also returns every accessible route
  /// (useful when a user has more than one role — rare but supported).
  Future<List<String>> getUserAccessibleRoles() async {
    final user = _auth.currentUser;
    if (user == null) return ['/dashboard'];

    // Super-admin email → all 5 dashboards
    if (isHardcodedAdmin(user.email)) return List<String>.from(kAdminAllRoutes);

    try {
      final employee = await _findEmployeeByEmail(user.email ?? '');
      if (employee != null) {
        return [_routeForRole(employee['role'] as String)];
      }

      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final byEmail = await _db
            .collection('users')
            .where('email', isEqualTo: _normEmail(user.email))
            .limit(1)
            .get();
        if (byEmail.docs.isEmpty) return ['/dashboard'];
        final role =
            (byEmail.docs.first.data()['role'] as String? ?? 'user').toLowerCase();
        if (role == 'admin') return List<String>.from(kAdminAllRoutes);
        return [_routeForRole(role)];
      }

      final role = (doc.data()?['role'] as String? ?? 'user').toLowerCase();
      // Firestore admins also get all dashboards
      if (role == 'admin') return List<String>.from(kAdminAllRoutes);
      // Single role — wrap in list
      return [_routeForRole(role)];
    } catch (_) {
      return ['/dashboard'];
    }
  }

  String _routeForRole(String role) {
    switch (role) {
      case 'admin':
        return '/admin-dashboard';
      case 'manager':
        return '/manager-dashboard';
      case 'delivery':
        return '/delivery-dashboard';
      case 'staff':
        return '/employee-dashboard';
      default:
        return '/dashboard';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2.  GOOGLE SIGN-IN  — ensure pre-assigned role is preserved
  // ─────────────────────────────────────────────────────────────

  /// Call this from AuthService after a successful Google sign-in.
  ///
  /// Logic:
  ///   a) If /users/{uid} already exists → keep its role (admin may have
  ///      pre-assigned one before first login).
  ///   b) If it is a brand-new Google account → create with role='user'.
  ///   c) If the account was pre-registered by admin using email (no uid yet)
  ///      → merge the Google uid into that doc.
  ///
  /// Returns the dashboard route string.
  Future<String> handleGoogleSignIn(User firebaseUser) async {
    final uid = firebaseUser.uid;
    final email = (firebaseUser.email ?? '').toLowerCase().trim();

    // ── STEP 1: Check role-specific collections FIRST ──────────────
    // Admin adds employees to delivery_agents/managers/staff BEFORE they sign in.
    // We must check these BEFORE /users so employees are never routed to /dashboard.
    for (final entry in {
      'manager': 'managers',
      'delivery': 'delivery_agents',
      'staff': 'staff',
    }.entries) {
      // Check by UID first (already linked)
      final byUid = await _db.collection(entry.value).doc(uid).get();
      if (byUid.exists) {
        await _db.collection(entry.value).doc(uid).set({
          'uid': uid,
          'email': email,
          'photoURL': firebaseUser.photoURL,
          'displayName': firebaseUser.displayName ?? '',
          'emailVerified': firebaseUser.emailVerified,
          'lastSignIn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return _routeForRole(entry.key);
      }

      // Check by email (admin pre-registered, no uid yet)
      final byEmail = await _db
          .collection(entry.value)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) {
        final roleDoc = byEmail.docs.first;
        final roleData = roleDoc.data();
        // Migrate to uid-keyed doc
        await _db.collection(entry.value).doc(uid).set({
          ...roleData,
          'uid': uid,
          'email': email,
          'photoURL': firebaseUser.photoURL,
          'displayName': firebaseUser.displayName ?? roleData['name'] ?? '',
          'emailVerified': firebaseUser.emailVerified,
          'lastSignIn': FieldValue.serverTimestamp(),
          'syncedAt': FieldValue.serverTimestamp(),
          'isPending': false,
        }, SetOptions(merge: true));
        if (roleDoc.id != uid) await roleDoc.reference.delete();
        return _routeForRole(entry.key);
      }
    }

    // ── STEP 2: Check /users by uid ────────────────────────────────
    final userDocRef = _db.collection('users').doc(uid);
    final existingDoc = await userDocRef.get();

    if (existingDoc.exists) {
      final data = existingDoc.data()!;
      final role = (data['role'] as String? ?? 'user').toLowerCase();
      await userDocRef.update({
        'email': email,
        'photoURL': firebaseUser.photoURL,
        'displayName': firebaseUser.displayName,
        'lastSignIn': FieldValue.serverTimestamp(),
        'authMethod': 'google',
      });
      // If this users doc has an employee role, sync to role collection
      if (role != 'user' && role != 'admin') {
        await _syncToRoleCollection(uid, role, data);
      }
      return _routeForRole(role);
    }

    // ── STEP 3: Check /users by email (admin pre-registered in /users) ──
    final preRegistered = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .where('createdByAdmin', isEqualTo: true)
        .limit(1)
        .get();

    if (preRegistered.docs.isNotEmpty) {
      final preDoc = preRegistered.docs.first;
      final preData = preDoc.data();
      final role = (preData['role'] as String? ?? 'user').toLowerCase();
      final mergedData = {
        ...preData,
        'uid': uid,
        'email': email,
        'photoURL': firebaseUser.photoURL,
        'displayName': firebaseUser.displayName ?? preData['name'] ?? '',
        'authMethod': 'google',
        'emailVerified': firebaseUser.emailVerified,
        'lastSignIn': FieldValue.serverTimestamp(),
      };
      await userDocRef.set(mergedData);
      if (preDoc.id != uid) await preDoc.reference.delete();
      if (role != 'user' && role != 'admin') {
        await _syncToRoleCollection(uid, role, mergedData);
      }
      return _routeForRole(role);
    }

    // ── STEP 4: Truly new customer — create /users doc with role='user' ──
    await userDocRef.set({
      'uid': uid,
      'name': firebaseUser.displayName ?? '',
      'email': email,
      'phone': firebaseUser.phoneNumber ?? '',
      'photoURL': firebaseUser.photoURL,
      'role': 'user',
      'isBlocked': false,
      'isActive': true,
      'authMethod': 'google',
      'emailVerified': firebaseUser.emailVerified,
      'loyaltyPoints': 0,
      'totalOrders': 0,
      'totalSpent': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSignIn': FieldValue.serverTimestamp(),
    });

    return '/dashboard';
  }

  // ─────────────────────────────────────────────────────────────
  // 3.  ROLE ASSIGNMENT  (admin operations)
  // ─────────────────────────────────────────────────────────────

  /// Assigns [newRole] to a user doc by [uid].
  /// Also writes a mirrored document to the role-specific collection.
  /// Sends an in-app notification to the employee about their role change.
  Future<void> assignRole(String uid, String newRole) async {
    Map<String, dynamic>? sourceData;
    String? oldRole;
    for (final entry in _roleCollections.entries) {
      final doc = await _db.collection(entry.value).doc(uid).get();
      if (doc.exists) {
        sourceData = doc.data();
        oldRole = entry.key;
        break;
      }
    }
    sourceData ??= (await _db.collection('users').doc(uid).get()).data();
    if (sourceData == null) return;

    await _removeFromAllRoleCollections(uid);
    if (newRole != 'user' && newRole != 'admin') {
      await _syncToRoleCollection(uid, newRole, {
        ...sourceData,
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // ── Notify the employee about their role change ──
    try {
      final roleLabel = _labelForRole(newRole);
      final oldLabel = oldRole != null ? _labelForRole(oldRole) : 'previous role';
      final name = sourceData['name'] as String? ?? 'Employee';

      // In-app Firestore notification
      await _db.collection('notifications').add({
        'userId': uid,
        'title': '🔄 Your Role Has Been Updated',
        'message': 'Hi \$name, your role has been changed from \$oldLabel to \$roleLabel. Please sign out and sign back in to access your updated dashboard.',
        'body': 'Hi \$name, your role has been changed from \$oldLabel to \$roleLabel.',
        'type': 'role_change',
        'role': newRole,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Fire local notification immediately (visible even without FCM/OneSignal)
      NotificationService().showRoleNotification(name: name, newRole: roleLabel);

      // Send role change email
      final empEmail = sourceData['email'] as String? ?? '';
      if (empEmail.isNotEmpty) {
        EmployeeNotificationService().sendRoleChangedEmail(
          name: name,
          email: empEmail,
          newRole: newRole,
        );
      }

      // Push notification via OneSignal (best-effort, may not work in demo)
      await _sendRoleChangePush(uid: uid, name: name, newRole: roleLabel, oldRole: oldLabel);
    } catch (e) {
      debugPrint('assignRole notification error (non-fatal): \$e');
    }
  }

  Future<void> _sendRoleChangePush({
    required String uid,
    required String name,
    required String newRole,
    required String oldRole,
  }) async {
    const appId = '92ab5f14-7803-43d2-b8b8-47a11527a89a';
    const oneSignalRestKey = 'os_v2_app_skvv6fdyanb5fofyi6qrkj5itj3cx66rowaudiuhmf24jrvmzebfezsaqbc4qcikgnsh5yhy3fib5jbir35u3z45yynr4y6nq4akglq';
    try {
      // Get player ID from role collections or users
      String? playerId;
      for (final col in ['delivery_agents', 'managers', 'staff', 'users']) {
        final doc = await _db.collection(col).doc(uid).get();
        if (doc.exists) {
          playerId = doc.data()?['oneSignalPlayerId'] as String?;
          if (playerId != null && playerId.isNotEmpty) break;
        }
      }
      if (playerId == null || playerId.isEmpty) return;
      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Basic $oneSignalRestKey'},
        body: jsonEncode({
          'app_id': appId,
          'include_player_ids': [playerId],
          'headings': {'en': '🔄 Role Updated'},
          'contents': {'en': 'Hi \$name, you are now a \$newRole. Sign out and back in to access your new dashboard.'},
          'data': {'type': 'role_change'},
        }),
      );
    } catch (e) {
      debugPrint('_sendRoleChangePush error (non-fatal): \$e');
    }
  }

  String _labelForRole(String role) {
    switch (role.toLowerCase()) {
      case 'delivery': return 'Delivery Agent';
      case 'manager': return 'Manager';
      case 'staff': return 'Staff Member';
      case 'admin': return 'Administrator';
      default: return role[0].toUpperCase() + role.substring(1);
    }
  }

  /// Assigns role by looking up a user's email.
  /// Returns {success: bool, name: String, phone: String, employeeId: String, error: String?}
  Future<Map<String, dynamic>> addRoleByEmail(
      String email, String role) async {
    try {
      final normalized = _normEmail(email);
      if (normalized.isEmpty) {
        return {'success': false, 'error': 'Email is required'};
      }
      if (!_roleCollections.containsKey(role)) {
        return {'success': false, 'error': 'Invalid role'};
      }

      Map<String, dynamic> baseData = {};
      String? existingUid;

      final existingEmployee = await _findEmployeeByEmail(normalized);
      if (existingEmployee != null) {
        final doc =
            existingEmployee['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
        baseData = doc.data();
        existingUid = baseData['uid'] as String?;
        await doc.reference.delete();
      }

      final userSnap = await _db
          .collection('users')
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
      if (userSnap.docs.isNotEmpty) {
        final u = userSnap.docs.first.data();
        existingUid ??= userSnap.docs.first.id;
        baseData = {
          ...u,
          ...baseData,
          'name': (baseData['name'] ?? u['name'] ?? '').toString(),
          'phone': (baseData['phone'] ?? u['phone'] ?? '').toString(),
        };
      }

      final col = _collectionForRole(role)!;
      final docRef = existingUid != null
          ? _db.collection(col).doc(existingUid)
          : _db.collection(col).doc();
      final employeeId =
          (baseData['employeeId'] as String?) ?? _generateEmployeeId(role);

      await docRef.set({
        ...baseData,
        'uid': docRef.id,
        'role': role,
        'email': normalized,
        'employeeId': employeeId,
        'isActive': true,
        'isBlocked': false,
        'createdByAdmin': true,
        'updatedAt': FieldValue.serverTimestamp(),
        if (baseData['createdAt'] == null)
          'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return {
        'success': true,
        'name': (baseData['name'] ?? '').toString(),
        'phone': (baseData['phone'] ?? '').toString(),
        'employeeId': employeeId,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Removes employee role — sets back to 'user' and cleans role collections.
  Future<void> removeRole(String uid) async {
    await _removeFromAllRoleCollections(uid);
  }

  /// Whether current admin can perform destructive actions.
  bool get canPerformDangerousActions {
    // Extend with your own admin-level check if needed
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  // 4.  ROLE-SPECIFIC COLLECTION SYNC  (private helpers)
  // ─────────────────────────────────────────────────────────────

  /// Writes / merges a document into the role-specific collection:
  ///   managers / delivery_agents / staff
  Future<void> _syncToRoleCollection(
      String uid, String role, Map<String, dynamic> userData) async {
    final collectionName = _collectionForRole(role);
    if (collectionName == null) return;

    final roleData = _buildRoleSpecificData(role, userData);
    await _db.collection(collectionName).doc(uid).set(
          {...roleData, 'uid': uid, 'syncedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
  }

  Future<void> _removeFromAllRoleCollections(String uid) async {
    for (final col in ['managers', 'delivery_agents', 'staff']) {
      try {
        final doc = await _db.collection(col).doc(uid).get();
        if (doc.exists) {
          await _db.collection(col).doc(uid).delete();
        }
      } catch (_) {}
    }
  }

  String? _collectionForRole(String role) {
    switch (role) {
      case 'manager':
        return 'managers';
      case 'delivery':
        return 'delivery_agents';
      case 'staff':
        return 'staff';
      default:
        return null;
    }
  }

  /// Builds the role-specific subset of fields to store in the role collection.
  Map<String, dynamic> _buildRoleSpecificData(
      String role, Map<String, dynamic> userData) {
    // Common fields present in all role collections
    final common = {
      'name': userData['name'] ?? '',
      'email': userData['email'] ?? '',
      'phone': userData['phone'] ?? '',
      'photoURL': userData['photoURL'],
      'role': role,
      'isActive': userData['isActive'] ?? true,
      'isBlocked': userData['isBlocked'] ?? false,
      'employeeId': userData['employeeId'] ?? _generateEmployeeId(role),
      'shift': userData['shift'] ?? 'morning',
      'createdAt': userData['createdAt'],
      'updatedAt': userData['updatedAt'] ?? FieldValue.serverTimestamp(),
      'activeOrders': userData['activeOrders'] ?? 0,
      'completedOrders': userData['completedOrders'] ?? 0,
      'rating': userData['rating'] ?? 5.0,
    };

    switch (role) {
      case 'delivery':
        return {
          ...common,
          'isOnline': userData['isOnline'] ?? false,
          'vehicleType': userData['vehicleType'] ?? 'bike',
          'vehicleNumber': userData['vehicleNumber'] ?? '',
          'totalDeliveries': userData['totalDeliveries'] ?? 0,
          'totalEarnings': userData['totalEarnings'] ?? 0.0,
          'pendingEarnings': userData['pendingEarnings'] ?? 0.0,
        };

      case 'manager':
        return {
          ...common,
          'branchId': userData['branchId'] ?? '',
          'managedStaffCount': userData['managedStaffCount'] ?? 0,
        };

      case 'staff':
        return {
          ...common,
          'department': userData['department'] ?? 'general',
          'employeeId': userData['employeeId'] ?? _generateEmployeeId('staff'),
        };

      default:
        return common;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 5.  UTILITIES
  // ─────────────────────────────────────────────────────────────

  String _generateEmployeeId(String role) {
    final prefix = role == 'delivery'
        ? 'DLV'
        : role == 'manager'
            ? 'MGR'
            : 'STF';
    return '$prefix${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  /// Shows a role-picker dialog when a user has multiple roles.
  Future<String?> showRoleSelectionDialog(BuildContext context) async {
    final routes = await getUserAccessibleRoles();
    if (routes.length == 1) return routes.first;

    // Guard against stale context after async gap
    if (!context.mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose your role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: routes
              .map((r) => ListTile(
                    title: Text(_labelForRoute(r)),
                    onTap: () => Navigator.pop(ctx, r),
                  ))
              .toList(),
        ),
      ),
    );
  }

  String _labelForRoute(String route) {
    switch (route) {
      case '/admin-dashboard':
        return 'Admin';
      case '/manager-dashboard':
        return 'Manager';
      case '/delivery-dashboard':
        return 'Delivery Agent';
      case '/employee-dashboard':
        return 'Staff';
      default:
        return 'Customer';
    }
  }
}
