import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Manages the dedicated /employees Firestore collection.
///
/// WHY a separate collection?
/// When an employee signs in with Google for the first time,
/// [AuthService._createOrUpdateGoogleUser] creates a /users doc with role='user'.
/// The /employees collection is written by admins BEFORE the employee logs in,
/// so on login [RoleBasedAuthService.getUserRole] can look here first and find
/// the correct role immediately — without waiting for the /users doc to be
/// manually patched.
class EmployeeService {
  static final EmployeeService _instance = EmployeeService._internal();
  factory EmployeeService() => _instance;
  EmployeeService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Lookup ────────────────────────────────────────────────────────────────

  /// Returns the employee document for [uid], or null if not an employee.
  Future<Map<String, dynamic>?> getEmployeeDoc(String uid) async {
    try {
      final doc = await _db.collection('employees').doc(uid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('EmployeeService.getEmployeeDoc error: $e');
      return null;
    }
  }

  /// Checks whether a Firestore UID exists in /employees and returns their role
  /// string (e.g. 'delivery', 'staff', 'manager', 'admin'), or null if absent.
  Future<String?> getEmployeeRole(String uid) async {
    final data = await getEmployeeDoc(uid);
    return data?['role'] as String?;
  }

  /// Looks up an employee by email (used when the employee hasn't signed in
  /// yet and we don't have their UID).
  Future<Map<String, dynamic>?> getEmployeeByEmail(String email) async {
    try {
      final snap = await _db
          .collection('employees')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return {'id': snap.docs.first.id, ...snap.docs.first.data()};
    } catch (e) {
      debugPrint('EmployeeService.getEmployeeByEmail error: $e');
      return null;
    }
  }

  // ── Create / Update ───────────────────────────────────────────────────────

  /// Called by the admin when adding a new employee.
  ///
  /// If the employee has already signed in (their UID is known), pass [uid].
  /// If they haven't signed in yet, pass null and [email] — the record will be
  /// linked when they first log in via [linkEmployeeOnLogin].
  Future<Map<String, dynamic>> addEmployee({
    String? uid,
    required String email,
    required String name,
    required String role,
    String? phone,
    String? gender,
    String? shift,
    String? dateOfBirth,
    String? address,
    String? emergencyContact,
    String? employeeId,
  }) async {
    try {
      final adminUid = _auth.currentUser?.uid ?? '';
      final data = {
        'email': email.trim().toLowerCase(),
        'name': name.trim(),
        'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (shift != null && shift.isNotEmpty) 'shift': shift.toLowerCase(),
        if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth.trim(),
        if (address != null && address.isNotEmpty) 'address': address.trim(),
        if (emergencyContact != null && emergencyContact.isNotEmpty)
          'emergencyContact': emergencyContact.trim(),
        'employeeId': employeeId ?? _generateEmployeeId(),
        'isActive': true,
        'addedBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (uid != null && uid.isNotEmpty) {
        // UID known — write directly to /employees/{uid}
        data['uid'] = uid;
        await _db.collection('employees').doc(uid).set(data, SetOptions(merge: true));
        // Mirror role into /users/{uid} for backwards compatibility
        await _mirrorRoleToUsersCollection(uid, role);
        return {'success': true, 'uid': uid, 'employeeId': data['employeeId']};
      } else {
        // UID unknown — create a pending record keyed by a generated doc ID.
        // Will be re-keyed by UID on first login via [linkEmployeeOnLogin].
        final docRef = await _db.collection('employees').add({
          ...data,
          'uid': '', // empty until linked
          'isPending': true,
        });
        return {'success': true, 'pendingDocId': docRef.id, 'employeeId': data['employeeId']};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Call this right after Google/email sign-in for every login.
  /// If there is a pending /employees document for this user's email,
  /// it re-keys it to the real UID and mirrors the role to /users.
  Future<void> linkEmployeeOnLogin(User user) async {
    try {
      final email = user.email?.trim().toLowerCase() ?? '';
      if (email.isEmpty) return;

      // 1. Check if already linked (doc keyed by UID)
      final existing = await _db.collection('employees').doc(user.uid).get();
      if (existing.exists) {
        // Already linked — just ensure /users mirrors the role
        final role = existing.data()?['role'] as String?;
        if (role != null) await _mirrorRoleToUsersCollection(user.uid, role);
        return;
      }

      // 2. Look for pending record by email
      final pending = await _db
          .collection('employees')
          .where('email', isEqualTo: email)
          .where('isPending', isEqualTo: true)
          .limit(1)
          .get();

      if (pending.docs.isEmpty) return; // not an employee

      final pendingDoc = pending.docs.first;
      final pendingData = pendingDoc.data();
      final role = pendingData['role'] as String? ?? 'staff';

      // 3. Write the proper UID-keyed document
      await _db.collection('employees').doc(user.uid).set({
        ...pendingData,
        'uid': user.uid,
        'name': user.displayName ?? pendingData['name'] ?? '',
        'photoUrl': user.photoURL ?? '',
        'isPending': false,
        'linkedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Delete the old pending document
      await pendingDoc.reference.delete();

      // 5. Mirror role to /users so legacy queries still work
      await _mirrorRoleToUsersCollection(user.uid, role);
    } catch (e) {
      debugPrint('EmployeeService.linkEmployeeOnLogin error: $e');
    }
  }

  /// Update an existing employee record.
  Future<Map<String, dynamic>> updateEmployee(
    String uid, {
    String? name,
    String? role,
    String? phone,
    String? gender,
    String? shift,
    String? dateOfBirth,
    String? address,
    String? emergencyContact,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        if (name != null) 'name': name.trim(),
        if (role != null) 'role': role,
        if (phone != null) 'phone': phone.trim(),
        if (gender != null) 'gender': gender,
        if (shift != null) 'shift': shift.toLowerCase(),
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
        if (address != null) 'address': address.trim(),
        if (emergencyContact != null) 'emergencyContact': emergencyContact.trim(),
        if (isActive != null) 'isActive': isActive,
      };
      await _db.collection('employees').doc(uid).update(updates);

      // Mirror role change to /users
      if (role != null) await _mirrorRoleToUsersCollection(uid, role);

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Remove an employee — resets role to 'user' in both collections.
  Future<Map<String, dynamic>> removeEmployee(String uid) async {
    try {
      await _db.collection('employees').doc(uid).delete();
      await _mirrorRoleToUsersCollection(uid, 'user');
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Stream all active employees (all roles).
  Stream<QuerySnapshot> allEmployeesStream() {
    return _db
        .collection('employees')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream employees filtered by role.
  Stream<QuerySnapshot> employeesByRoleStream(String role) {
    return _db
        .collection('employees')
        .where('role', isEqualTo: role)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Keeps the legacy /users/{uid}.role field in sync so existing queries
  /// that read role from /users continue to work without modification.
  Future<void> _mirrorRoleToUsersCollection(String uid, String role) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        await _db.collection('users').doc(uid).update({
          'role': role,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('EmployeeService._mirrorRoleToUsersCollection error: $e');
    }
  }

  String _generateEmployeeId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return 'EMP${ts.substring(ts.length - 6)}';
  }
}
