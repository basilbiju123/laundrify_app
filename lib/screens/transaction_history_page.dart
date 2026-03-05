import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

// ═══════════════════════════════════════════════════════════════════
// TRANSACTION HISTORY PAGE — Real Firestore data
// Shows all payments the user has made for their orders
// Navy + Gold theme matching the rest of the app
// ═══════════════════════════════════════════════════════════════════

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _filter = 'All'; // All | Paid | COD | Refunded
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final _filters = ['All', 'Paid', 'COD', 'Refunded'];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _ordersStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(uid)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  List<Map<String, dynamic>> _applyFilter(List<QueryDocumentSnapshot> docs) {
    return docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .where((d) {
      if (_filter == 'All') return true;
      if (_filter == 'COD') {
        return (d['paymentMethod'] ?? '').toString().toUpperCase() == 'COD';
      }
      if (_filter == 'Refunded') {
        return (d['paymentStatus'] ?? '') == 'refunded' ||
            (d['status'] ?? '') == 'cancelled';
      }
      if (_filter == 'Paid') {
        return (d['paymentStatus'] ?? '') == 'completed' &&
            (d['paymentMethod'] ?? '').toString().toUpperCase() != 'COD';
      }
      return true;
    }).toList();
  }

  double _totalSpent(List<Map<String, dynamic>> txns) {
    return txns.fold(0.0, (total, t) {
      if ((t['status'] ?? '') == 'cancelled') return total;
      return total + ((t['total'] ?? t['totalAmount'] ?? 0) as num).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lt = DynTheme.of(context);
    return Scaffold(
      backgroundColor: lt.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _ordersStream(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: DynTheme.gold, strokeWidth: 2),
                    );
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return _buildEmpty();
                  }
                  final txns = _applyFilter(snap.data!.docs);
                  if (txns.isEmpty) {
                    return _buildEmpty(filtered: true);
                  }
                  final spent = _totalSpent(txns);
                  return Column(
                    children: [
                      _buildSummaryBand(txns.length, spent),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          physics: const BouncingScrollPhysics(),
                          itemCount: txns.length,
                          itemBuilder: (_, i) =>
                              _TransactionCard(data: txns[i]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DynTheme.navy, DynTheme.navyMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaction History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'All your payments in one place',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DynTheme.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: DynTheme.gold.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: DynTheme.gold, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter bar ─────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      color: DynTheme.navy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: _filters.map((f) {
          final active = _filter == f;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _filter = f);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                        colors: [DynTheme.gold, DynTheme.goldSoft])
                    : null,
                color: active ? null : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? DynTheme.navy : Colors.white,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Summary band ────────────────────────────────────────────────
  Widget _buildSummaryBand(int count, double spent) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DynTheme.navy, DynTheme.navyMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: DynTheme.navy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _summaryItem('Transactions', '$count',
              Icons.receipt_outlined, DynTheme.blueSoft),
          Container(
            width: 1,
            height: 36,
            color: Colors.white.withValues(alpha: 0.12),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _summaryItem('Total Spent', '₹${spent.toStringAsFixed(0)}',
              Icons.currency_rupee_rounded, DynTheme.gold),
        ],
      ),
    );
  }

  Widget _summaryItem(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────
  Widget _buildEmpty({bool filtered = false}) {
    return LEmptyState(
      title: filtered ? 'No $_filter transactions' : 'No transactions yet',
      sub: filtered
          ? 'Try a different filter'
          : 'Your payment history will appear here after your first order.',
      icon: Icons.receipt_long_outlined,
      color: DynTheme.gold,
    );
  }
}

// ── Transaction Card ─────────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TransactionCard({required this.data});

  String get _orderId => data['id'] ?? data['orderId'] ?? '';
  String get _shortId {
    final id = _orderId;
    return id.length >= 8 ? '#${id.substring(0, 8).toUpperCase()}' : '#$id';
  }

  double get _amount =>
      ((data['total'] ?? data['totalAmount'] ?? 0) as num).toDouble();
  String get _method =>
      (data['paymentMethod'] ?? 'Online').toString();
  String get _status => data['status'] ?? 'confirmed';
  String get _payStatus => data['paymentStatus'] ?? 'completed';

  bool get _isRefunded =>
      _status == 'cancelled' || _payStatus == 'refunded';
  bool get _isCOD => _method.toUpperCase() == 'COD';

  Color get _statusColor {
    if (_isRefunded) return DynTheme.rose;
    if (_isCOD) return DynTheme.amber;
    return DynTheme.emerald;
  }

  IconData get _statusIcon {
    if (_isRefunded) return Icons.money_off_csred_rounded;
    if (_isCOD) return Icons.payments_outlined;
    return Icons.check_circle_rounded;
  }

  String get _statusLabel {
    if (_isRefunded) return 'REFUNDED';
    if (_isCOD) return 'COD';
    return 'PAID';
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else {
      return ts.toString();
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final lt = DynTheme.of(context);
    final color = _statusColor;
    final services = (data['services'] as List?)
        ?.map((s) => (s['serviceName'] ?? s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .join(', ') ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: lt.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(_statusIcon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shortId,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: lt.textHi,
                        ),
                      ),
                      if (services.isNotEmpty)
                        Text(
                          services,
                          style: TextStyle(
                              fontSize: 11, color: lt.textDim),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _isRefunded
                          ? '- ₹${_amount.toStringAsFixed(0)}'
                          : '₹${_amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _isRefunded ? DynTheme.rose : lt.textHi,
                      ),
                    ),
                    LBadge(
                        label: _statusLabel,
                        color: color,
                        fontSize: 9),
                  ],
                ),
              ],
            ),
          ),

          // Details row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                // Method
                _pill(
                  icon: _isCOD
                      ? Icons.payments_outlined
                      : Icons.account_balance_wallet_outlined,
                  label: _method,
                  color: DynTheme.blueSoft,
                ),
                const SizedBox(width: 8),
                // Date
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 12, color: lt.textDim),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(data['createdAt']),
                        style: TextStyle(
                            fontSize: 11, color: lt.textDim),
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

  Widget _pill(
      {required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
