// lib/screens/admin/admin_refunds_page.dart
//
// Displays every cancellation-refund record from the top-level
// /refunds collection.  Managers can mark bank/UPI refunds as
// "processed".  Wallet refunds are completed automatically.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_theme.dart';

class AdminRefundsPage extends StatefulWidget {
  const AdminRefundsPage({super.key});
  @override
  State<AdminRefundsPage> createState() => _AdminRefundsPageState();
}

class _AdminRefundsPageState extends State<AdminRefundsPage> {
  final _db = FirebaseFirestore.instance;
  String _filter = 'all'; // all | initiated | completed | failed

  @override
  Widget build(BuildContext context) {
    final at = DynAdmin.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: AdminPageHeader(
            title: 'Refund Management',
            subtitle: 'Review & process cancelled-order refunds',
          ),
        ),

        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'initiated', 'completed', 'failed'].map((f) {
                final active = _filter == f;
                final c = f == 'completed'
                    ? AdminTheme.emerald
                    : f == 'initiated'
                        ? AdminTheme.amber
                        : f == 'failed'
                            ? AdminTheme.rose
                            : AdminTheme.gold;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: active
                          ? c.withValues(alpha: 0.2)
                          : AdminTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: active ? c : AdminTheme.cardBorder,
                          width: active ? 1.5 : 1),
                    ),
                    child: Text(f.toUpperCase(),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: active ? c : at.textSecondary)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _filter == 'all'
                ? _db
                    .collection('refunds')
                    .orderBy('createdAt', descending: true)
                    .snapshots()
                : _db
                    .collection('refunds')
                    .where('refundStatus', isEqualTo: _filter)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AdminTheme.gold, strokeWidth: 2));
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 56, color: at.textSecondary),
                    const SizedBox(height: 12),
                    Text('No refunds found', style: at.label(15)),
                  ]),
                );
              }

              final docs = snap.data!.docs;
              double totalPending = 0;
              for (final d in docs) {
                final data = d.data() as Map<String, dynamic>;
                if (data['refundStatus'] == 'initiated') {
                  totalPending += (data['cashbackAmount'] ?? 0).toDouble();
                }
              }

              return Column(
                children: [
                  // Summary bar
                  if (_filter == 'all')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AdminTheme.cardDecoration(glow: true),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _sumCol('Total', '${docs.length}', AdminTheme.gold),
                            Container(
                                width: 1,
                                height: 36,
                                color: AdminTheme.cardBorder),
                            _sumCol(
                                'Pending',
                                '₹${totalPending.toStringAsFixed(0)}',
                                AdminTheme.amber),
                            Container(
                                width: 1,
                                height: 36,
                                color: AdminTheme.cardBorder),
                            _sumCol(
                                'Initiated',
                                '${docs.where((d) => (d.data() as Map)['refundStatus'] == 'initiated').length}',
                                AdminTheme.violet),
                          ],
                        ),
                      ),
                    ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (_, i) =>
                          _buildRefundCard(docs[i]),
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

  Widget _buildRefundCard(DocumentSnapshot doc) {
    final at = DynAdmin.of(context);
    final d = doc.data() as Map<String, dynamic>;
    final status = d['refundStatus'] ?? 'initiated';
    final method = d['refundMethod'] ?? 'wallet';
    final amount = (d['cashbackAmount'] ?? 0).toDouble();
    final orderId = d['orderId'] ?? '';
    final ts = (d['createdAt'] as Timestamp?)?.toDate();
    final reason = d['cancellationReason'] ?? '—';
    final bankDetails = d['bankDetails'] as Map<String, dynamic>?;
    final upiId = d['upiId'] as String?;

    final statusColor = status == 'completed'
        ? AdminTheme.emerald
        : status == 'failed'
            ? AdminTheme.rose
            : AdminTheme.amber;

    // Check if current user is a manager or admin
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AdminTheme.cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor)),
              ),
              const Spacer(),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: statusColor),
              ),
            ]),

            const SizedBox(height: 10),

            // Order & user info
            _infoRow('Order ID',
                '#${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}'),
            _infoRow('User ID', d['userId'] ?? '—'),
            _infoRow('Reason', reason),
            _infoRow(
              'Created',
              ts != null
                  ? '${ts.day}/${ts.month}/${ts.year} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                  : '—',
            ),
            _infoRow('Refund via', _methodLabel(method)),

            // Bank details section
            if (method == 'bank' && bankDetails != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminTheme.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AdminTheme.amber.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.account_balance_rounded,
                          size: 14, color: AdminTheme.amber),
                      const SizedBox(width: 6),
                      const Text('Bank Transfer Details',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AdminTheme.amber)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _copyBankDetails(bankDetails),
                        child: Icon(Icons.copy_rounded,
                            size: 14, color: at.textSecondary),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _infoRow('Account Name',
                        bankDetails['accountName'] ?? '—'),
                    _infoRow('Account No.',
                        bankDetails['accountNumber'] ?? '—'),
                    _infoRow('IFSC', bankDetails['ifsc'] ?? '—'),
                    _infoRow('Bank', bankDetails['bankName'] ?? '—'),
                  ],
                ),
              ),
            ],

            // UPI details
            if (method == 'upi' && upiId != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminTheme.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AdminTheme.cyan.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.phone_android_rounded,
                      size: 14, color: AdminTheme.cyan),
                  const SizedBox(width: 6),
                  Text('UPI: $upiId',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: at.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: upiId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('UPI ID copied'),
                            behavior: SnackBarBehavior.floating),
                      );
                    },
                    child: Icon(Icons.copy_rounded,
                        size: 14, color: at.textSecondary),
                  ),
                ]),
              ),
            ],

            // ── Manager action button (only for initiated bank/upi refunds) ──
            if (status == 'initiated' &&
                method != 'wallet' &&
                currentUserUid != null) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminTheme.rose,
                      side: BorderSide(
                          color: AdminTheme.rose.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Mark Failed',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                    onPressed: () =>
                        _updateRefundStatus(doc.id, 'failed', currentUserUid),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.emerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Mark Processed',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12)),
                    onPressed: () => _updateRefundStatus(
                        doc.id, 'completed', currentUserUid),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateRefundStatus(
      String refundId, String newStatus, String managerUid) async {
    try {
      await _db.collection('refunds').doc(refundId).update({
        'refundStatus': newStatus,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': managerUid,
      });
      // Also update the linked order's refundStatus
      final refDoc = await _db.collection('refunds').doc(refundId).get();
      final orderId = (refDoc.data() as Map?)?['orderId'] as String?;
      if (orderId != null) {
        await _db.collection('orders').doc(orderId).update({
          'refundStatus': newStatus,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newStatus == 'completed'
              ? '✓ Refund marked as processed'
              : '✓ Refund marked as failed'),
          backgroundColor: newStatus == 'completed'
              ? AdminTheme.emerald
              : AdminTheme.rose,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AdminTheme.rose,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  void _copyBankDetails(Map<String, dynamic> bd) {
    final text =
        'Account Name: ${bd['accountName']}\nAccount No: ${bd['accountNumber']}\nIFSC: ${bd['ifsc']}\nBank: ${bd['bankName']}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Bank details copied'),
          behavior: SnackBarBehavior.floating),
    );
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'wallet':
        return 'Laundrify Wallet';
      case 'upi':
        return 'UPI Transfer';
      case 'bank':
        return 'Bank Transfer (NEFT)';
      default:
        return method;
    }
  }

  Widget _infoRow(String label, String value) {
    final at = DynAdmin.of(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: at.label(12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: at.textPrimary)),
          ),
        ]),
      );
  }

  Widget _sumCol(String label, String value, Color color) {
    final at = DynAdmin.of(context);
    return Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: at.label(11)),
        ],
      );
  }
}
