import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'role_based_auth_service.dart'
    show RoleBasedAuthService, isHardcodedAdmin, kAdminAllRoutes;
import 'notification_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final RoleBasedAuthService _roleService = RoleBasedAuthService();

  // Lazy-init: never instantiated on Web (would crash with missing clientId)
  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn {
    _googleSignInInstance ??= GoogleSignIn();
    return _googleSignInInstance!;
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get _isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  // ── WEB: signInWithPopup (no google_sign_in package needed) ───
  Future<Map<String, dynamic>> signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});
    try {
      final cred = await _auth.signInWithPopup(provider);
      if (cred.user == null) return {'success': false, 'error': 'Sign in failed'};
      return _buildGoogleSuccessResult(cred.user!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request' ||
          e.code == 'web-context-cancelled') {
        return {'success': false, 'error': 'Sign in cancelled'};
      }
      return {'success': false, 'error': e.message ?? 'Google sign-in failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── MOBILE: standard GoogleSignIn package ─────────────────────
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Always sign out first so the account picker is shown on every sign-in
      // (prevents silent re-auth after the user explicitly logs out)
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return {'success': false, 'error': 'Sign in cancelled'};
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) return _buildGoogleSuccessResult(userCredential.user!);
      return {'success': false, 'error': 'Failed to sign in'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── DESKTOP: signInWithProvider (opens browser window) ────────
  Future<Map<String, dynamic>> signInWithGoogleDesktop() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});
    try {
      final cred = await _auth.signInWithProvider(provider);
      if (cred.user == null) return {'success': false, 'error': 'Failed to sign in'};
      return _buildGoogleSuccessResult(cred.user!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'web-context-already-presented') {
        try {
          await Future.delayed(const Duration(milliseconds: 250));
          final retry = await _auth.signInWithProvider(provider);
          if (retry.user == null) return {'success': false, 'error': 'Failed to sign in'};
          return _buildGoogleSuccessResult(retry.user!);
        } catch (re) {
          return {'success': false, 'error': re.toString()};
        }
      }
      return {'success': false, 'error': _mapDesktopGoogleError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _buildGoogleSuccessResult(User user) async {
    final existingDoc = await _db.collection('users').doc(user.uid).get();
    final isNewUser = !existingDoc.exists;
    final email = user.email ?? '';

    // ── Super-admin hardcoded emails — always get all 5 dashboards ──────────
    if (isHardcodedAdmin(email)) {
      // Ensure the user doc exists in Firestore with role='admin'
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': email,
        'photoURL': user.photoURL,
        'role': 'admin',
        'isBlocked': false,
        'isActive': true,
        'authMethod': 'google',
        'emailVerified': user.emailVerified,
        'lastSignIn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return {
        'success': true,
        'user': user,
        'route': '/admin-dashboard',
        'isNewUser': isNewUser,
        'accessibleRoles': List<String>.from(kAdminAllRoutes),
        'hasMultipleRoles': true, // always show dashboard picker
      };
    }

    // ── Is this an employee signing in? ────────────────────────────────
    // Employees are pre-registered in managers/delivery_agents/staff.
    // If their email matches, route them directly — NEVER write to /users.
    // /users is exclusively for customers (role='user').
    String? employeeRole;
    if (email.isNotEmpty) {
      const roleMap = {
        'manager': 'managers',
        'delivery': 'delivery_agents',
        'staff': 'staff',
      };
      for (final entry in roleMap.entries) {
        try {
          final q = await _db
              .collection(entry.value)
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            employeeRole = entry.key;
            final roleDoc = q.docs.first;
            if (roleDoc.id != user.uid) {
              // Migrate placeholder → real uid
              final data = Map<String, dynamic>.from(roleDoc.data());
              await _db.collection(entry.value).doc(user.uid).set({
                ...data,
                'uid': user.uid,
                'photoURL': user.photoURL ?? '',
                'emailVerified': user.emailVerified,
                'lastSignIn': FieldValue.serverTimestamp(),
                'syncedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              await roleDoc.reference.delete();
            } else {
              await _db.collection(entry.value).doc(user.uid).update({
                'lastSignIn': FieldValue.serverTimestamp(),
                'photoURL': user.photoURL ?? '',
              });
            }
            break;
          }
        } catch (_) {}
      }
    }

    if (employeeRole != null) {
      // Employee → route to correct dashboard, skip /users entirely
      final route = _routeForRole(employeeRole);
      return {
        'success': true,
        'user': user,
        'route': route,
        'isNewUser': isNewUser,
        'accessibleRoles': [route],
        'hasMultipleRoles': false,
      };
    }

    // ── Customer path ─────────────────────────────────────────────────
    // Only customers land in /users with role='user'
    await _createOrUpdateGoogleUser(user);
    final accessibleRoles = await _roleService.getUserAccessibleRoles();
    final route = await _roleService.getDashboardRoute();
    return {
      'success': true,
      'user': user,
      'route': route,
      'isNewUser': isNewUser,
      'accessibleRoles': accessibleRoles,
      'hasMultipleRoles': accessibleRoles.length > 1,
    };
  }

  String _routeForRole(String role) {
    switch (role) {
      case 'admin':    return '/admin-dashboard';
      case 'manager':  return '/manager-dashboard';
      case 'delivery': return '/delivery-dashboard';
      case 'staff':    return '/employee-dashboard';
      default:         return '/dashboard';
    }
  }

  String _mapDesktopGoogleError(FirebaseAuthException e) {
    if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') return 'Sign in cancelled';
    if (e.code == 'operation-not-allowed') return 'Google sign-in is disabled in Firebase Console.';
    if (e.code == 'unauthorized-domain') return 'Domain not authorized. Add it in Firebase Console > Authentication > Authorized domains.';
    if (e.code == 'network-request-failed') return 'Network error. Check your connection and try again.';
    return e.message ?? 'Google sign-in failed';
  }

  // Called ONLY for customers (employees are handled before this is reached).
  // This always writes role='user' — employees never reach this method.
  Future<void> _createOrUpdateGoogleUser(User user) async {
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'phoneVerified': false,
          'emailVerified': user.emailVerified,
          'photoUrl': user.photoURL ?? '',
          'photoURL': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'authMethod': 'google',
          'role': 'user',         // /users = customers only, always
          'isBlocked': false,
          'isActive': true,
          'loyaltyPoints': 0,
          'totalOrders': 0,
          'totalSpent': 0.0,
        });
        // Welcome notification
        try {
          await _db.collection('notifications').add({
            'userId': user.uid,
            'title': '👋 Welcome to Laundrify!',
            'body': 'Fresh, clean laundry is just a tap away. Explore our services and place your first order today!',
            'type': 'welcome',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      } else {
        // Existing customer — update display fields only, never change role
        await _db.collection('users').doc(user.uid).update({
          'name': user.displayName ?? doc.data()?['name'] ?? '',
          'photoUrl': user.photoURL ?? doc.data()?['photoUrl'] ?? '',
          'photoURL': user.photoURL ?? doc.data()?['photoURL'] ?? '',
          'emailVerified': user.emailVerified,
          'lastSignIn': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error creating/updating Google user: $e');
    }
  }

  Future<User?> signUpWithEmail({required String email, required String password, required String name}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.sendEmailVerification();
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid, 'name': name, 'email': email, 'phone': '',
          'phoneVerified': false, 'emailVerified': false,
          'createdAt': FieldValue.serverTimestamp(), 'authMethod': 'email',
          'role': 'user',
        });
        // Send welcome notification
        try {
          await _db.collection('notifications').add({
            'userId': user.uid,
            'title': '👋 Welcome to Laundrify!',
            'body': 'Fresh, clean laundry is just a tap away. Explore our services and place your first order today!',
            'type': 'welcome',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
      return user;
    } catch (e) { rethrow; }
  }

  Future<User?> signInWithEmail({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return credential.user;
    } catch (e) { rethrow; }
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
    required Function(User) onAutoVerify,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential cred) async {
          final uc = await _auth.signInWithCredential(cred);
          if (uc.user != null) { await _createOrUpdatePhoneUser(uc.user!); onAutoVerify(uc.user!); }
        },
        verificationFailed: (FirebaseAuthException e) => onError(e.message ?? 'Verification failed'),
        codeSent: (String id, int? _) => onCodeSent(id),
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) { onError(e.toString()); }
  }

  Future<User?> verifyOTP({required String verificationId, required String otp}) async {
    try {
      final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: otp);
      final uc = await _auth.signInWithCredential(credential);
      if (uc.user != null) await _createOrUpdatePhoneUser(uc.user!);
      return uc.user;
    } catch (e) { rethrow; }
  }

  Future<void> _createOrUpdatePhoneUser(User user) async {
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid, 'name': user.displayName ?? '', 'email': user.email ?? '',
          'phone': user.phoneNumber ?? '', 'phoneVerified': true, 'emailVerified': false,
          'createdAt': FieldValue.serverTimestamp(), 'authMethod': 'phone',
          'role': 'user',
        });
      } else {
        await _db.collection('users').doc(user.uid).update(
            {'phone': user.phoneNumber ?? '', 'phoneVerified': true, 'updatedAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {}
  }

  Future<void> signOut() async {
    try {
      final notifService = NotificationService();
      // unsubscribeAllTopics removed - token cleanup handled by deleteToken()
      await notifService.deleteToken();
    } catch (_) {}
    await _auth.signOut();
    if (!kIsWeb && !_isDesktop) {
      try { await _googleSignIn.signOut(); } catch (_) {}
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try { await _auth.sendPasswordResetEmail(email: email); } catch (e) { rethrow; }
  }

  Future<void> updateUserProfile({String? name, String? photoUrl}) async {
    final user = currentUser;
    if (user == null) return;
    try {
      if (name != null) { await user.updateDisplayName(name); await _db.collection('users').doc(user.uid).update({'name': name}); }
      if (photoUrl != null) { await user.updatePhotoURL(photoUrl); await _db.collection('users').doc(user.uid).update({'photoUrl': photoUrl}); }
    } catch (e) { rethrow; }
  }

  Future<void> reloadUser() async { await currentUser?.reload(); }
}
