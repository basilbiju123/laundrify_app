import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────────────────
  // USER PROFILE
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_uid == null) return null;
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('getUserProfile error: $e');
      return null;
    }
  }

  Stream<DocumentSnapshot> getUserProfileStream() {
    return _db.collection('users').doc(_uid).snapshots();
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // -----------------------------------------------------------------------------
  // SAVED ADDRESSES
  // -----------------------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> getSavedAddressesStream() {
    if (_uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _db
        .collection('users')
        .doc(_uid)
        .collection('addresses')
        .orderBy('isDefault', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> setDefaultAddress(String addressId) async {
    if (_uid == null) return;
    final addressesRef = _db.collection('users').doc(_uid).collection('addresses');
    final existing = await addressesRef.get();
    final batch = _db.batch();
    for (final doc in existing.docs) {
      if ((doc.data()['isDefault'] ?? false) == true) {
        batch.update(doc.reference, {'isDefault': false});
      }
    }
    batch.update(addressesRef.doc(addressId), {
      'isDefault': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> deleteAddress(String addressId) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('addresses')
        .doc(addressId)
        .delete();
  }

  Future<void> saveAddress({
    required String nickname,
    required String fullAddress,
    required String houseNumber,
    required double latitude,
    required double longitude,
    required bool isDefault,
    required String type,
  }) async {
    if (_uid == null) return;
    final addressesRef = _db.collection('users').doc(_uid).collection('addresses');
    final doc = addressesRef.doc();
    await doc.set({
      'nickname': nickname,
      'fullAddress': fullAddress,
      'houseNumber': houseNumber,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (isDefault) {
      await setDefaultAddress(doc.id);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ORDERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getOrders() async {
    if (_uid == null) return [];
    try {
      final snap = await _db
          .collection('orders')
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('getOrders error: $e');
      return [];
    }
  }

  Stream<QuerySnapshot> getUserOrdersStream() {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>?> getActiveOrder() async {
    if (_uid == null) return null;
    try {
      final snap = await _db
          .collection('orders')
          .where('userId', isEqualTo: _uid)
          .where('status', whereIn: ['pending', 'pickup', 'processing', 'delivery', 'assigned', 'accepted'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return {'id': snap.docs.first.id, ...snap.docs.first.data()};
    } catch (e) {
      debugPrint('getActiveOrder error: $e');
      return null;
    }
  }

  Stream<QuerySnapshot> getActiveOrderStream() {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: _uid)
        .where('status', whereIn: ['pending', 'pickup', 'processing', 'delivery', 'assigned', 'accepted'])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COUPONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUserCoupons() async {
    if (_uid == null) return [];
    try {
      final snap = await _db
          .collection('users')
          .doc(_uid)
          .collection('coupons')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('getUserCoupons error: $e');
      return [];
    }
  }

  Future<void> seedWelcomeCoupons(List<Map<String, dynamic>> coupons) async {
    if (_uid == null) return;
    final batch = _db.batch();
    for (final coupon in coupons) {
      final ref = _db.collection('users').doc(_uid).collection('coupons').doc();
      batch.set(ref, {
        ...coupon,
        'status': 'available',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<bool> applyCoupon(String couponCode) async {
    if (_uid == null) return false;
    try {
      final snap = await _db
          .collection('users')
          .doc(_uid)
          .collection('coupons')
          .where('code', isEqualTo: couponCode)
          .where('status', isEqualTo: 'available')
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return false;
      await snap.docs.first.reference.update({'status': 'used', 'usedAt': FieldValue.serverTimestamp()});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOYALTY
  // ─────────────────────────────────────────────────────────────────────────

  Stream<DocumentSnapshot> getLoyaltyStream() {
    return _db.collection('users').doc(_uid).snapshots();
  }

  Stream<QuerySnapshot> getLoyaltyHistoryStream() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('loyalty_history')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<Map<String, dynamic>> redeemPoints(int points) async {
    if (_uid == null) return {'success': false, 'error': 'Not logged in'};
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      final currentPoints = (doc.data()?['loyaltyPoints'] ?? 0) as int;
      if (currentPoints < points) {
        return {'success': false, 'error': 'Insufficient points'};
      }
      final discountAmount = (points * 0.1).roundToDouble(); // 1 point = ₹0.10
      await _db.collection('users').doc(_uid).update({
        'loyaltyPoints': FieldValue.increment(-points),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _db
          .collection('users')
          .doc(_uid)
          .collection('loyalty_history')
          .add({
        'type': 'redeem',
        'points': -points,
        'description': 'Points redeemed for ₹${discountAmount.toStringAsFixed(0)} discount',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return {'success': true, 'discountAmount': discountAmount};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REFERRAL
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> ensureReferralCode() async {
    if (_uid == null) return '';
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      final existing = doc.data()?['referralCode'] as String?;
      if (existing != null && existing.isNotEmpty) return existing;

      // Generate a unique referral code
      final code = 'LAUN${_uid!.substring(0, 6).toUpperCase()}';
      await _db.collection('users').doc(_uid).update({'referralCode': code});
      return code;
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>> applyReferralCode(String code) async {
    if (_uid == null) return {'success': false, 'error': 'Not logged in'};
    try {
      // Find user with this referral code
      final snap = await _db
          .collection('users')
          .where('referralCode', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        return {'success': false, 'error': 'Invalid referral code'};
      }
      final referrerId = snap.docs.first.id;
      if (referrerId == _uid) {
        return {'success': false, 'error': 'Cannot use your own referral code'};
      }

      // Check if already applied
      final myDoc = await _db.collection('users').doc(_uid).get();
      if (myDoc.data()?['referredBy'] != null) {
        return {'success': false, 'error': 'Referral code already applied'};
      }

      // Award points to both
      final batch = _db.batch();
      batch.update(_db.collection('users').doc(_uid), {
        'referredBy': referrerId,
        'loyaltyPoints': FieldValue.increment(100),
      });
      batch.update(_db.collection('users').doc(referrerId), {
        'loyaltyPoints': FieldValue.increment(200),
      });
      await batch.commit();

      return {'success': true, 'pointsEarned': 100};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Stream<QuerySnapshot> getNotificationsStream() {
    return _db
        .collection('notifications')
        .where('targetGroup', whereIn: ['all', 'users'])
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('read_notifications')
        .doc(notificationId)
        .set({'readAt': FieldValue.serverTimestamp()});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TRANSACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  Stream<QuerySnapshot> getTransactionsStream() {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: _uid)
        .where('paymentStatus', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEEDBACK
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> submitFeedback({
    required String orderId,
    required int rating,
    required String comment,
  }) async {
    if (_uid == null) return;
    await _db.collection('feedback').add({
      'userId': _uid,
      'orderId': orderId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPLOYEES / DELIVERY / STAFF — queries on the unified users collection
  // ─────────────────────────────────────────────────────────────────────────

  /// Get all delivery agents (online + offline)
  Stream<QuerySnapshot> getDeliveryAgentsStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'delivery')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  /// Get all staff members
  Stream<QuerySnapshot> getStaffStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'staff')
        .snapshots();
  }

  /// Get all managers
  Stream<QuerySnapshot> getManagersStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'manager')
        .snapshots();
  }

  /// Get all non-customer users (employees tab)
  Stream<QuerySnapshot> getEmployeesStream() {
    return _db
        .collection('users')
        .where('role', whereIn: ['delivery', 'staff', 'manager'])
        .snapshots();
  }

  /// Toggle delivery agent online/offline status
  Future<void> setDeliveryAgentOnline(String uid, bool isOnline) async {
    await _db.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastStatusChange': FieldValue.serverTimestamp(),
    });
  }

  /// Assign order to delivery agent
  Future<bool> assignOrderToDelivery({
    required String orderId,
    required String deliveryAgentId,
    required String deliveryAgentName,
  }) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'assignedTo': deliveryAgentId,
        'assignedToName': deliveryAgentName,
        'assignedAt': FieldValue.serverTimestamp(),
        'status': 'assigned',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'assigned',
            'note': 'Assigned to $deliveryAgentName',
            'timestamp': Timestamp.now(),
          }
        ]),
      });
      return true;
    } catch (e) {
      debugPrint('assignOrder error: $e');
      return false;
    }
  }

  /// Get orders assigned to a delivery agent
  Stream<QuerySnapshot> getAssignedOrdersStream(String deliveryAgentId) {
    return _db
        .collection('orders')
        .where('assignedTo', isEqualTo: deliveryAgentId)
        .where('status', whereIn: [
          'assigned',
          'pickup',
          'processing',
          'out_for_delivery',
        ])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Update order status (used by delivery/staff/manager)
  Future<bool> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? note,
    String? updatedByUid,
  }) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'delivered') 'deliveredAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': newStatus,
            'note': note ?? 'Status updated',
            'updatedBy': updatedByUid ?? '',
            'timestamp': Timestamp.now(),
          }
        ]),
      });
      return true;
    } catch (e) {
      debugPrint('updateOrderStatus error: $e');
      return false;
    }
  }

  /// Get admin dashboard analytics
  Future<Map<String, dynamic>> getAdminAnalytics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      final results = await Future.wait([
        _db.collection('users').where('role', isEqualTo: 'user').count().get(),
        _db.collection('orders').count().get(),
        _db.collection('orders')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .count()
            .get(),
        _db.collection('orders')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        _db.collection('users')
            .where('role', isEqualTo: 'delivery')
            .where('isOnline', isEqualTo: true)
            .count()
            .get(),
        _db.collection('orders')
            .where('paymentStatus', isEqualTo: 'paid')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
            .get(),
      ]);

      final monthlyOrders = results[5] as QuerySnapshot;
      final monthlyRevenue = monthlyOrders.docs.fold(0.0, (runningTotal, doc) {
        final data = doc.data() as Map<String, dynamic>;
        return runningTotal + ((data['totalAmount'] as num?)?.toDouble() ?? 0);
      });

      return {
        'totalUsers': (results[0] as AggregateQuerySnapshot).count ?? 0,
        'totalOrders': (results[1] as AggregateQuerySnapshot).count ?? 0,
        'ordersToday': (results[2] as AggregateQuerySnapshot).count ?? 0,
        'pendingOrders': (results[3] as AggregateQuerySnapshot).count ?? 0,
        'onlineAgents': (results[4] as AggregateQuerySnapshot).count ?? 0,
        'monthlyRevenue': monthlyRevenue,
      };
    } catch (e) {
      debugPrint('getAdminAnalytics error: $e');
      return {};
    }
  }
}
