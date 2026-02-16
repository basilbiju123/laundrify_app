import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class DeliveryService {
  static final DeliveryService _instance = DeliveryService._internal();
  factory DeliveryService() => _instance;
  DeliveryService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════
  // ASSIGNED ORDERS
  // ═══════════════════════════════════════════════════════════

  /// Get orders assigned to current delivery person
  Stream<List<Map<String, dynamic>>> getMyAssignedOrders(String deliveryPersonId) {
    return _db
        .collection('orders')
        .where('assignedTo', isEqualTo: deliveryPersonId)
        .where('status', whereIn: ['assigned', 'picked_up', 'in_transit'])
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

  /// Get available orders (not yet assigned)
  Stream<List<Map<String, dynamic>>> getAvailableOrders() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .where('assignedTo', isNull: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get completed deliveries
  Stream<List<Map<String, dynamic>>> getMyCompletedOrders(String deliveryPersonId) {
    return _db
        .collection('orders')
        .where('assignedTo', isEqualTo: deliveryPersonId)
        .where('status', isEqualTo: 'delivered')
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // ORDER ACTIONS
  // ═══════════════════════════════════════════════════════════

  /// Accept an order
  Future<bool> acceptOrder(String orderId, String deliveryPersonId) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'assignedTo': deliveryPersonId,
        'status': 'assigned',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'assigned',
            'timestamp': FieldValue.serverTimestamp(),
            'note': 'Order accepted by delivery person',
          }
        ]),
      });
      return true;
    } catch (e) {
      debugPrint('Error accepting order: $e');
      return false;
    }
  }

  /// Mark order as picked up
  Future<bool> markAsPickedUp(String orderId, {String? note}) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': 'picked_up',
        'pickedUpAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'picked_up',
            'timestamp': FieldValue.serverTimestamp(),
            'note': note ?? 'Order picked up from customer',
          }
        ]),
      });
      return true;
    } catch (e) {
      debugPrint('Error marking as picked up: $e');
      return false;
    }
  }

  /// Mark order as in transit
  Future<bool> markAsInTransit(String orderId) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': 'in_transit',
        'inTransitAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'in_transit',
            'timestamp': FieldValue.serverTimestamp(),
            'note': 'Order is in transit',
          }
        ]),
      });
      return true;
    } catch (e) {
      debugPrint('Error marking as in transit: $e');
      return false;
    }
  }

  /// Mark order as delivered
  Future<bool> markAsDelivered(String orderId, {String? note, String? signature}) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deliveryNote': note,
        'signature': signature,
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'delivered',
            'timestamp': FieldValue.serverTimestamp(),
            'note': note ?? 'Order delivered successfully',
          }
        ]),
      });
      return true;
    } catch (e) {
      debugPrint('Error marking as delivered: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // LOCATION TRACKING
  // ═══════════════════════════════════════════════════════════

  /// Update delivery person's current location
  Future<bool> updateLocation(String deliveryPersonId, Position position) async {
    try {
      await _db.collection('deliveryLocations').doc(deliveryPersonId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': FieldValue.serverTimestamp(),
        'deliveryPersonId': deliveryPersonId,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error updating location: $e');
      return false;
    }
  }

  /// Get delivery person's current location
  Stream<Map<String, dynamic>?> getDeliveryPersonLocation(String deliveryPersonId) {
    return _db
        .collection('deliveryLocations')
        .doc(deliveryPersonId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    });
  }

  /// Update order with current location
  Future<bool> updateOrderLocation(String orderId, Position position) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'currentLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
      return true;
    } catch (e) {
      debugPrint('Error updating order location: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // STATISTICS
  // ═══════════════════════════════════════════════════════════

  /// Get delivery person statistics
  Future<Map<String, dynamic>> getDeliveryStats(String deliveryPersonId) async {
    try {
      final ordersSnapshot = await _db
          .collection('orders')
          .where('assignedTo', isEqualTo: deliveryPersonId)
          .get();

      final totalDeliveries = ordersSnapshot.docs.length;
      
      final completedDeliveries = ordersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'delivered')
          .length;

      final activeDeliveries = ordersSnapshot.docs
          .where((doc) => 
              doc.data()['status'] == 'assigned' ||
              doc.data()['status'] == 'picked_up' ||
              doc.data()['status'] == 'in_transit')
          .length;

      // Get today's deliveries
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayDeliveries = ordersSnapshot.docs
          .where((doc) {
            final deliveredAt = (doc.data()['deliveredAt'] as Timestamp?)?.toDate();
            return deliveredAt != null && deliveredAt.isAfter(todayStart);
          })
          .length;

      // Calculate total earnings
      double totalEarnings = 0;
      for (var doc in ordersSnapshot.docs) {
        if (doc.data()['status'] == 'delivered') {
          final deliveryFee = (doc.data()['deliveryFee'] as num?)?.toDouble() ?? 0;
          totalEarnings += deliveryFee;
        }
      }

      return {
        'totalDeliveries': totalDeliveries,
        'completedDeliveries': completedDeliveries,
        'activeDeliveries': activeDeliveries,
        'todayDeliveries': todayDeliveries,
        'totalEarnings': totalEarnings,
      };
    } catch (e) {
      debugPrint('Error getting delivery stats: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ISSUE REPORTING
  // ═══════════════════════════════════════════════════════════

  /// Report an issue with an order
  Future<bool> reportIssue({
    required String orderId,
    required String deliveryPersonId,
    required String issueType,
    required String description,
    String? imageUrl,
  }) async {
    try {
      await _db.collection('orderIssues').add({
        'orderId': orderId,
        'deliveryPersonId': deliveryPersonId,
        'issueType': issueType,
        'description': description,
        'imageUrl': imageUrl,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update order with issue flag
      await _db.collection('orders').doc(orderId).update({
        'hasIssue': true,
        'issueReportedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error reporting issue: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // NAVIGATION HELPER
  // ═══════════════════════════════════════════════════════════

  /// Calculate distance between two points
  double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // in km
  }

  /// Get estimated time (rough calculation: 30 km/h average)
  int getEstimatedTime(double distanceInKm) {
    return ((distanceInKm / 30) * 60).round(); // in minutes
  }
}
