import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

const _navy = Color(0xFF080F1E);
const _blue = Color(0xFF1B4FD8);
const _gold = Color(0xFFF5C518);

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  late TabController _tabController;

  List<Map<String, dynamic>> availableCoupons = [];
  List<Map<String, dynamic>> usedCoupons = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCoupons();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCoupons() async {
    setState(() => isLoading = true);

    try {
      // Load coupons from Firestore
      final coupons = await _firestore.getUserCoupons();

      // If user has no coupons yet, seed welcome coupons into Firestore
      if (coupons.isEmpty) {
        await _seedWelcomeCoupons();
        final seeded = await _firestore.getUserCoupons();
        availableCoupons = seeded
            .where((c) => c['status'] == 'available' || c['status'] == null)
            .toList();
        usedCoupons = [];
      } else {
        availableCoupons = coupons
            .where((c) => c['status'] == 'available' || c['status'] == null)
            .toList();
        usedCoupons =
            coupons.where((c) => c['status'] == 'used').toList();
      }
    } catch (e) {
      debugPrint('Error loading coupons: $e');
      availableCoupons = _getDefaultCoupons();
      usedCoupons = [];
    }

    setState(() => isLoading = false);
  }

  Future<void> _seedWelcomeCoupons() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final defaults = _getDefaultCoupons();
      final batch = FirebaseFirestore.instance.batch();
      for (final coupon in defaults) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('coupons')
            .doc();
        batch.set(ref, {
          ...coupon,
          'status': 'available',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Seed coupons error: $e');
    }
  }

  List<Map<String, dynamic>> _getDefaultCoupons() {
    return [
      {
        'id': 'WELCOME50',
        'code': 'WELCOME50',
        'title': 'Welcome Bonus',
        'description': 'Get 50% off on your first order',
        'discount': 50,
        'discountType': 'percentage',
        'minOrder': 500,
        'maxDiscount': 250,
        'validUntil': DateTime.now().add(const Duration(days: 30)),
        'status': 'available',
      },
      {
        'id': 'SAVE100',
        'code': 'SAVE100',
        'title': 'Flat ₹100 Off',
        'description': 'Save ₹100 on orders above ₹799',
        'discount': 100,
        'discountType': 'flat',
        'minOrder': 799,
        'maxDiscount': 100,
        'validUntil': DateTime.now().add(const Duration(days: 15)),
        'status': 'available',
      },
      {
        'id': 'DRYCLEAN20',
        'code': 'DRYCLEAN20',
        'title': 'Dry Clean Special',
        'description': '20% off on all dry cleaning services',
        'discount': 20,
        'discountType': 'percentage',
        'minOrder': 300,
        'maxDiscount': 150,
        'validUntil': DateTime.now().add(const Duration(days: 7)),
        'status': 'available',
        'serviceType': 'dryclean',
      },
      {
        'id': 'WEEKEND30',
        'code': 'WEEKEND30',
        'title': 'Weekend Offer',
        'description': 'Get 30% off on weekend orders',
        'discount': 30,
        'discountType': 'percentage',
        'minOrder': 600,
        'maxDiscount': 200,
        'validUntil': DateTime.now().add(const Duration(days: 3)),
        'status': 'available',
      },
      {
        'id': 'PREMIUM15',
        'code': 'PREMIUM15',
        'title': 'Premium Service',
        'description': '15% off on premium laundry',
        'discount': 15,
        'discountType': 'percentage',
        'minOrder': 1000,
        'maxDiscount': 300,
        'validUntil': DateTime.now().add(const Duration(days: 20)),
        'status': 'available',
      },
    ];
  }

  void _copyCouponCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coupon code "$code" copied!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppColors.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Offers & Coupons',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _gold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          tabs: const [
            Tab(text: 'Available'),
            Tab(text: 'Used'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCouponsList(availableCoupons, true),
                _buildCouponsList(usedCoupons, false),
              ],
            ),
    );
  }

  Widget _buildCouponsList(List<Map<String, dynamic>> coupons, bool isAvailable) {
    if (coupons.isEmpty) {
      final t = AppColors.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAvailable
                  ? Icons.local_offer_outlined
                  : Icons.history_rounded,
              size: 80,
              color: t.textDim,
            ),
            const SizedBox(height: 16),
            Text(
              isAvailable
                  ? 'No coupons available'
                  : 'No used coupons yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: t.textMid,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAvailable
                  ? 'Check back later for new offers!'
                  : 'Your used coupons will appear here',
              style: TextStyle(
                fontSize: 13,
                color: t.textDim,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCoupons,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: coupons.length,
        itemBuilder: (context, index) {
          final coupon = coupons[index];
          return _buildCouponCard(coupon, isAvailable);
        },
      ),
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> coupon, bool isAvailable) {
    final t = AppColors.of(context);
    final discount = coupon['discount'];
    final discountType = coupon['discountType'];
    // validUntil may be a Firestore Timestamp or a DateTime (from defaults)
    final rawUntil = coupon['validUntil'];
    DateTime? validUntil;
    if (rawUntil is DateTime) {
      validUntil = rawUntil;
    } else if (rawUntil != null) {
      try { validUntil = (rawUntil as dynamic).toDate() as DateTime; } catch (_) {}
    }
    final daysLeft = validUntil?.difference(DateTime.now()).inDays ?? 0;

    final discountText = discountType == 'percentage'
        ? '$discount% OFF'
        : '₹$discount OFF';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isAvailable
              ? [Colors.white, t.surface]
              : [Colors.grey.shade300, Colors.grey.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isAvailable
                ? _blue.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAvailable
                    ? _gold.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Discount badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAvailable
                              ? [_blue, const Color(0xFF3B82F6)]
                              : [Colors.grey, Colors.grey.shade600],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        discountText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Validity badge
                    if (isAvailable && daysLeft > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: daysLeft <= 3
                              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: daysLeft <= 3
                                ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                : const Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: daysLeft <= 3
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$daysLeft days',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: daysLeft <= 3
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  coupon['title'] ?? 'Special Offer',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isAvailable ? t.textHi : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  coupon['description'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: isAvailable ? t.textMid : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                // Terms
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: isAvailable ? t.textDim : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Min order: ₹${coupon['minOrder']} • Max discount: ₹${coupon['maxDiscount']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isAvailable ? t.textDim : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Coupon code & action button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? _gold.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAvailable
                          ? _gold.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        color: isAvailable ? _gold : Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        coupon['code'] ?? 'COUPON',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isAvailable ? _navy : Colors.grey.shade700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      if (isAvailable)
                        GestureDetector(
                          onTap: () => _copyCouponCode(coupon['code'] ?? ''),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'COPY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'USED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
