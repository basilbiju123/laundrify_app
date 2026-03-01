import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_page.dart';

class AbandonedCartPage extends StatelessWidget {
  const AbandonedCartPage({super.key});

  static const _navy = Color(0xFF080F1E);
  static const _gold = Color(0xFFF5C518);
  static const _bg = Color(0xFFF0F4FF);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Saved Carts',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('abandoned_carts')
            .where('status', isEqualTo: 'abandoned')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No saved carts',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8))),
                  const SizedBox(height: 8),
                  const Text('Carts saved after payment failure appear here.',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFFB0BEC5)),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
              final items = data['totalItems'] ?? 0;
              final date = (data['createdAt'] as Timestamp?)?.toDate();
              final method = data['paymentMethod'] ?? 'online';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE4B5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.shopping_cart_rounded,
                              color: _navy, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('₹${total.toStringAsFixed(0)} • $items items',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _navy)),
                              if (date != null)
                                Text(
                                    'Saved ${date.day}/${date.month}/${date.year}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await doc.reference.update({'status': 'dismissed'});
                          },
                          child: const Icon(Icons.close_rounded,
                              color: Color(0xFF94A3B8), size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final services = (data['services'] as List<dynamic>?)
                                  ?.map((s) => Map<String, dynamic>.from(s as Map))
                                  .toList() ??
                              [];
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentPage(
                                totalAmount: total,
                                totalItems: items is int
                                    ? items
                                    : int.tryParse(items.toString()) ?? 0,
                                services: services,
                                pickupDate: data['pickupDate'] ?? '',
                                pickupTime: data['pickupTime'] ?? '',
                                paymentMethod: method,
                              ),
                            ),
                          );
                        },
                        child: const Text('RETRY PAYMENT',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
