import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManagerService {
  static final ManagerService _instance = ManagerService._internal();
  factory ManagerService() => _instance;
  ManagerService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════
  // ORDER MANAGEMENT
  // ═══════════════════════════════════════════════════════════

  /// Get all orders
  Stream<List<Map<String, dynamic>>> getAllOrders() {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get orders by status
  Stream<List<Map<String, dynamic>>> getOrdersByStatus(String status) {
    return _db
        .collection('orders')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get pending orders (need assignment)
  Stream<List<Map<String, dynamic>>> getPendingOrders() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false) // Oldest first
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get today's orders
  Stream<List<Map<String, dynamic>>> getTodayOrders() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    return _db
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String newStatus, {String? note}) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': newStatus,
            'timestamp': FieldValue.serverTimestamp(),
            'updatedBy': 'manager',
            'note': note,
          }
        ]),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  /// Assign order to delivery person
  Future<bool> assignOrderToDelivery(String orderId, String deliveryPersonId, String deliveryPersonName) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'assignedTo': deliveryPersonId,
        'assignedToName': deliveryPersonName,
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'assigned',
            'timestamp': FieldValue.serverTimestamp(),
            'updatedBy': 'manager',
            'note': 'Assigned to $deliveryPersonName',
          }
        ]),
      });
      return true;
    } catch (e) {
      debugPrint('Error assigning order: $e');
      return false;
    }
  }

  /// Cancel order (with conditions)
  Future<Map<String, dynamic>> cancelOrder(String orderId, String reason) async {
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      
      if (!orderDoc.exists) {
        return {'success': false, 'error': 'Order not found'};
      }

      final orderData = orderDoc.data()!;
      final status = orderData['status'];

      // Check if order can be cancelled
      if (status == 'delivered' || status == 'cancelled') {
        return {
          'success': false,
          'error': 'Cannot cancel ${status == 'delivered' ? 'delivered' : 'already cancelled'} order'
        };
      }

      if (status == 'in_transit' || status == 'picked_up') {
        return {
          'success': false,
          'error': 'Cannot cancel order that is already picked up or in transit. Please contact delivery person.',
        };
      }

      // Cancel the order
      await _db.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'cancelledBy': 'manager',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'cancelled',
            'timestamp': FieldValue.serverTimestamp(),
            'updatedBy': 'manager',
            'note': 'Order cancelled: $reason',
          }
        ]),
      });

      return {'success': true, 'message': 'Order cancelled successfully'};
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      return {'success': false, 'error': 'Failed to cancel order'};
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DELIVERY STAFF MANAGEMENT
  // ═══════════════════════════════════════════════════════════

  /// Get all delivery personnel
  Stream<List<Map<String, dynamic>>> getDeliveryPersonnel() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'delivery')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get available delivery personnel (not currently assigned)
  Future<List<Map<String, dynamic>>> getAvailableDeliveryPersonnel() async {
    try {
      final allDelivery = await _db
          .collection('users')
          .where('role', isEqualTo: 'delivery')
          .get();

      List<Map<String, dynamic>> available = [];

      for (var doc in allDelivery.docs) {
        final deliveryId = doc.id;
        
        // Check active assignments
        final activeOrders = await _db
            .collection('orders')
            .where('assignedTo', isEqualTo: deliveryId)
            .where('status', whereIn: ['assigned', 'picked_up', 'in_transit'])
            .get();

        if (activeOrders.docs.isEmpty) {
          final data = doc.data();
          data['id'] = doc.id;
          available.add(data);
        }
      }

      return available;
    } catch (e) {
      debugPrint('Error getting available delivery personnel: $e');
      return [];
    }
  }

  /// Get delivery person's active orders count
  Future<int> getDeliveryPersonActiveOrders(String deliveryPersonId) async {
    try {
      final orders = await _db
          .collection('orders')
          .where('assignedTo', isEqualTo: deliveryPersonId)
          .where('status', whereIn: ['assigned', 'picked_up', 'in_transit'])
          .get();
      return orders.docs.length;
    } catch (e) {
      debugPrint('Error getting active orders count: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // STATISTICS & ANALYTICS
  // ═══════════════════════════════════════════════════════════

  /// Get manager dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final ordersSnapshot = await _db.collection('orders').get();
      final totalOrders = ordersSnapshot.docs.length;

      final pendingOrders = ordersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .length;

      final assignedOrders = ordersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'assigned')
          .length;

      final inTransitOrders = ordersSnapshot.docs
          .where((doc) => 
              doc.data()['status'] == 'picked_up' ||
              doc.data()['status'] == 'in_transit')
          .length;

      final completedOrders = ordersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'delivered')
          .length;

      final cancelledOrders = ordersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'cancelled')
          .length;

      // Get today's orders
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayOrders = ordersSnapshot.docs
          .where((doc) {
            final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
            return createdAt != null && createdAt.isAfter(todayStart);
          })
          .length;

      // Calculate revenue
      double totalRevenue = 0;
      double todayRevenue = 0;
      for (var doc in ordersSnapshot.docs) {
        if (doc.data()['status'] == 'delivered') {
          final amount = (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
          totalRevenue += amount;
          
          final deliveredAt = (doc.data()['deliveredAt'] as Timestamp?)?.toDate();
          if (deliveredAt != null && deliveredAt.isAfter(todayStart)) {
            todayRevenue += amount;
          }
        }
      }

      // Get delivery personnel count
      final deliverySnapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'delivery')
          .get();
      final totalDeliveryPersonnel = deliverySnapshot.docs.length;

      return {
        'totalOrders': totalOrders,
        'pendingOrders': pendingOrders,
        'assignedOrders': assignedOrders,
        'inTransitOrders': inTransitOrders,
        'completedOrders': completedOrders,
        'cancelledOrders': cancelledOrders,
        'todayOrders': todayOrders,
        'totalRevenue': totalRevenue,
        'todayRevenue': todayRevenue,
        'totalDeliveryPersonnel': totalDeliveryPersonnel,
      };
    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      return {};
    }
  }

  /// Get daily order statistics
  Future<List<Map<String, dynamic>>> getDailyStats(int days) async {
    List<Map<String, dynamic>> dailyData = [];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final orders = await _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .get();

      double revenue = 0;
      for (var doc in orders.docs) {
        if (doc.data()['status'] == 'delivered') {
          revenue += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
        }
      }

      dailyData.add({
        'date': '${date.day}/${date.month}',
        'orders': orders.docs.length,
        'revenue': revenue,
      });
    }

    return dailyData;
  }

  // ═══════════════════════════════════════════════════════════
  // ISSUES & SUPPORT
  // ═══════════════════════════════════════════════════════════

  /// Get all order issues
  Stream<List<Map<String, dynamic>>> getOrderIssues() {
    return _db
        .collection('orderIssues')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Resolve an issue
  Future<bool> resolveIssue(String issueId, String resolution) async {
    try {
      await _db.collection('orderIssues').doc(issueId).update({
        'status': 'resolved',
        'resolution': resolution,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': 'manager',
      });
      return true;
    } catch (e) {
      debugPrint('Error resolving issue: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // CUSTOMER MANAGEMENT
  // ═══════════════════════════════════════════════════════════

  /// Get all customers
  Stream<List<Map<String, dynamic>>> getAllCustomers() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'user')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get customer order history
  Future<List<Map<String, dynamic>>> getCustomerOrders(String customerId) async {
    try {
      final orders = await _db
          .collection('orders')
          .where('userId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return orders.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting customer orders: $e');
      return [];
    }
  }
}
