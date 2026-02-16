import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Save abandoned cart (when user reaches payment but doesn't complete)
  Future<void> saveAbandonedCart({
    required String orderId,
    required List<Map<String, dynamic>> services,
    required double subtotal,
    required double deliveryFee,
    required double gst,
    required double total,
    required String pickupDate,
    required String pickupTime,
    required String deliveryDate,
    required String deliveryTime,
    required String address,
    required String addressLabel,
  }) async {
    if (_uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(_uid)
          .collection('abandoned_carts')
          .doc(orderId)
          .set({
        'orderId': orderId,
        'services': services,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'gst': gst,
        'total': total,
        'pickupDate': pickupDate,
        'pickupTime': pickupTime,
        'deliveryDate': deliveryDate,
        'deliveryTime': deliveryTime,
        'address': address,
        'addressLabel': addressLabel,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'abandoned',
      });

      // Send notification about abandoned cart
      await _sendAbandonedCartNotification(orderId, total);
    } catch (e) {
      // Fail silently
    }
  }

  /// Get abandoned carts
  Future<List<Map<String, dynamic>>> getAbandonedCarts() async {
    if (_uid == null) return [];
    try {
      final snap = await _db
          .collection('users')
          .doc(_uid)
          .collection('abandoned_carts')
          .where('status', isEqualTo: 'abandoned')
          .orderBy('createdAt', descending: true)
          .limit(10)
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

  /// Convert abandoned cart to order
  Future<void> convertCartToOrder(String cartId) async {
    if (_uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(_uid)
          .collection('abandoned_carts')
          .doc(cartId)
          .update({
        'status': 'converted',
        'convertedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Delete abandoned cart
  Future<void> deleteAbandonedCart(String cartId) async {
    if (_uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(_uid)
          .collection('abandoned_carts')
          .doc(cartId)
          .delete();
    } catch (_) {}
  }

  Future<void> _sendAbandonedCartNotification(
      String orderId, double total) async {
    if (_uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(_uid)
          .collection('notifications')
          .add({
        'title': 'Complete Your Order 🛒',
        'message':
            'Your order #$orderId (₹${total.toStringAsFixed(0)}) is waiting. Complete it now and get 10% off!',
        'type': 'abandoned_cart',
        'orderId': orderId,
        'icon': 'shopping_cart',
        'color': '0xFFD97706',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
