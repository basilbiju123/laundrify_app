// lib/services/coupon_service.dart
//
// TWO-LAYER COUPON LOOKUP:
//
//   Layer 1 — /coupons/{couponId}            ← Admin-created global coupons
//     Fields: code, discountType('flat'|'percentage'), discount, maxDiscount,
//             minOrder, validUntil, maxUses, usedCount, isActive, title
//     Sub:    /coupons/{id}/usages/{usageId}
//               userId, userEmail, userName, orderId,
//               discountAmount, orderTotal, usedAt
//
//   Layer 2 — /users/{uid}/coupons/{couponId} ← Personal (referral rewards)
//     Fields: code, status('available'|'used'), discountType, discount, ...
//
// Admin reads /coupons stream + subcollection /usages for full analytics.

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CouponService {
  final _db = FirebaseFirestore.instance;

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) { try { return DateTime.parse(v); } catch (_) {} }
    return null;
  }

  double _calcDiscount(Map<String, dynamic> data, double billTotal) {
    final type  = data['discountType'] ?? 'flat';
    final value = (data['discount'] ?? 0).toDouble();
    final cap   = data['maxDiscount'] != null
        ? (data['maxDiscount'] as num).toDouble()
        : double.infinity;
    double amt = type == 'percentage'
        ? (billTotal * value / 100).clamp(0.0, cap)
        : value.clamp(0.0, cap);
    return amt.clamp(0.0, billTotal);
  }

  // ── Validate & calculate discount ───────────────────────────
  // Returns: valid, error, discountAmount, discountedTotal,
  //          couponId, couponData, isGlobal
  Future<Map<String, dynamic>> applyCoupon({
    required String code,
    required double billTotal,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'valid': false, 'error': 'Not logged in'};

    final upper = code.trim().toUpperCase();

    // ── Layer 1: global admin coupons ────────────────────────
    try {
      final snap = await _db
          .collection('coupons')
          .where('code', isEqualTo: upper)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final doc  = snap.docs.first;
        final data = doc.data();

        // Expired?
        final exp = _toDateTime(data['validUntil']);
        if (exp != null && exp.isBefore(DateTime.now())) {
          return {'valid': false, 'error': 'This coupon has expired'};
        }

        // Max uses reached?
        final maxUses   = data['maxUses'];
        final usedCount = (data['usedCount'] ?? 0) as int;
        if (maxUses != null && usedCount >= (maxUses as int)) {
          return {'valid': false, 'error': 'Coupon usage limit has been reached'};
        }

        // Already used by this user?
        final used = await _db
            .collection('coupons').doc(doc.id)
            .collection('usages')
            .where('userId', isEqualTo: user.uid)
            .limit(1).get();
        if (used.docs.isNotEmpty) {
          return {'valid': false, 'error': 'You have already used this coupon'};
        }

        // Min order check
        final minOrder = (data['minOrder'] ?? 0).toDouble();
        if (billTotal < minOrder) {
          return {'valid': false,
            'error': 'Minimum order ₹${minOrder.toStringAsFixed(0)} required'};
        }

        final discount = _calcDiscount(data, billTotal);
        return {
          'valid': true,
          'discountAmount':  discount,
          'discountedTotal': (billTotal - discount).clamp(0.0, billTotal),
          'couponId':   doc.id,
          'couponData': data,
          'isGlobal':   true,
        };
      }
    } catch (e) {
      debugPrint('Global coupon lookup error: $e');
    }

    // ── Layer 2: user-specific coupons (referral etc.) ───────
    try {
      final snap = await _db
          .collection('users').doc(user.uid)
          .collection('coupons')
          .where('code', isEqualTo: upper)
          .where('status', isEqualTo: 'available')
          .limit(1).get();

      if (snap.docs.isNotEmpty) {
        final doc  = snap.docs.first;
        final data = doc.data();

        final exp = _toDateTime(data['validUntil']);
        if (exp != null && exp.isBefore(DateTime.now())) {
          return {'valid': false, 'error': 'This coupon has expired'};
        }

        final minOrder = (data['minOrder'] ?? 0).toDouble();
        if (billTotal < minOrder) {
          return {'valid': false,
            'error': 'Minimum order ₹${minOrder.toStringAsFixed(0)} required'};
        }

        final discount = _calcDiscount(data, billTotal);
        return {
          'valid': true,
          'discountAmount':  discount,
          'discountedTotal': (billTotal - discount).clamp(0.0, billTotal),
          'couponId':   doc.id,
          'couponData': data,
          'isGlobal':   false,
        };
      }
    } catch (e) {
      debugPrint('User coupon lookup error: $e');
    }

    return {'valid': false, 'error': 'Coupon not found or already used'};
  }

  // ── Record usage after order is confirmed ────────────────────
  // isGlobal=true  → writes to /coupons/{id}/usages + increments usedCount
  // isGlobal=false → marks user-coupon status='used'
  Future<void> markCouponUsed({
    required String couponId,
    required bool isGlobal,
    required double appliedOrderTotal,
    required double appliedDiscountAmount,
    required String orderId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (isGlobal) {
      try {
        // Usage record — read by admin for analytics
        await _db
            .collection('coupons').doc(couponId)
            .collection('usages').add({
          'userId':         user.uid,
          'userEmail':      user.email ?? '',
          'userName':       user.displayName ?? user.email ?? '',
          'orderId':        orderId,
          'orderTotal':     appliedOrderTotal,
          'discountAmount': appliedDiscountAmount,
          'usedAt':         FieldValue.serverTimestamp(),
        });
        // Increment counter on coupon doc
        await _db.collection('coupons').doc(couponId).update({
          'usedCount':  FieldValue.increment(1),
          'lastUsedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Global coupon usage tracking failed (non-fatal): $e');
      }
    } else {
      try {
        await _db
            .collection('users').doc(user.uid)
            .collection('coupons').doc(couponId)
            .update({
          'status':                'used',
          'usedAt':                FieldValue.serverTimestamp(),
          'orderId':               orderId,
          'appliedOrderTotal':     appliedOrderTotal,
          'appliedDiscountAmount': appliedDiscountAmount,
        });
      } catch (e) {
        debugPrint('User coupon update failed (non-fatal): $e');
      }
    }
  }
}
