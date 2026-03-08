import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ManagerService {
  static final ManagerService _instance = ManagerService._internal();
  factory ManagerService() => _instance;
  ManagerService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────────────────
  // DASHBOARD STATS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfMonth = DateTime(now.year, now.month, 1);

      final todaySnap = await _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      final monthSnap = await _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('status', isEqualTo: 'completed')
          .get();

      final pendingSnap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'pending')
          .get();

      final deliverySnap = await _db
          .collection('delivery_agents')
          .get();

      double monthRevenue = 0;
      for (final doc in monthSnap.docs) {
        monthRevenue += ((doc.data()['totalAmount'] ?? 0) as num).toDouble();
      }

      double todayRevenue = 0;
      for (final doc in todaySnap.docs) {
        if ((doc.data()['status'] ?? '') == 'completed') {
          todayRevenue += ((doc.data()['totalAmount'] ?? 0) as num).toDouble();
        }
      }

      return {
        'todayOrders': todaySnap.docs.length,
        'todayRevenue': todayRevenue,
        'monthRevenue': monthRevenue,
        'pendingOrders': pendingSnap.docs.length,
        'totalDeliveryStaff': deliverySnap.docs.length,
        'activeDeliveryStaff': deliverySnap.docs.where((d) => d.data()['isAvailable'] == true).length,
      };
    } catch (e) {
      debugPrint('getDashboardStats error: $e');
      return {
        'todayOrders': 0,
        'todayRevenue': 0.0,
        'monthRevenue': 0.0,
        'pendingOrders': 0,
        'totalDeliveryStaff': 0,
        'activeDeliveryStaff': 0,
      };
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ORDER STREAMS
  // ─────────────────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getPendingOrders() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getOrdersByStatus(String status) {
    return _db
        .collection('orders')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Stream<QuerySnapshot> getAllOrders() {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELIVERY PERSONNEL
  // ─────────────────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getDeliveryPersonnel() {
    return _db
        .collection('delivery_agents')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<List<Map<String, dynamic>>> getAvailableDeliveryPersonnel() async {
    try {
      final snap = await _db
          .collection('delivery_agents')
          .where('isAvailable', isEqualTo: true)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('getAvailableDeliveryPersonnel error: $e');
      return [];
    }
  }

  Future<int> getDeliveryPersonActiveOrders(String deliveryPersonId) async {
    try {
      final snap = await _db
          .collection('orders')
          .where('assignedTo', isEqualTo: deliveryPersonId)
          .where('status', whereIn: ['assigned', 'accepted', 'pickup', 'delivery'])
          .get();
      return snap.docs.length;
    } catch (e) {
      debugPrint('getDeliveryPersonActiveOrders error: $e');
      return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ORDER ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> assignOrderToDelivery(
    String orderId,
    String deliveryPersonId,
    [String? deliveryPersonName]
  ) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': 'assigned',
        'assignedTo': deliveryPersonId,
        'assignedBy': _uid,
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Update delivery person active orders count
      await _db.collection('users').doc(deliveryPersonId).update({
        'activeOrders': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      debugPrint('assignOrderToDelivery error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId, String reason) async {
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      final assignedTo = orderDoc.data()?['assignedTo'] as String?;

      await _db.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'cancelReason': reason,
        'cancelledBy': _uid,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Decrease delivery person's active orders
      if (assignedTo != null) {
        await _db.collection('users').doc(assignedTo).update({
          'activeOrders': FieldValue.increment(-1),
        });
      }

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'completed') 'completedAt': FieldValue.serverTimestamp(),
      });
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
