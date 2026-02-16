import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get userId => _auth.currentUser?.uid;
  String? get _uid => _auth.currentUser?.uid;

  // ── User Profile Methods ────────────────────────────────────────────────

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (userId == null) return null;
      
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    try {
      if (userId == null) throw Exception('No user logged in');
      
      await _db.collection('users').doc(userId).set(
        data,
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  // ── Location Methods ────────────────────────────────────────────────────

  /// Save user location (home, office, or other)
  Future<void> saveUserLocation({
    required String addressLabel, // 'Home', 'Office', 'Other'
    required String address,
    required double latitude,
    required double longitude,
    String? apartment,
    String? landmark,
  }) async {
    try {
      if (userId == null) throw Exception('No user logged in');

      final locationData = {
        'addressLabel': addressLabel,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'apartment': apartment,
        'landmark': landmark,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('users').doc(userId).set({
        'location': locationData,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving location: $e');
      rethrow;
    }
  }

  /// Get saved addresses (home, office, other)
  Future<Map<String, Map<String, dynamic>>> getSavedAddresses() async {
    try {
      if (userId == null) return {};

      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['savedAddresses'] != null) {
          return Map<String, Map<String, dynamic>>.from(
            data['savedAddresses'],
          );
        }
      }
      return {};
    } catch (e) {
      debugPrint('Error getting saved addresses: $e');
      return {};
    }
  }

  /// Save multiple addresses (home, office, other)
  Future<void> saveAddresses({
    Map<String, dynamic>? home,
    Map<String, dynamic>? office,
    Map<String, dynamic>? other,
  }) async {
    try {
      if (userId == null) throw Exception('No user logged in');

      final addresses = <String, dynamic>{};
      
      if (home != null) addresses['home'] = home;
      if (office != null) addresses['office'] = office;
      if (other != null) addresses['other'] = other;

      await _db.collection('users').doc(userId).set({
        'savedAddresses': addresses,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving addresses: $e');
      rethrow;
    }
  }

  // ── Settings Methods ────────────────────────────────────────────────────

  /// Update user settings
  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    try {
      if (userId == null) throw Exception('No user logged in');

      await _db.collection('users').doc(userId).set({
        'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating settings: $e');
      rethrow;
    }
  }

  /// Get user settings
  Future<Map<String, dynamic>?> getUserSettings() async {
    try {
      if (userId == null) return null;

      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['settings'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting settings: $e');
      return null;
    }
  }

  // ── Coupon Methods ──────────────────────────────────────────────────────

  /// Get user coupons
  Future<List<Map<String, dynamic>>> getUserCoupons() async {
    try {
      if (userId == null) return [];

      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('coupons')
          .orderBy('validUntil', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        // Convert Timestamp to DateTime
        if (data['validUntil'] is Timestamp) {
          data['validUntil'] = (data['validUntil'] as Timestamp).toDate();
        }
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting coupons: $e');
      return [];
    }
  }

  /// Add a coupon to user's account
  Future<void> addCoupon(Map<String, dynamic> couponData) async {
    try {
      if (userId == null) throw Exception('No user logged in');

      final couponId = couponData['id'] ?? couponData['code'];
      
      await _db
          .collection('users')
          .doc(userId)
          .collection('coupons')
          .doc(couponId)
          .set({
        ...couponData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding coupon: $e');
      rethrow;
    }
  }

  /// Mark coupon as used
  Future<void> useCoupon(String couponId) async {
    try {
      if (userId == null) throw Exception('No user logged in');

      await _db
          .collection('users')
          .doc(userId)
          .collection('coupons')
          .doc(couponId)
          .update({
        'status': 'used',
        'usedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error using coupon: $e');
      rethrow;
    }
  }

  // ── Order Methods ───────────────────────────────────────────────────────

  /// Create a new order
  Future<String> createOrder(Map<String, dynamic> orderData) async {
    try {
      if (userId == null) throw Exception('No user logged in');

      final docRef = await _db.collection('orders').add({
        'userId': userId,
        ...orderData,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  /// Get user orders
  Future<List<Map<String, dynamic>>> getUserOrders() async {
    try {
      if (userId == null) return [];

      final querySnapshot = await _db
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Convert Timestamp to DateTime
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
        }
        if (data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate();
        }
        
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting orders: $e');
      return [];
    }
  }

  /// Get specific order by ID
  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          data['id'] = doc.id;
          
          // Convert Timestamp to DateTime
          if (data['createdAt'] is Timestamp) {
            data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
          }
          if (data['date'] is Timestamp) {
            data['date'] = (data['date'] as Timestamp).toDate();
          }
          
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting order: $e');
      return null;
    }
  }

  // ── Notification Methods ────────────────────────────────────────────────

  /// Get user notifications
  Future<List<Map<String, dynamic>>> getUserNotifications() async {
    try {
      if (userId == null) return [];

      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Convert Timestamp to DateTime
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
        }
        
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      if (userId == null) throw Exception('No user logged in');

      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  // ── Account Deletion ────────────────────────────────────────────────────

  /// Delete all user data from Firestore
  Future<void> deleteUserData(String uid) async {
    try {
      // Delete user document
      await _db.collection('users').doc(uid).delete();

      // Delete user's orders
      final ordersSnapshot = await _db
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .get();
      
      for (var doc in ordersSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete subcollections (coupons, notifications, etc.)
      final couponsSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('coupons')
          .get();
      
      for (var doc in couponsSnapshot.docs) {
        await doc.reference.delete();
      }

      final notificationsSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .get();
      
      for (var doc in notificationsSnapshot.docs) {
        await doc.reference.delete();
      }

      debugPrint('User data deleted successfully');
    } catch (e) {
      debugPrint('Error deleting user data: $e');
      rethrow;
    }
  }

  // ── Helper Methods ──────────────────────────────────────────────────────

  /// Check if user exists in Firestore
  Future<bool> userExists() async {
    try {
      if (userId == null) return false;
      
      final doc = await _db.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking if user exists: $e');
      return false;
    }
  }

  /// Create initial user document
  Future<void> createUserDocument({
    required String email,
    String? displayName,
    String? photoURL,
    String? phoneNumber,
  }) async {
    try {
      if (userId == null) throw Exception('No user logged in');

      final exists = await userExists();
      if (exists) return; // User document already exists

      await _db.collection('users').doc(userId).set({
        'email': email,
        'displayName': displayName,
        'photoURL': photoURL,
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'settings': {
          'pushNotifications': true,
          'emailNotifications': true,
          'smsNotifications': false,
          'orderUpdates': true,
          'promotionalEmails': true,
          'darkMode': false,
        },
      });
    } catch (e) {
      debugPrint('Error creating user document: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // ORDERS (Additional methods from provided service)
  // ──────────────────────────────────────────────────────────────

  /// Save a completed order to Firestore
  Future<void> saveOrder(Map<String, dynamic> orderData) async {
    if (_uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(_uid)
          .collection('orders')
          .doc(orderData['orderId'] as String)
          .set({
        ...orderData,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': _uid,
        'status': 'pending', // pending, pickup, processing, delivery, completed
      });
    } catch (e) {
      // ignore silently — app still works offline
    }
  }

  /// Stream of user's orders (newest first)
  Stream<List<Map<String, dynamic>>> ordersStream() {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(_uid)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// One-time fetch of all orders
  Future<List<Map<String, dynamic>>> getOrders() async {
    if (_uid == null) return [];
    try {
      final snap = await _db
          .collection('users')
          .doc(_uid)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Update order status (with automatic notifications)
  Future<void> updateOrderStatus(String orderId, String status) async {
    if (_uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(_uid)
          .collection('orders')
          .doc(orderId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send appropriate notification based on status
      if (status == 'pickup') {
        await sendPickupNotification(orderId);
      } else if (status == 'processing') {
        await sendProcessingNotification(orderId);
      } else if (status == 'delivery') {
        await sendDeliveryNotification(orderId);
      } else if (status == 'completed') {
        await sendCompletionNotification(orderId);
      }
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────
  // USER PROFILE / ADDRESS (Additional methods)
  // ──────────────────────────────────────────────────────────────

  /// Save or update user profile data
  Future<void> saveUserProfile(Map<String, dynamic> data) async {
    if (_uid == null) return;
    try {
      await _db.collection('users').doc(_uid).set(
        {...data, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  /// Stream user profile for real-time updates
  Stream<Map<String, dynamic>?> userProfileStream() {
    if (_uid == null) return const Stream.empty();
    return _db.collection('users').doc(_uid).snapshots().map(
          (snap) => snap.exists ? snap.data() : null,
        );
  }

  /// Save address to user's addresses sub-collection
  Future<void> saveAddress(Map<String, dynamic> addressData) async {
    if (_uid == null) return;
    try {
      final label = (addressData['label'] as String?) ?? 'Home';
      await _db
          .collection('users')
          .doc(_uid)
          .collection('addresses')
          .doc(label)
          .set({
        ...addressData,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Get all saved addresses
  Future<List<Map<String, dynamic>>> getAddresses() async {
    if (_uid == null) return [];
    try {
      final snap =
          await _db.collection('users').doc(_uid).collection('addresses').get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // NOTIFICATIONS (New system from provided service)
  // ──────────────────────────────────────────────────────────────

  /// Add a notification (enforces max 10/day limit)
  Future<void> addNotification(Map<String, dynamic> notif) async {
    if (_uid == null) return;
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Count today's notifications
      final todaySnap = await _db
          .collection('users')
          .doc(_uid)
          .collection('notifications')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .count()
          .get();

      if ((todaySnap.count ?? 0) >= 10) return; // Enforce 10/day limit

      await _db.collection('users').doc(_uid).collection('notifications').add({
        ...notif,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Stream of user's notifications (newest first)
  Stream<List<Map<String, dynamic>>> notificationsStream() {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Mark notification as read
  Future<void> markNotificationRead(String notifId) async {
    if (_uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(_uid)
          .collection('notifications')
          .doc(notifId)
          .update({'isRead': true});
    } catch (_) {}
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsRead() async {
    if (_uid == null) return;
    try {
      final snap = await _db
          .collection('users')
          .doc(_uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────
  // PUSH NOTIFICATION QUEUE
  // ──────────────────────────────────────────────────────────────

  /// Queue a push notification to be sent by Cloud Function
  Future<void> _queuePushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _db.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        debugPrint('No FCM token found for user: $userId');
        return;
      }

      // Queue notification for Cloud Function to send
      await _db.collection('push_queue').add({
        'token': fcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data ?? {},
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Push notification queued for: $title');
    } catch (e) {
      debugPrint('Error queuing push notification: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // TRIGGER SYSTEM NOTIFICATIONS
  // ──────────────────────────────────────────────────────────────

  Future<void> sendAccountCreatedNotification() async {
    if (_uid == null) return;

    await addNotification({
      'title': 'Welcome to Laundrify! 🎉',
      'message':
          'Your account has been created successfully. Enjoy premium laundry services!',
      'type': 'account_created',
      'icon': 'person_add',
      'color': '0xFF10B981',
    });

    // Send push notification
    await _queuePushNotification(
      userId: _uid!,
      title: 'Welcome to Laundrify! 🎉',
      body:
          'Your account has been created successfully. Enjoy premium laundry services!',
      data: {'type': 'account_created'},
    );
  }

  Future<void> sendLoginNotification(String name) async {
    if (_uid == null) return;

    await addNotification({
      'title': 'Welcome back, $name! 👋',
      'message':
          'You have successfully logged in to Laundrify. Great to see you again!',
      'type': 'login',
      'icon': 'login',
      'color': '0xFF1B4FD8',
    });

    // Send push notification
    await _queuePushNotification(
      userId: _uid!,
      title: 'Welcome back, $name! 👋',
      body: 'You have successfully logged in to Laundrify.',
      data: {'type': 'login'},
    );
  }

  Future<void> sendBookingSuccessNotification(
      String orderId, double total) async {
    if (_uid == null) return;

    await addNotification({
      'title': 'Booking Confirmed! ✅',
      'message':
          'Your order #$orderId has been placed successfully. Total: ₹${total.toStringAsFixed(0)}',
      'type': 'booking_success',
      'icon': 'check_circle',
      'color': '0xFF10B981',
      'orderId': orderId,
    });

    // Send push notification
    await _queuePushNotification(
      userId: _uid!,
      title: 'Booking Confirmed! ✅',
      body:
          'Your order #$orderId has been placed successfully. Total: ₹${total.toStringAsFixed(0)}',
      data: {
        'type': 'booking_success',
        'orderId': orderId,
      },
    );
  }

  Future<void> sendPickupNotification(String orderId) async {
    if (_uid == null) return;

    await addNotification({
      'title': 'Pickup Scheduled 🛵',
      'message':
          'Our agent is on the way to pick up your items for order #$orderId.',
      'type': 'pickup',
      'icon': 'directions_bike',
      'color': '0xFF3B82F6',
      'orderId': orderId,
    });

    // Send push notification
    await _queuePushNotification(
      userId: _uid!,
      title: 'Pickup Scheduled 🛵',
      body:
          'Our agent is on the way to pick up your items for order #$orderId.',
      data: {
        'type': 'pickup',
        'orderId': orderId,
      },
    );
  }

  Future<void> sendProcessingNotification(String orderId) async {
    if (_uid == null) return;

    await addNotification({
      'title': 'Order in Processing 🧺',
      'message':
          'Your items for order #$orderId are being carefully cleaned by our experts.',
      'type': 'processing',
      'icon': 'local_laundry_service',
      'color': '0xFFF59E0B',
      'orderId': orderId,
    });

    // Send push notification
    await _queuePushNotification(
      userId: _uid!,
      title: 'Order in Processing 🧺',
      body: 'Your items for order #$orderId are being carefully cleaned.',
      data: {
        'type': 'processing',
        'orderId': orderId,
      },
    );
  }

  Future<void> sendDeliveryNotification(String orderId) async {
    if (_uid == null) return;

    await addNotification({
      'title': 'Out for Delivery 🚚',
      'message':
          'Your freshly cleaned items for order #$orderId are on their way. Get ready!',
      'type': 'delivery',
      'icon': 'delivery_dining',
      'color': '0xFF10B981',
      'orderId': orderId,
    });

    // Send push notification
    await _queuePushNotification(
      userId: _uid!,
      title: 'Out for Delivery 🚚',
      body: 'Your freshly cleaned items for order #$orderId are on their way!',
      data: {
        'type': 'delivery',
        'orderId': orderId,
      },
    );
  }

  Future<void> sendCompletionNotification(String orderId) async {
    if (_uid == null) return;

    await addNotification({
      'title': 'Order Completed! 🎊',
      'message':
          'Your order #$orderId has been delivered successfully. Thank you for choosing Laundrify!',
      'type': 'completed',
      'icon': 'celebration',
      'color': '0xFF10B981',
      'orderId': orderId,
    });

    // Send push notification
    await _queuePushNotification(
      userId: _uid!,
      title: 'Order Completed! 🎊',
      body: 'Your order #$orderId has been delivered successfully. Thank you!',
      data: {
        'type': 'completed',
        'orderId': orderId,
      },
    );
  }
}
