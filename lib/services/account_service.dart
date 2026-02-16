import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AccountService {
  static final AccountService _instance = AccountService._internal();
  factory AccountService() => _instance;
  AccountService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  String? get userId => _auth.currentUser?.uid;

  /// Sign out from all services
  Future<void> signOut() async {
    try {
      // Sign out from Google if signed in with Google
      await _googleSignIn.signOut();
      
      // Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  /// Delete user account completely
  Future<Map<String, dynamic>> deleteAccount(BuildContext context) async {
    if (userId == null) {
      return {'success': false, 'error': 'No user logged in'};
    }

    try {
      // Show confirmation dialog
      final confirmed = await _showDeleteConfirmationDialog(context);
      if (!confirmed) {
        return {'success': false, 'error': 'Cancelled by user'};
      }

      // Get user reference
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'User not found'};
      }

      // Delete user data from Firestore
      await _deleteUserData(userId!);

      // Delete authentication account
      await user.delete();

      // Sign out from Google
      await _googleSignIn.signOut();

      return {'success': true, 'message': 'Account deleted successfully'};
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // User needs to re-authenticate
        return {
          'success': false,
          'error': 'Please sign in again before deleting your account',
          'requiresReauth': true,
        };
      }
      return {'success': false, 'error': e.message ?? 'Failed to delete account'};
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  /// Delete all user data from Firestore
  Future<void> _deleteUserData(String uid) async {
    try {
      final batch = _db.batch();

      // Delete user document
      batch.delete(_db.collection('users').doc(uid));

      // Delete user's orders
      final orders = await _db
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .get();
      
      for (var doc in orders.docs) {
        batch.delete(doc.reference);
      }

      // Delete user's addresses
      final addresses = await _db
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .get();
      
      for (var doc in addresses.docs) {
        batch.delete(doc.reference);
      }

      // Delete user's cart
      final cart = await _db
          .collection('users')
          .doc(uid)
          .collection('cart')
          .get();
      
      for (var doc in cart.docs) {
        batch.delete(doc.reference);
      }

      // Commit all deletions
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting user data: $e');
      throw Exception('Failed to delete user data');
    }
  }

  /// Show confirmation dialog before deleting account
  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'This action will:',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            _buildWarningItem('Permanently delete your account'),
            _buildWarningItem('Remove all your personal data'),
            _buildWarningItem('Cancel all pending orders'),
            _buildWarningItem('Delete your order history'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.close, color: Colors.red.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  /// Show sign out confirmation dialog
  static Future<bool> showSignOutDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F6FD8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Re-authenticate user (required before account deletion in some cases)
  Future<bool> reauthenticateUser(String email, String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      debugPrint('Error re-authenticating: $e');
      return false;
    }
  }

  /// Show re-authentication dialog
  static Future<String?> showReauthDialog(BuildContext context) async {
    final passwordController = TextEditingController();

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Password',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please enter your password to continue',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F6FD8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
