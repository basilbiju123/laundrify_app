import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_page.dart';
import 'order_summary_page.dart';

// ════════════════════════════════════════════════════════════
// SAVED CARTS / INCOMPLETE ORDERS PAGE
// Shows two types:
//   1. 'saved'     → user tapped "Save for Later" from OrderSummaryPage
//   2. 'abandoned' → payment failed, cart auto-saved from PaymentPage
// ════════════════════════════════════════════════════════════

class AbandonedCartPage extends StatelessWidget {
  const AbandonedCartPage({super.key});

  static const _navy  = Color(0xFF080F1E);
  static const _gold  = Color(0xFFF5C518);
  static const _green = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final t = AppColors.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Saved Carts',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('abandoned_carts')
            .where('status', whereIn: ['abandoned', 'saved'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return _emptyState(context, t);

          // Separate by type
          final savedCarts = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['saveType'] == 'incomplete' || data['status'] == 'saved';
          }).toList();
          final abandonedCarts = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] == 'abandoned' && data['saveType'] != 'incomplete';
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Incomplete / Saved Orders ──────────────────
              if (savedCarts.isNotEmpty) ...[
                _sectionHeader(t, Icons.bookmark_rounded, _green, 'Saved Orders',
                    '${savedCarts.length} order${savedCarts.length != 1 ? 's' : ''} saved'),
                const SizedBox(height: 10),
                ...savedCarts.map((doc) => _savedCartCard(context, t, doc)),
                const SizedBox(height: 20),
              ],

              // ── Abandoned / Payment Failed ─────────────────
              if (abandonedCarts.isNotEmpty) ...[
                _sectionHeader(t, Icons.warning_amber_rounded, _amber, 'Payment Failed',
                    '${abandonedCarts.length} cart${abandonedCarts.length != 1 ? 's' : ''} need retry'),
                const SizedBox(height: 10),
                ...abandonedCarts.map((doc) => _abandonedCartCard(context, t, doc)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(dynamic t, IconData icon, Color color, String title, String sub) =>
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: (t as dynamic).textHi)),
          Text(sub, style: TextStyle(fontSize: 11, color: t.textDim)),
        ]),
      ]);

  // ── Saved (incomplete) cart card ──────────────────────────
  Widget _savedCartCard(BuildContext context, dynamic t, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final itemCount = data['totalItems'] ?? 0;
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    final services = (data['services'] as List<dynamic>? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _green.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.bookmark_rounded, color: _green, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('₹${total.toStringAsFixed(0)}  •  $itemCount item${itemCount != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.textHi)),
              if (date != null)
                Text('Saved ${date.day}/${date.month}/${date.year} at '
                    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11, color: t.textDim)),
            ])),
            GestureDetector(
              onTap: () async {
                await doc.reference.update({'status': 'dismissed'});
              },
              child: Icon(Icons.close_rounded, color: t.textDim, size: 20),
            ),
          ]),
        ),

        // Services summary
        if (services.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 8, runSpacing: 6,
              children: services.map<Widget>((svc) {
                final name = (svc as Map)['serviceName'] ?? svc['title'] ?? '';
                final items = (svc['items'] as List? ?? [])
                    .where((i) => ((i as Map)['qty'] ?? 0) > 0).length;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.cardBdr)),
                  child: Text('$name ($items)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.textMid)),
                );
              }).toList(),
            ),
          ),

        // Actions
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Continue ordering (go to order summary)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final servicesList = services
                      .map((s) => Map<String, dynamic>.from(s as Map))
                      .toList();
                  // Delete this saved cart then open order summary
                  doc.reference.update({'status': 'dismissed'});
                  if (servicesList.isNotEmpty) {
                    final firstSvc = servicesList.first;
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => OrderSummaryPage(
                        serviceName: firstSvc['serviceName'] ?? firstSvc['title'] ?? 'Order',
                        selectedItems: (firstSvc['items'] as List? ?? [])
                            .map((i) => Map<String, dynamic>.from(i as Map))
                            .toList(),
                      ),
                    ));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: _navy,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.edit_rounded, color: _gold, size: 15),
                    SizedBox(width: 6),
                    Text('Continue Ordering',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Quick pay (go straight to payment)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final servicesList = services
                      .map((s) => Map<String, dynamic>.from(s as Map))
                      .toList();
                  doc.reference.update({'status': 'dismissed'});
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PaymentPage(
                      totalAmount: total,
                      totalItems: itemCount is int ? itemCount : int.tryParse(itemCount.toString()) ?? 0,
                      services: servicesList,
                      pickupDate: data['pickupDate'] ?? '',
                      pickupTime: data['pickupTime'] ?? '',
                      paymentMethod: data['paymentMethod'] ?? 'online',
                    ),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _green.withValues(alpha: 0.3))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.flash_on_rounded, color: _green, size: 15),
                    SizedBox(width: 6),
                    Text('Quick Pay',
                        style: TextStyle(
                            color: _green,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Abandoned (payment-failed) cart card ─────────────────
  Widget _abandonedCartCard(BuildContext context, dynamic t, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final itemCount = data['totalItems'] ?? 0;
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    final method = data['paymentMethod'] ?? 'online';
    final services = (data['services'] as List<dynamic>?)
            ?.map((s) => Map<String, dynamic>.from(s as Map))
            .toList() ??
        [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _amber.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _amber.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.warning_amber_rounded, color: _amber, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('₹${total.toStringAsFixed(0)}  •  $itemCount items',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.textHi)),
              if (date != null)
                Text('Failed on ${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(fontSize: 11, color: _amber, fontWeight: FontWeight.w600)),
            ])),
            GestureDetector(
              onTap: () async => await doc.reference.update({'status': 'dismissed'}),
              child: Icon(Icons.close_rounded, color: t.textDim, size: 20),
            ),
          ]),
        ),

        // Retry button
        Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                doc.reference.update({'status': 'dismissed'});
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PaymentPage(
                    totalAmount: total,
                    totalItems: itemCount is int ? itemCount : int.tryParse(itemCount.toString()) ?? 0,
                    services: services,
                    pickupDate: data['pickupDate'] ?? '',
                    pickupTime: data['pickupTime'] ?? '',
                    paymentMethod: method,
                  ),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF080F1E), Color(0xFF0D1F3C)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.refresh_rounded, color: _gold, size: 16),
                  SizedBox(width: 8),
                  Text('Retry Payment',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _emptyState(BuildContext context, dynamic t) =>
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: Icon(Icons.shopping_cart_outlined,
                  size: 52,
                  color: _gold.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text('No saved carts',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: (t as dynamic).textHi)),
            const SizedBox(height: 8),
            Text('Tap 🔖 in Order Summary to save\nincomplete orders for later.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: t.textDim, height: 1.5)),
          ],
        ),
      );
}
