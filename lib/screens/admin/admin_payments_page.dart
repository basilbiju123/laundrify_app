import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_theme.dart';

// ═══════════════════════════════════════════════════════════
// PAYMENTS PAGE
// ═══════════════════════════════════════════════════════════
class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});
  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  final _db = FirebaseFirestore.instance;
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final at = DynAdmin.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: AdminPageHeader(title: 'Payment Management', subtitle: 'Track all transactions and revenue'),
        ),

        // FILTER TABS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: ['all', 'completed', 'pending', 'failed'].map((f) {
              final active = _filter == f;
              final c = f == 'completed' ? AdminTheme.emerald : f == 'failed' ? AdminTheme.rose : f == 'pending' ? AdminTheme.amber : AdminTheme.gold;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? c.withValues(alpha: 0.2) : at.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? c : at.cardBorder, width: active ? 1.5 : 1),
                  ),
                  child: Text(f.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? c : at.textSecondary)),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _filter == 'all'
                ? _db.collection('orders').orderBy('createdAt', descending: true).snapshots()
                : _db.collection('orders').where('paymentStatus', isEqualTo: _filter).orderBy('createdAt', descending: true).snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AdminTheme.gold, strokeWidth: 2));
              if (!snap.hasData || snap.data!.docs.isEmpty) return Center(child: Text('No transactions found', style: at.label(14)));

              final docs = snap.data!.docs;
              double total = 0;
              for (var d in docs) { total += ((d.data() as Map)['totalAmount'] ?? 0); }

              return Column(
                children: [
                  // SUMMARY CARD — only shown when viewing all transactions
                  if (_filter == 'all')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: at.cardDecoration(glow: true),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _sumCol(context, 'Transactions', '${docs.length}', AdminTheme.gold),
                          Container(width: 1, height: 40, color: at.cardBorder),
                          _sumCol(context, 'Total Amount', '₹${_fmt(total)}', AdminTheme.emerald),
                          Container(width: 1, height: 40, color: at.cardBorder),
                          _sumCol(context, 'Avg Value', '₹${docs.isEmpty ? 0 : _fmt(total / docs.length)}', AdminTheme.violet),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final amt = (d['totalAmount'] ?? 0).toDouble();
                        final pStatus = d['paymentStatus'] ?? 'pending';
                        final pColor = pStatus == 'completed' ? AdminTheme.emerald : pStatus == 'failed' ? AdminTheme.rose : AdminTheme.amber;
                        final ts = (d['createdAt'] as Timestamp?)?.toDate();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: at.cardDecoration(),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: pColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                child: Icon(pStatus == 'completed' ? Icons.check_circle_outline : pStatus == 'failed' ? Icons.error_outline : Icons.schedule_rounded, color: pColor, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d['customerName'] ?? 'Customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: at.textPrimary)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Text('#${docs[i].id.substring(0, 8).toUpperCase()}', style: at.label(11)),
                                      const SizedBox(width: 8),
                                      if (ts != null) Text('${ts.day}/${ts.month}/${ts.year}', style: at.label(11).copyWith(color: at.textMuted)),
                                    ]),
                                    if (d['razorpayOrderId'] != null) ...[
                                      const SizedBox(height: 2),
                                      Text('Razorpay: ${d['razorpayOrderId']}', style: at.label(10).copyWith(color: at.textMuted)),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${amt.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: at.textPrimary)),
                                  const SizedBox(height: 4),
                                  AdminBadge(label: pStatus, color: pColor, fontSize: 10),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sumCol(BuildContext context, String label, String value, Color color) {
    final at = DynAdmin.of(context);
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 4),
      Text(label, style: at.label(11)),
    ]);
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

