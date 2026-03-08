import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/firestore_models.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════
  // USER MANAGEMENT
  // ═══════════════════════════════════════════════════════════

  /// Get all users
  Stream<List<Map<String, dynamic>>> getAllUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get users by role
  Stream<List<Map<String, dynamic>>> getUsersByRole(UserRole role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role.name)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Update user role
  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      List<String> accessibleRoles;
      switch (newRole) {
        case UserRole.admin:
          accessibleRoles = ['admin', 'manager', 'delivery', 'user'];
          break;
        case UserRole.manager:
          accessibleRoles = ['manager', 'user'];
          break;
        case UserRole.delivery:
          accessibleRoles = ['delivery', 'user'];
          break;
        case UserRole.staff:
          accessibleRoles = ['staff', 'user'];
          break;
        case UserRole.user:
          accessibleRoles = ['user'];
          break;
      }

      await _db.collection('users').doc(userId).update({
        'role': newRole.name,
        'accessibleRoles': accessibleRoles,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      });
      return true;
    } catch (e) {
      debugPrint('Error updating user role: $e');
      return false;
    }
  }

  /// Delete user
  Future<bool> deleteUser(String userId) async {
    try {
      final batch = _db.batch();

      // Delete user document
      batch.delete(_db.collection('users').doc(userId));

      // Delete user's orders
      final orders = await _db
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in orders.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return false;
    }
  }

  /// Suspend/Activate user
  Future<bool> toggleUserStatus(String userId, bool suspend) async {
    try {
      await _db.collection('users').doc(userId).update({
        'isSuspended': suspend,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling user status: $e');
      return false;
    }
  }

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

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': newStatus,
            'timestamp': FieldValue.serverTimestamp(),
            'updatedBy': 'admin',
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
  Future<bool> assignOrderToDelivery(String orderId, String deliveryPersonId) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'assignedTo': deliveryPersonId,
        'status': 'assigned',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error assigning order: $e');
      return false;
    }
  }

  /// Delete order
  Future<bool> deleteOrder(String orderId) async {
    try {
      await _db.collection('orders').doc(orderId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting order: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ANALYTICS & STATISTICS
  // ═══════════════════════════════════════════════════════════

  /// Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Get total users
      final usersSnapshot = await _db.collection('users').get();
      final totalUsers = usersSnapshot.docs.length;

      // Get total orders
      final ordersSnapshot = await _db.collection('orders').get();
      final totalOrders = ordersSnapshot.docs.length;

      // Get active orders (not completed/cancelled)
      final activeOrders = ordersSnapshot.docs
          .where((doc) => 
              doc.data()['status'] != 'completed' && 
              doc.data()['status'] != 'cancelled')
          .length;

      // Get completed orders
      final completedOrders = ordersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;

      // Get pending orders
      final pendingOrders = ordersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .length;

      // Calculate total revenue
      double totalRevenue = 0;
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'completed' && data['totalAmount'] != null) {
          totalRevenue += (data['totalAmount'] as num).toDouble();
        }
      }

      // Get today's orders
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayOrders = ordersSnapshot.docs
          .where((doc) {
            final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
            return createdAt != null && createdAt.isAfter(todayStart);
          })
          .length;

      // Get delivery personnel count from correct collection
      final deliverySnap = await _db.collection('delivery_agents').count().get();
      final deliveryPersonnel = deliverySnap.count ?? 0;

      return {
        'totalUsers': totalUsers,
        'totalOrders': totalOrders,
        'activeOrders': activeOrders,
        'completedOrders': completedOrders,
        'pendingOrders': pendingOrders,
        'totalRevenue': totalRevenue,
        'todayOrders': todayOrders,
        'deliveryPersonnel': deliveryPersonnel,
      };
    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      return {};
    }
  }

  /// Get revenue by date range
  Future<double> getRevenueByDateRange(DateTime start, DateTime end) async {
    try {
      final orders = await _db
          .collection('orders')
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      double revenue = 0;
      for (var doc in orders.docs) {
        final amount = doc.data()['totalAmount'] as num?;
        if (amount != null) {
          revenue += amount.toDouble();
        }
      }
      return revenue;
    } catch (e) {
      debugPrint('Error getting revenue: $e');
      return 0;
    }
  }

  /// Get monthly revenue for chart
  Future<List<Map<String, dynamic>>> getMonthlyRevenue(int year) async {
    List<Map<String, dynamic>> monthlyData = [];
    
    for (int month = 1; month <= 12; month++) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59);
      
      final revenue = await getRevenueByDateRange(start, end);
      
      monthlyData.add({
        'month': _getMonthName(month),
        'revenue': revenue,
      });
    }
    
    return monthlyData;
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  // ═══════════════════════════════════════════════════════════
  // SERVICE MANAGEMENT
  // ═══════════════════════════════════════════════════════════

  /// Get all services
  Stream<List<Map<String, dynamic>>> getAllServices() {
    return _db.collection('services').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Add/Update service
  Future<bool> saveService(Map<String, dynamic> serviceData, {String? serviceId}) async {
    try {
      if (serviceId != null) {
        // Update existing service
        await _db.collection('services').doc(serviceId).update({
          ...serviceData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add new service
        await _db.collection('services').add({
          ...serviceData,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error saving service: $e');
      return false;
    }
  }

  /// Delete service
  Future<bool> deleteService(String serviceId) async {
    try {
      await _db.collection('services').doc(serviceId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting service: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // COUPON MANAGEMENT
  // ═══════════════════════════════════════════════════════════

  /// Get all coupons
  Stream<List<Map<String, dynamic>>> getAllCoupons() {
    return _db.collection('coupons').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Add/Update coupon
  Future<bool> saveCoupon(Map<String, dynamic> couponData, {String? couponId}) async {
    try {
      if (couponId != null) {
        await _db.collection('coupons').doc(couponId).update({
          ...couponData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _db.collection('coupons').add({
          ...couponData,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error saving coupon: $e');
      return false;
    }
  }

  /// Delete coupon
  Future<bool> deleteCoupon(String couponId) async {
    try {
      await _db.collection('coupons').doc(couponId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting coupon: $e');
      return false;
    }
  }

  /// Toggle coupon status
  Future<bool> toggleCouponStatus(String couponId, bool isActive) async {
    try {
      await _db.collection('coupons').doc(couponId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling coupon status: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════

  /// Send notification to all users
  Future<bool> sendBroadcastNotification(String title, String message) async {
    try {
      await _db.collection('notifications').add({
        'title': title,
        'message': message,
        'type': 'broadcast',
        'createdAt': FieldValue.serverTimestamp(),
        'sentBy': 'admin',
      });
      return true;
    } catch (e) {
      debugPrint('Error sending notification: $e');
      return false;
    }
  }

  /// Send notification to specific user
  Future<bool> sendUserNotification(String userId, String title, String message) async {
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': 'user',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'sentBy': 'admin',
      });
      return true;
    } catch (e) {
      debugPrint('Error sending notification: $e');
      return false;
    }
  }
}
