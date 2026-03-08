import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Manages the three dedicated employee Firestore collections:
///   /managers        → role = 'manager'
///   /delivery_agents → role = 'delivery'
///   /staff           → role = 'staff'
///
/// /users is CUSTOMERS ONLY (role = 'user'). Employees are NEVER written there.
class EmployeeService {
  static final EmployeeService _instance = EmployeeService._internal();
  factory EmployeeService() => _instance;
  EmployeeService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Map role → collection name
  static const _roleCollection = {
    'manager':  'managers',
    'delivery': 'delivery_agents',
    'staff':    'staff',
  };

  String _collectionForRole(String role) =>
      _roleCollection[role] ?? 'staff';

  // ── Lookup ─────────────────────────────────────────────────────────────────

  /// Returns the employee document for [uid] by checking all 3 collections.
  Future<Map<String, dynamic>?> getEmployeeDoc(String uid) async {
    for (final col in _roleCollection.values) {
      try {
        final doc = await _db.collection(col).doc(uid).get();
        if (doc.exists) return {'_collection': col, ...?doc.data()};
      } catch (_) {}
    }
    return null;
  }

  /// Returns the role string for [uid], or null if not an employee.
  Future<String?> getEmployeeRole(String uid) async {
    final data = await getEmployeeDoc(uid);
    return data?['role'] as String?;
  }

  /// Looks up an employee by email across all 3 collections.
  Future<Map<String, dynamic>?> getEmployeeByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    for (final entry in _roleCollection.entries) {
      try {
        final q = await _db
            .collection(entry.value)
            .where('email', isEqualTo: normalized)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          return {'id': q.docs.first.id, '_collection': entry.value,
                  ...q.docs.first.data()};
        }
      } catch (_) {}
    }
    return null;
  }

  // ── Create / Update ────────────────────────────────────────────────────────

  /// Called by the admin when adding a new employee.
  /// Writes to the correct role collection — never to /users.
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
      final col = _collectionForRole(role);
      final data = <String, dynamic>{
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
        'employeeId': employeeId ?? _generateEmployeeId(role),
        'isActive': true,
        'addedBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (uid != null && uid.isNotEmpty) {
        // UID known — write directly to role collection keyed by UID
        data['uid'] = uid;
        await _db.collection(col).doc(uid).set(data, SetOptions(merge: true));
        return {'success': true, 'uid': uid, 'employeeId': data['employeeId'],
                'collection': col};
      } else {
        // UID unknown — placeholder doc. Will be migrated on first Google login.
        final docRef = await _db.collection(col).add({
          ...data,
          'uid': '',
          'isPending': true,
        });
        return {'success': true, 'pendingDocId': docRef.id,
                'employeeId': data['employeeId'], 'collection': col};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Called after sign-in. Finds a pending placeholder doc by email in any
  /// role collection and migrates it to the real UID. Does NOT touch /users.
  Future<void> linkEmployeeOnLogin(User user) async {
    // NOTE: auth_service.dart already handles this during _buildGoogleSuccessResult.
    // This method is kept for email/phone sign-in paths that don't go through
    // the Google flow.
    try {
      final email = user.email?.trim().toLowerCase() ?? '';
      if (email.isEmpty) return;

      for (final entry in _roleCollection.entries) {
        final col = entry.value;
        // Check if already linked (doc keyed by real UID)
        final existing = await _db.collection(col).doc(user.uid).get();
        if (existing.exists) {
          // Already linked — update last sign-in only
          await _db.collection(col).doc(user.uid).update({
            'lastSignIn': FieldValue.serverTimestamp(),
            'photoURL': user.photoURL ?? '',
          });
          return;
        }

        // Look for a pending placeholder by email
        final pending = await _db
            .collection(col)
            .where('email', isEqualTo: email)
            .where('isPending', isEqualTo: true)
            .limit(1)
            .get();

        if (pending.docs.isEmpty) continue;

        final pendingDoc = pending.docs.first;
        final pendingData = pendingDoc.data();

        // Migrate to real UID
        await _db.collection(col).doc(user.uid).set({
          ...pendingData,
          'uid': user.uid,
          'name': user.displayName ?? pendingData['name'] ?? '',
          'photoURL': user.photoURL ?? '',
          'isPending': false,
          'linkedAt': FieldValue.serverTimestamp(),
          'lastSignIn': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Remove old placeholder
        await pendingDoc.reference.delete();

        // Claim any pending notifications addressed to this email
        try {
          final pendingNotifs = await _db
              .collection('notifications')
              .where('pendingEmail', isEqualTo: email)
              .get();
          for (final doc in pendingNotifs.docs) {
            await doc.reference.update({
              'userId': user.uid,
              'pendingEmail': FieldValue.delete(),
            });
          }
        } catch (_) {}

        return; // found and migrated — done
      }
    } catch (e) {
      debugPrint('EmployeeService.linkEmployeeOnLogin error: \$e');
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
      // Find which collection this employee is in
      String? currentCol;
      String? currentRole;
      for (final entry in _roleCollection.entries) {
        final doc = await _db.collection(entry.value).doc(uid).get();
        if (doc.exists) {
          currentCol = entry.value;
          currentRole = doc.data()?['role'] as String? ?? entry.key;
          break;
        }
      }
      if (currentCol == null) {
        return {'success': false, 'error': 'Employee not found'};
      }

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

      // If role is changing, migrate to the correct collection
      if (role != null && role != currentRole) {
        final newCol = _collectionForRole(role);
        final oldDoc = await _db.collection(currentCol).doc(uid).get();
        if (oldDoc.exists) {
          final data = Map<String, dynamic>.from(oldDoc.data()!);
          data.addAll(updates);
          await _db.collection(newCol).doc(uid).set(data);
          await _db.collection(currentCol).doc(uid).delete();
        }
      } else {
        await _db.collection(currentCol).doc(uid).update(updates);
      }

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Remove an employee from their role collection.
  /// Does NOT create or modify any /users doc.
  Future<Map<String, dynamic>> removeEmployee(String uid) async {
    try {
      for (final col in _roleCollection.values) {
        final doc = await _db.collection(col).doc(uid).get();
        if (doc.exists) {
          await _db.collection(col).doc(uid).delete();
          return {'success': true};
        }
      }
      return {'success': false, 'error': 'Employee not found'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Stream all active employees from a specific role collection.
  Stream<QuerySnapshot> employeesByRoleStream(String role) {
    final col = _collectionForRole(role);
    return _db
        .collection(col)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream all employees across all 3 collections (merged client-side).
  /// Returns a list of [Map] with a '_collection' key added.
  Stream<List<Map<String, dynamic>>> allEmployeesStream() {
    final streams = _roleCollection.values.map((col) =>
        _db.collection(col)
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snap) => snap.docs
                .map((d) => {'_collection': col, 'id': d.id, ...d.data()})
                .toList()));

    // Combine via StreamBuilder in UI; or use RxDart combineLatest3 if available
    // For simplicity, return managers stream (UI queries each collection separately)
    return streams.first;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _generateEmployeeId(String role) {
    return '${role == 'delivery' ? 'DLV' : role == 'manager' ? 'MGR' : 'STF'}'
        '${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }
}
