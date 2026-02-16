import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'role_based_auth_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final RoleBasedAuthService _roleService = RoleBasedAuthService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ──────────────────────────────────────────────────────────────
  // GOOGLE AUTH
  // ──────────────────────────────────────────────────────────────

  /// Sign in with Google and route to appropriate dashboard
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Trigger Google Sign In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return {'success': false, 'error': 'Sign in cancelled'};
      }

      // Obtain auth details from request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credentials
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Create or update user document
        await _createOrUpdateGoogleUser(user);

        // Get accessible roles and dashboard route
        final accessibleRoles = await _roleService.getUserAccessibleRoles();
        final route = await _roleService.getDashboardRoute();

        return {
          'success': true,
          'user': user,
          'route': route,
          'accessibleRoles': accessibleRoles,
          'hasMultipleRoles': accessibleRoles.length > 1,
        };
      }

      return {'success': false, 'error': 'Failed to sign in'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create or update Google user document in Firestore
  Future<void> _createOrUpdateGoogleUser(User user) async {
    try {
      final doc = await _db.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        // New user - create document
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'phoneVerified': false,
          'emailVerified': user.emailVerified,
          'photoUrl': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'authMethod': 'google',
        });
      } else {
        // Existing user - update info
        await _db.collection('users').doc(user.uid).update({
          'name': user.displayName ?? doc.data()?['name'] ?? '',
          'photoUrl': user.photoURL ?? doc.data()?['photoUrl'] ?? '',
          'emailVerified': user.emailVerified,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Fail silently
      debugPrint('Error creating/updating Google user: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // EMAIL AUTH
  // ──────────────────────────────────────────────────────────────

  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.sendEmailVerification();

        // Create user document
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'phone': '',
          'phoneVerified': false,
          'emailVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'authMethod': 'email',
        });
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // PHONE AUTH
  // ──────────────────────────────────────────────────────────────

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(User user) onAutoVerify,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          final userCredential = await _auth.signInWithCredential(credential);
          if (userCredential.user != null) {
            await _createOrUpdatePhoneUser(userCredential.user!);
            onAutoVerify(userCredential.user!);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Timeout - no action needed
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<User?> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _createOrUpdatePhoneUser(userCredential.user!);
      }
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _createOrUpdatePhoneUser(User user) async {
    try {
      final doc = await _db.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        // New user - create document
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'phoneVerified': true,
          'emailVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'authMethod': 'phone',
        });
      } else {
        // Existing user - update phone
        await _db.collection('users').doc(user.uid).update({
          'phone': user.phoneNumber ?? '',
          'phoneVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Fail silently
    }
  }

  // ──────────────────────────────────────────────────────────────
  // COMMON AUTH
  // ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserProfile({String? name, String? photoUrl}) async {
    final user = currentUser;
    if (user == null) return;

    try {
      if (name != null) {
        await user.updateDisplayName(name);
        await _db.collection('users').doc(user.uid).update({'name': name});
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
        await _db
            .collection('users')
            .doc(user.uid)
            .update({'photoUrl': photoUrl});
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reloadUser() async {
    await currentUser?.reload();
  }
}
