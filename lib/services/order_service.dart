import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Cancel order with conditions
  /// Can cancel if: pending, confirmed (not yet picked up)
  /// Cannot cancel if: picked_up, in_transit, delivered, cancelled
  Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required String userId,
    required String reason,
  }) async {
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();

      if (!orderDoc.exists) {
        return {'success': false, 'error': 'Order not found'};
      }

      final orderData = orderDoc.data()!;
      final status = orderData['status'];
      final orderUserId = orderData['userId'];

      // Verify user owns this order
      if (orderUserId != userId) {
        return {'success': false, 'error': 'Unauthorized'};
      }

      // Check if order can be cancelled
      if (status == 'delivered') {
        return {
          'success': false,
          'error': 'Cannot cancel delivered order',
          'canRefund': true, // But can request refund
        };
      }

      if (status == 'cancelled') {
        return {
          'success': false,
          'error': 'Order already cancelled',
        };
      }

      if (status == 'picked_up' || status == 'in_transit') {
        return {
          'success': false,
          'error': 'Order is already ${status == 'picked_up' ? 'picked up' : 'in transit'}. Please contact support.',
          'contactSupport': true,
        };
      }

      // Determine refund amount based on status
      double refundPercentage = 1.0; // 100% refund by default
      if (status == 'assigned') {
        refundPercentage = 0.9; // 90% refund if assigned
      }

      final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0;
      final refundAmount = totalAmount * refundPercentage;

      // Cancel the order
      await _db.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'cancelledBy': 'user',
        'refundAmount': refundAmount,
        'refundPercentage': refundPercentage * 100,
        'refundStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'cancelled',
            'timestamp': FieldValue.serverTimestamp(),
            'note': 'Order cancelled by user: $reason',
          }
        ]),
      });

      return {
        'success': true,
        'message': 'Order cancelled successfully',
        'refundAmount': refundAmount,
        'refundPercentage': refundPercentage * 100,
      };
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      return {'success': false, 'error': 'Failed to cancel order'};
    }
  }

  /// Show cancellation dialog with conditions
  static Future<String?> showCancellationDialog(BuildContext context, String orderStatus) async {
    // Check if order can be cancelled
    if (orderStatus == 'picked_up' || orderStatus == 'in_transit') {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Cannot Cancel',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Your order is already ${orderStatus == 'picked_up' ? 'picked up' : 'in transit'}. Please contact our support team if you need assistance.',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to support page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F6FD8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Contact Support'),
            ),
          ],
        ),
      );
      return null;
    }

    if (orderStatus == 'delivered' || orderStatus == 'cancelled') {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Cannot Cancel',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Order is already ${orderStatus == 'delivered' ? 'delivered' : 'cancelled'}.',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return null;
    }

    // Show cancellation reason dialog
    final reasons = [
      'Changed my mind',
      'Found better price elsewhere',
      'Ordered by mistake',
      'Delivery taking too long',
      'Need to modify order',
      'Other',
    ];

    String? selectedReason;
    final customReasonController = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Cancel Order',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please select a reason for cancellation:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: selectedReason,
                onChanged: (value) {
                  setState(() => selectedReason = value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: reasons.map((reason) {
                    return RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ),
              if (selectedReason == 'Other') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: customReasonController,
                  decoration: InputDecoration(
                    labelText: 'Please specify',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        orderStatus == 'assigned'
                            ? 'Refund: 90% of order amount'
                            : 'Refund: 100% of order amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Order'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () {
                      final finalReason = selectedReason == 'Other'
                          ? customReasonController.text.trim()
                          : selectedReason!;
                      Navigator.pop(context, finalReason);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel Order'),
            ),
          ],
        ),
      ),
    );
  }

  /// Get order details for tracking
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting order details: $e');
      return null;
    }
  }

  /// Get delivery person details
  Future<Map<String, dynamic>?> getDeliveryPersonDetails(String deliveryPersonId) async {
    try {
      final doc = await _db.collection('users').doc(deliveryPersonId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting delivery person details: $e');
      return null;
    }
  }
}
