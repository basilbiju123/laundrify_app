import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DeliveryService {
  static final DeliveryService _instance = DeliveryService._internal();
  factory DeliveryService() => _instance;
  DeliveryService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────────────────
  // STATS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDeliveryStats(String deliveryPersonId) async {
    try {
      final userDoc = await _db.collection('users').doc(deliveryPersonId).get();
      final userData = userDoc.data() ?? {};

      final completedSnap = await _db
          .collection('orders')
          .where('assignedTo', isEqualTo: deliveryPersonId)
          .where('status', isEqualTo: 'completed')
          .get();

      final activeSnap = await _db
          .collection('orders')
          .where('assignedTo', isEqualTo: deliveryPersonId)
          .where('status', whereIn: ['assigned', 'accepted', 'pickup', 'delivery'])
          .get();

      double totalEarnings = 0;
      for (final doc in completedSnap.docs) {
        totalEarnings += ((doc.data()['totalAmount'] ?? 0) as num) * 0.15; // 15% commission
      }

      return {
        'totalDeliveries': completedSnap.docs.length,
        'activeOrders': activeSnap.docs.length,
        'totalEarnings': totalEarnings,
        'rating': userData['rating'] ?? 4.5,
        'isAvailable': userData['isAvailable'] ?? true,
      };
    } catch (e) {
      debugPrint('getDeliveryStats error: $e');
      return {
        'totalDeliveries': 0,
        'activeOrders': 0,
        'totalEarnings': 0.0,
        'rating': 4.5,
        'isAvailable': true,
      };
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ORDER STREAMS
  // ─────────────────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getMyAssignedOrders(String deliveryPersonId) {
    return _db
        .collection('orders')
        .where('assignedTo', isEqualTo: deliveryPersonId)
        .where('status', whereIn: ['assigned', 'accepted', 'pickup', 'delivery'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getAvailableOrders() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getMyCompletedOrders(String deliveryPersonId) {
    return _db
        .collection('orders')
        .where('assignedTo', isEqualTo: deliveryPersonId)
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ORDER ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> acceptOrder(String orderId, String deliveryPersonId) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': 'accepted',
        'assignedTo': deliveryPersonId,
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('acceptOrder error: $e');
      return false;
    }
  }

  Future<bool> markAsPickedUp(String orderId) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': 'pickup',
        'pickedUpAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('markAsPickedUp error: $e');
      return false;
    }
  }

  Future<bool> markAsInTransit(String orderId) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': 'delivery',
        'inTransitAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('markAsInTransit error: $e');
      return false;
    }
  }

  Future<bool> markAsDelivered(String orderId) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': 'completed',
        'deliveredAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update delivery person stats
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      final assignedTo = orderDoc.data()?['assignedTo'] as String?;
      if (assignedTo != null) {
        final earnings = ((orderDoc.data()?['totalAmount'] ?? 0) as num) * 0.15;
        await _db.collection('users').doc(assignedTo).update({
          'completedOrders': FieldValue.increment(1),
          'totalEarnings': FieldValue.increment(earnings),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } catch (e) {
      debugPrint('markAsDelivered error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AVAILABILITY TOGGLE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> updateAvailability(bool isAvailable) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'isAvailable': isAvailable,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }
}
